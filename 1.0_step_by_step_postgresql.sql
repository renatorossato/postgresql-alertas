/*
    Objetivo: roteiro passo a passo para instalar os alertas em PostgreSQL.
    Banco alvo: PostgreSQL 12 ou superior.
    Pré‑requisitos: ver README.md e guia_instalacao.md.
    Responsável: Adaptado do Script_SQLServer_Alerts.
    Histórico de versões:
      v1.0 - Criação inicial do roteiro para PostgreSQL.

    Este arquivo não deve ser executado; serve como guia. Execute os scripts indicados manualmente.

    Passo a passo:
    ---------------------------------------------------------------
    1. Crie o schema `monitoring` se ainda não existir:
       -- CREATE SCHEMA IF NOT EXISTS monitoring;

    2. Execute o script de criação de tabelas e parâmetros:
       \i 2.0_cria_tabelas_alertas.sql

    3. Execute o script de criação de funções de alerta e agendamento:
       \i 2.1_cria_procedures_e_jobs_postgresql.sql

    4. (Opcional) Execute a verificação de corrupção:
       \i 3.0_verifica_corrupcao.sql

    5. Execute o script de checklist diário:
       \i 4.0_checklist_procedures_postgresql.sql

    6. Ajuste parâmetros na tabela monitoring.parametros_alerta conforme sua necessidade.

    7. Configure o script externo de envio de e‑mails (ver doc/guia_configuracao.md) e agende via cron.

    Observação:
    Para executar estes scripts, utilize uma ferramenta de linha de comando (psql) ou interface gráfica. 
    Os scripts usam a convenção `schema.objeto`, portanto defina o search_path ou prefixe as referências com o schema.
*/

-- Script apenas informativo.