# start.ps1 - Script de inicio automatizado
$projectRoot = $PSScriptRoot
$envFile = Join-Path $projectRoot ".env"
$envExample = Join-Path $projectRoot ".env.example"
$composeFile = Join-Path $projectRoot "docker-compose.yml"
$jwtFile = Join-Path $projectRoot ".dev-jwt"
$defaultJwtSecret = "cambia-este-secreto-por-uno-de-al-menos-32-caracteres-aleatorios"

Write-Host "==> Verificando archivo .env..." -ForegroundColor Cyan
if (-not (Test-Path $envFile)) {
    if (-not (Test-Path $envExample)) {
        Write-Error "[ERROR] No se encontró .env.example en $projectRoot"
        exit 1
    }

    Copy-Item $envExample $envFile
    Write-Host "[OK] Archivo .env creado a partir de .env.example" -ForegroundColor Green
}

$envLines = [System.Collections.Generic.List[string]]::new()
[System.IO.File]::ReadAllLines($envFile) | ForEach-Object { $envLines.Add($_) }
$jwtSecretLine = -1
for ($index = 0; $index -lt $envLines.Count; $index++) {
    if ($envLines[$index] -match '^JWT_SECRET=(.*)$') {
        $jwtSecretLine = $index
        break
    }
}

$jwtSecret = if ($jwtSecretLine -ge 0) {
    $envLines[$jwtSecretLine].Substring("JWT_SECRET=".Length)
} else {
    ""
}

if ([string]::IsNullOrWhiteSpace($jwtSecret) -or $jwtSecret -eq $defaultJwtSecret) {
    $secretBytes = [byte[]]::new(32)
    $randomGenerator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $randomGenerator.GetBytes($secretBytes)
    } finally {
        $randomGenerator.Dispose()
    }
    $jwtSecret = [Convert]::ToBase64String($secretBytes)
    $jwtSecretEntry = "JWT_SECRET=$jwtSecret"
    if ($jwtSecretLine -ge 0) {
        $envLines[$jwtSecretLine] = $jwtSecretEntry
    } else {
        $envLines.Add($jwtSecretEntry)
    }
    [System.IO.File]::WriteAllLines($envFile, $envLines, [System.Text.UTF8Encoding]::new($false))
    Write-Host "[OK] Se generó un JWT_SECRET aleatorio en .env" -ForegroundColor Green
}

if ([System.Text.Encoding]::UTF8.GetByteCount($jwtSecret) -lt 32) {
    throw "JWT_SECRET en .env debe tener al menos 32 bytes UTF-8."
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "[ERROR] Docker no está instalado o no está disponible en PATH."
    exit 1
}

Write-Host "==> Construyendo servicios y esperando a que estén listos..." -ForegroundColor Cyan
docker compose --project-directory $projectRoot --env-file $envFile -f $composeFile up --build --detach --wait --wait-timeout 300
$composeExitCode = $LASTEXITCODE
if ($composeExitCode -ne 0) {
    Write-Error "[ERROR] Docker Compose falló (código $composeExitCode). Revisa el estado con 'docker compose ps' y los logs con 'docker compose logs'."
    exit $composeExitCode
}

$toBase64Url = {
    param([byte[]]$Bytes)
    [Convert]::ToBase64String($Bytes).TrimEnd("=").Replace("+", "-").Replace("/", "_")
}
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$jwtHeader = [ordered]@{ alg = "HS256"; typ = "JWT" } | ConvertTo-Json -Compress
$jwtPayload = [ordered]@{
    sub = "local-dev"
    iat = $now
    exp = $now + 28800
} | ConvertTo-Json -Compress
$headerPart = & $toBase64Url ([System.Text.Encoding]::UTF8.GetBytes($jwtHeader))
$payloadPart = & $toBase64Url ([System.Text.Encoding]::UTF8.GetBytes($jwtPayload))
$signingInput = "$headerPart.$payloadPart"
$hmac = [System.Security.Cryptography.HMACSHA256]::new([System.Text.Encoding]::UTF8.GetBytes($jwtSecret))
try {
    $signature = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($signingInput))
} finally {
    $hmac.Dispose()
}
$signaturePart = & $toBase64Url $signature
$token = "$signingInput.$signaturePart"
[System.IO.File]::WriteAllText($jwtFile, $token, [System.Text.UTF8Encoding]::new($false))

Write-Host "==> ¡Servicios iniciados y listos!" -ForegroundColor Green
Write-Host "    - API Gateway / NGINX: http://localhost:8088"
Write-Host "    - Grafana: http://localhost:3001 (admin / Grafana#Obs2026)"
Write-Host "    - RabbitMQ Management: http://localhost:15672 (banking / Rabbit#Bus2026)"
Write-Host "    - JWT local (válido por 8 horas): .dev-jwt"
Write-Host '    - PowerShell: $jwt = (Get-Content .\.dev-jwt -Raw).Trim()'