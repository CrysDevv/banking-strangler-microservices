$projectRoot = $PSScriptRoot
$startScript = Join-Path $projectRoot "start.ps1"

if (-not (Test-Path $startScript)) {
    Write-Error "[ERROR] No se encontró start.ps1 en $projectRoot"
    exit 1
}

& $startScript
