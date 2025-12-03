#!/bin/bash
#
# Script simples para enviar e‑mails lendo a tabela monitoring.log_email no PostgreSQL.
# Requer as utilidades psql e mailx (ou sendmail). Ajuste variáveis abaixo.

DB_HOST="localhost"
DB_NAME="postgres"
DB_USER="postgres"
DB_PASS=""
EMAIL_FROM="monitor@empresa.com"
EMAIL_TO="dba@empresa.com"

export PGPASSWORD="$DB_PASS"

# Consulta e processa emails pendentes
psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -Atc "SELECT id_email, assunto, corpo_html FROM monitoring.log_email WHERE processed = false ORDER BY data_evento" | while IFS="|" read -r id assunto corpo
do
  echo "Enviando email $id..."
  echo -e "$corpo" | mailx -a 'Content-Type: text/html' -s "$assunto" -r "$EMAIL_FROM" $EMAIL_TO
  psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "UPDATE monitoring.log_email SET processed = true WHERE id_email = $id" > /dev/null
done

unset PGPASSWORD