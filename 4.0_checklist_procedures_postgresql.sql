--
-- Objetivo: implementar funções de checklist diário em PostgreSQL, consolidando métricas relevantes em um relatório HTML
-- e armazenando histórico para posterior consulta. O envio de e‑mail deve ser feito por script externo.
-- Inspirado no script 4.0 - Procedures CheckList.sql do projeto original para SQL Server.
-- Histórico de versões: v1.0 - Implementação simplificada.

SET search_path TO monitoring, public;

-- Tabela de histórico de checklist
CREATE TABLE IF NOT EXISTS checklist_historico (
    id_checklist SERIAL PRIMARY KEY,
    data_execucao TIMESTAMP DEFAULT NOW(),
    relatorio_html TEXT
);

/*
  Função: fn_checklist_espaco_db
  Retorna uma tabela HTML com tamanho de cada banco de dados no cluster.
*/
CREATE OR REPLACE FUNCTION fn_checklist_espaco_db() RETURNS TEXT AS $$
DECLARE
    v_corpo TEXT := '<h3>Tamanho dos Bancos de Dados</h3><table border="1" cellpadding="3" cellspacing="0">'
                    || '<tr><th>Banco</th><th>Tamanho (GB)</th></tr>';
BEGIN
    FOR rec IN SELECT datname, pg_database_size(datname) AS size_bytes FROM pg_database WHERE datistemplate = false LOOP
        v_corpo := v_corpo || '<tr><td>' || rec.datname || '</td><td>' || ROUND(rec.size_bytes/1024/1024/1024::NUMERIC,2)::TEXT || '</td></tr>';
    END LOOP;
    v_corpo := v_corpo || '</table>';
    RETURN v_corpo;
END;
$$ LANGUAGE plpgsql;

/*
  Função: fn_checklist_sessoes_ativas
  Retorna top 5 queries em execução.
*/
CREATE OR REPLACE FUNCTION fn_checklist_sessoes_ativas() RETURNS TEXT AS $$
DECLARE
    v_corpo TEXT := '<h3>Sessões Ativas</h3><table border="1" cellpadding="3" cellspacing="0">'
                    || '<tr><th>PID</th><th>Usuário</th><th>Tempo (min)</th><th>Query</th></tr>';
    v_count INTEGER := 0;
BEGIN
    FOR rec IN SELECT pid, usename, EXTRACT(EPOCH FROM (NOW() - query_start))/60 AS tempo_min, query
                 FROM pg_stat_activity
                WHERE state = 'active'
                  AND usename IS NOT NULL
                ORDER BY query_start ASC
                LIMIT 5
    LOOP
        v_count := v_count + 1;
        v_corpo := v_corpo || '<tr><td>' || rec.pid || '</td><td>' || rec.usename || '</td><td>' || ROUND(rec.tempo_min)::TEXT || '</td><td>' || substring(rec.query from 1 for 200) || '</td></tr>';
    END LOOP;
    v_corpo := v_corpo || '</table>';
    IF v_count = 0 THEN
        v_corpo := v_corpo || '<p>Não há sessões ativas no momento da coleta.</p>';
    END IF;
    RETURN v_corpo;
END;
$$ LANGUAGE plpgsql;

/*
  Função: fn_checklist_jobs_cron
  Lista jobs do pg_cron falhos nas últimas 24h.
*/
CREATE OR REPLACE FUNCTION fn_checklist_jobs_cron() RETURNS TEXT AS $$
DECLARE
    v_corpo TEXT := '<h3>Jobs do pg_cron com Falha nas Últimas 24h</h3><table border="1" cellpadding="3" cellspacing="0">'
                    || '<tr><th>JobID</th><th>Command</th><th>Última Execução</th><th>Status</th></tr>';
    v_count INTEGER := 0;
BEGIN
    -- Verificar se a extensão cron está instalada
    PERFORM 1 FROM pg_extension WHERE extname = 'pg_cron';
    IF NOT FOUND THEN
        RETURN '<p>pg_cron não está instalado.</p>';
    END IF;
    FOR rec IN SELECT j.jobid, j.command, r.runid, r.status, r.end_time
                 FROM cron.job j
                 JOIN cron.job_run_details r ON j.jobid = r.jobid
                WHERE r.start_time > NOW() - INTERVAL '1 day' AND r.status = 'failed'
    LOOP
        v_count := v_count + 1;
        v_corpo := v_corpo || '<tr><td>' || rec.jobid || '</td><td>' || rec.command || '</td><td>' || TO_CHAR(rec.end_time, 'DD/MM/YYYY HH24:MI') || '</td><td>' || rec.status || '</td></tr>';
    END LOOP;
    v_corpo := v_corpo || '</table>';
    IF v_count = 0 THEN
        v_corpo := v_corpo || '<p>Nenhum job apresentou falha nas últimas 24 horas.</p>';
    END IF;
    RETURN v_corpo;
END;
$$ LANGUAGE plpgsql;

/*
  Função: fn_checklist_diario
  Concatena as seções e grava no histórico. 
  Em vez de enviar e‑mail, grava na tabela log_email; o script externo pode enviar em seguida.
*/
CREATE OR REPLACE FUNCTION fn_checklist_diario() RETURNS VOID AS $$
DECLARE
    v_relatorio TEXT;
    v_titulo    TEXT := 'Checklist Diário – ' || TO_CHAR(NOW(), 'DD/MM/YYYY');
BEGIN
    v_relatorio := fn_checklist_espaco_db() || fn_checklist_sessoes_ativas() || fn_checklist_jobs_cron();
    INSERT INTO checklist_historico (relatorio_html) VALUES (v_relatorio);
    -- Inserir em log_email para posterior envio
    PERFORM grava_email(v_titulo, v_relatorio);
END;
$$ LANGUAGE plpgsql;

-- Agendamento via pg_cron: diariamente às 06:55
DO $$
BEGIN
    PERFORM cron.unschedule(jobid) FROM cron.job WHERE command LIKE '%fn_checklist_diario%';
    PERFORM cron.schedule('55 6 * * *', 'SELECT monitoring.fn_checklist_diario()');
EXCEPTION WHEN UNDEFINED_TABLE OR UNDEFINED_FUNCTION THEN
    RAISE NOTICE 'pg_cron não instalado ou função inexistente; agende manualmente via cron do SO.';
END$$;