#!/usr/bin/env python3
"""
Script de exemplo para envio de e‑mails de alertas a partir das tabelas de log do PostgreSQL.

Este script se conecta ao banco, lê as linhas da tabela monitoring.log_email com processed = false,
envia cada mensagem via SMTP e marca como processadas. Ajuste as variáveis de conexão e servidor SMTP
conforme sua infraestrutura. Utilize variáveis de ambiente ou arquivo de configuração para proteger credenciais.

Dependências: `psycopg2` (instalado via pip) e biblioteca padrão `smtplib`.
"""
import os
import smtplib
import psycopg2
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

# Variáveis de ambiente para conexão e SMTP
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_NAME = os.getenv('DB_NAME', 'postgres')
DB_USER = os.getenv('DB_USER', 'postgres')
DB_PASS = os.getenv('DB_PASS', '')
SMTP_HOST = os.getenv('SMTP_HOST', 'smtp.seu-servidor.com')
SMTP_PORT = int(os.getenv('SMTP_PORT', '25'))
SMTP_USER = os.getenv('SMTP_USER', '')
SMTP_PASS = os.getenv('SMTP_PASS', '')
EMAIL_FROM = os.getenv('EMAIL_FROM', 'monitor@empresa.com')
EMAIL_TO = os.getenv('EMAIL_TO', 'dba@empresa.com')

def send_email(subject: str, html_content: str):
    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = EMAIL_FROM
    msg['To'] = EMAIL_TO
    part = MIMEText(html_content, 'html')
    msg.attach(part)
    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
        if SMTP_USER:
            server.login(SMTP_USER, SMTP_PASS)
        server.sendmail(EMAIL_FROM, EMAIL_TO.split(','), msg.as_string())

def process_emails():
    conn = psycopg2.connect(host=DB_HOST, dbname=DB_NAME, user=DB_USER, password=DB_PASS)
    conn.autocommit = True
    cur = conn.cursor()
    cur.execute("SELECT id_email, assunto, corpo_html FROM monitoring.log_email WHERE processed = FALSE ORDER BY data_evento")
    rows = cur.fetchall()
    for row in rows:
        email_id, subject, body = row
        try:
            send_email(subject, body)
            cur.execute("UPDATE monitoring.log_email SET processed = TRUE WHERE id_email = %s", (email_id,))
            print(f"Email {email_id} enviado com sucesso")
        except Exception as e:
            print(f"Falha ao enviar email {email_id}: {e}")
    cur.close()
    conn.close()

if __name__ == '__main__':
    process_emails()