#!/bin/bash
# Ejecutado por el contenedor init-db (imagen mssql/server:2022 que incluye sqlcmd).
# -I: QUOTED_IDENTIFIER ON (indices filtrados) | -b: abortar ante error | -f 65001: UTF-8
set -euo pipefail

SQLCMD=/opt/mssql-tools18/bin/sqlcmd

for f in schema stored_procedures seed; do
  echo "[init-db] Ejecutando ${f}.sql ..."
  "$SQLCMD" -S mssql -U sa -P "${MSSQL_SA_PASSWORD}" -C -I -b -f 65001 \
            -v APP_DB_PASSWORD="${APP_DB_PASSWORD}" \
            -i "/scripts/${f}.sql"
done

echo "[init-db] Base BankingCore lista."
