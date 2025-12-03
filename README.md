# PostgreSQL Alertas

Este repositório contém a versão **PostgreSQL** dos scripts de alertas e monitoria inspirados no projeto original para SQL Server. A solução foi adaptada para PL/pgSQL e utiliza as funções de catálogo do PostgreSQL, além da extensão **pg_cron** para agendamento. O objetivo é disponibilizar uma base completa de monitoria para DBAs e analistas de dados em ambientes PostgreSQL.

## Visão geral

* Todos os objetos são criados em um esquema dedicado (`monitoring`) para facilitar a manutenção.
* O script `scripts/2.0_cria_tabelas_alertas.sql` cria as tabelas de configuração, parâmetros e logs.
* O script `scripts/2.1_cria_procedures_e_jobs_postgresql.sql` define as funções de alerta e agenda sua execução via **pg_cron** (quando disponível). Caso não utilize pg_cron, é possível agendar via cron do sistema.
* O script `scripts/4.0_checklist_procedures_postgresql.sql` implementa uma checklist diária com métricas de uso e performance.

## Pré‑requisitos

1. PostgreSQL versão 12 ou superior.
2. Usuário superusuário ou com privilégios para criar schema, funções e acessar as views `pg_stat_*`.
3. Extensão **pg_cron** instalada para agendamento interno (opcional). Se não disponível, utilize agendador externo (cron do SO) para chamar as funções.
4. Ferramenta externa ou script (ex.: Python, Shell) para envio de e‑mails, pois o PostgreSQL não possui mecanismo nativo de SMTP. Exemplos podem ser encontrados em `tools/scripts_envio_email`.

## Instalação

1. Crie o schema de monitoria e conceda privilégios:
   ```sql
   CREATE SCHEMA IF NOT EXISTS monitoring;
   GRANT USAGE ON SCHEMA monitoring TO public;
   ```
2. Execute `scripts/2.0_cria_tabelas_alertas.sql` para criar as tabelas e parâmetros padrão.
3. Execute `scripts/2.1_cria_procedures_e_jobs_postgresql.sql` para criar as funções de alerta e agendar jobs via pg_cron.
4. (Opcional) Execute `scripts/3.0_verifica_corrupcao.sql` para adicionar rotina de verificação de integridade através de `pg_checksums` ou `pg_dump`.
5. Execute `scripts/4.0_checklist_procedures_postgresql.sql` para implementar a checklist diária.
6. Ajuste os parâmetros de thresholds na tabela `monitoring.parametros_alerta` conforme a realidade do seu ambiente.

## Estrutura de pastas

```
postgresql-alertas/
├── README.md
├── doc/
│   ├── guia_instalacao.md
│   ├── guia_configuracao.md
│   └── guia_troubleshooting.md
├── scripts/
│   ├── 1.0_step_by_step_postgresql.sql
│   ├── 2.0_cria_tabelas_alertas.sql
│   ├── 2.1_cria_procedures_e_jobs_postgresql.sql
│   ├── 3.0_verifica_corrupcao.sql
│   └── 4.0_checklist_procedures_postgresql.sql
└── tools/
    └── scripts_envio_email/  # Exemplos de scripts externos para enviar e‑mail
```

## Créditos

Este projeto é uma adaptação do repositório [Script_SQLServer_Alerts](https://github.com/soupowertuning/Script_SQLServer_Alerts) para PostgreSQL. Todos os scripts foram reescritos em PL/pgSQL e podem ser utilizados livremente mediante observância da licença definida.
