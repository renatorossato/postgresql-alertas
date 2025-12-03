--
-- Objetivo: criar funções de alerta em PL/pgSQL e agendar jobs via pg_cron.
-- Banco alvo: PostgreSQL 12 ou superior.
-- Responsável: Adaptado do Script_SQLServer_Alerts.
-- Histórico de versões:
--   v1.0 - Implementação inicial das funções e agendamentos.

SET search_path TO monitoring, public;

/*
  Tabela de e‑mails pendentes
  As funções de alerta não enviam e‑mail diretamente; elas gravam registros nesta tabela.
  Um script externo deve ler as linhas com processed = false, enviar e‑mail via SMTP e marcar como processadas.
*/
CREATE TABLE IF NOT EXISTS log_email (
    id_email      SERIAL PRIMARY KEY,
    assunto       TEXT,
    corpo_html    TEXT,
    data_evento   TIMESTAMP DEFAULT NOW(),
    processed     BOOLEAN DEFAULT FALSE
);

/*
  Função utilitária para obter valor de parâmetro
*/
CREATE OR REPLACE FUNCTION get_parametro(p_nome TEXT) RETURNS TEXT AS $$
DECLARE
    v_valor TEXT;
BEGIN
    SELECT valor INTO v_valor
      FROM parametros_alerta
     WHERE LOWER(nome_parametro) = LOWER(p_nome);
    RETURN v_valor;
EXCEPTION WHEN NO_DATA_FOUND THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

/*
  Função utilitária para gravar um e‑mail na tabela log_email.
*/
CREATE OR REPLACE FUNCTION grava_email(p_assunto TEXT, p_corpo TEXT) RETURNS VOID AS $$
BEGIN
    INSERT INTO log_email (assunto, corpo_html) VALUES (p_assunto, p_corpo);
END;
$$ LANGUAGE plpgsql;

/*
  Alerta: espaço em tablespace (adaptado para PostgreSQL).
  Como PostgreSQL não possui dicionário de espaço livre por tablespace, esta função considera o tamanho total
  de cada tablespace (pg_tablespace_size) e compara com um limite virtual definido pelo parâmetro 'limite_tablespace_pct'.
  Ajuste a lógica conforme sua política de armazenamento (por exemplo, usando dados do SO).
*/
CREATE OR REPLACE FUNCTION fn_alerta_espaco_tbs() RETURNS VOID AS $$
DECLARE
    v_limite NUMERIC := get_parametro('limite_tablespace_pct')::NUMERIC;
    v_assunto TEXT;
    v_corpo   TEXT := '<h3>Espaço em Tablespaces</h3><table border="1" cellpadding="3" cellspacing="0">' ||
                      '<tr><th>Tablespace</th><th>Tamanho (GB)</th></tr>';
    v_alerta  BOOLEAN := FALSE;
BEGIN
    FOR rec IN SELECT spcname, pg_tablespace_size(oid) AS size_bytes FROM pg_tablespace WHERE spcname NOT IN ('pg_global') LOOP
        -- Aqui não há conceito de % utilizado; apenas reporta o tamanho absoluto.
        IF (rec.size_bytes/1024/1024/1024) >= v_limite THEN
            v_alerta := TRUE;
        END IF;
        v_corpo := v_corpo || '<tr><td>' || rec.spcname || '</td><td>' ||
                   ROUND(rec.size_bytes/1024/1024/1024,2)::TEXT || '</td></tr>';
    END LOOP;
    v_corpo := v_corpo || '</table>';
    IF v_alerta THEN
        v_assunto := 'Alerta: Espaço em Tablespace excede ' || v_limite || ' GB';
        PERFORM grava_email(v_assunto, v_corpo);
    END IF;
END;
$$ LANGUAGE plpgsql;

/*
  Alerta: processos bloqueados
  Verifica processos bloqueados via função pg_blocking_pids.
*/
CREATE OR REPLACE FUNCTION fn_alerta_processo_bloqueado() RETURNS VOID AS $$
DECLARE
    v_limite INTEGER := get_parametro('limite_tempo_query_min')::INTEGER;
    v_assunto TEXT := 'Alerta: Processos Bloqueados';
    v_corpo   TEXT := '<h3>Processos Bloqueados</h3><table border="1" cellpadding="3" cellspacing="0">' ||
                      '<tr><th>PID Bloqueado</th><th>PID Bloqueante</th><th>Tempo Bloqueio (min)</th><th>Query Bloqueada</th></tr>';
    v_alerta  BOOLEAN := FALSE;
BEGIN
    FOR rec IN SELECT a.pid AS pid_bloqueado,
                      b.pid AS pid_bloqueante,
                      EXTRACT(EPOCH FROM (NOW() - a.query_start))/60 AS tempo_min,
                      a.query AS query_text
                 FROM pg_stat_activity a
                 JOIN LATERAL unnest(pg_blocking_pids(a.pid)) AS bpid(pid)
                 JOIN pg_stat_activity b ON b.pid = bpid.pid
                WHERE a.state = 'active'
                  AND (NOW() - a.query_start) > (v_limite * INTERVAL '1 minute')
    LOOP
        v_alerta := TRUE;
        v_corpo := v_corpo || '<tr><td>' || rec.pid_bloqueado || '</td><td>' || rec.pid_bloqueante || '</td><td>' ||
                   ROUND(rec.tempo_min)::TEXT || '</td><td>' || substring(rec.query_text from 1 for 200) || '</td></tr>';
    END LOOP;
    v_corpo := v_corpo || '</table>';
    IF v_alerta THEN
        PERFORM grava_email(v_assunto, v_corpo);
    END IF;
END;
$$ LANGUAGE plpgsql;

/*
  Alerta: fragmentação/bloat
  Exige a extensão pgstattuple. Calcula bloat para cada tabela do schema público e grava email se superior ao limite.
*/
CREATE OR REPLACE FUNCTION fn_alerta_fragmentacao_indice() RETURNS VOID AS $$
DECLARE
    v_limite NUMERIC := get_parametro('limite_bloat_pct')::NUMERIC;
    v_alerta BOOLEAN := FALSE;
    v_assunto TEXT := 'Alerta: Bloat em Tabelas/Índices';
    v_corpo   TEXT := '<h3>Bloat Detected</h3><table border="1" cellpadding="3" cellspacing="0">' ||
                      '<tr><th>Tabela</th><th>Bloat %</th></tr>';
BEGIN
    -- Verifica se a extensão pgstattuple está instalada
    PERFORM 1 FROM pg_extension WHERE extname = 'pgstattuple';
    IF NOT FOUND THEN
        RETURN;
    END IF;
    FOR rec IN
        SELECT schemaname, tablename,
               (pgstattuple(schemaname || '.' || tablename)).approximate_percent_dead_tuples AS bloat_pct
          FROM pg_tables
         WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
    LOOP
        IF rec.bloat_pct >= v_limite THEN
            v_alerta := TRUE;
            v_corpo := v_corpo || '<tr><td>' || rec.schemaname || '.' || rec.tablename || '</td><td>' ||
                       ROUND(rec.bloat_pct,2)::TEXT || '%</td></tr>';
        END IF;
    END LOOP;
    v_corpo := v_corpo || '</table>';
    IF v_alerta THEN
        PERFORM grava_email(v_assunto, v_corpo);
    END IF;
END;
$$ LANGUAGE plpgsql;

/*
  Alerta: sessões longas
  Identifica queries em execução acima do limite definido.
*/
CREATE OR REPLACE FUNCTION fn_alerta_sessoes_longas() RETURNS VOID AS $$
DECLARE
    v_limite INTEGER := get_parametro('limite_tempo_query_min')::INTEGER;
    v_alerta BOOLEAN := FALSE;
    v_assunto TEXT := 'Alerta: Sessões Longas';
    v_corpo   TEXT := '<h3>Sessões de Longa Duração</h3><table border="1" cellpadding="3" cellspacing="0">' ||
                      '<tr><th>PID</th><th>Usuário</th><th>Tempo (min)</th><th>Query</th></tr>';
BEGIN
    FOR rec IN
        SELECT pid, usename, EXTRACT(EPOCH FROM (NOW() - query_start))/60 AS tempo_min, query
          FROM pg_stat_activity
         WHERE state = 'active'
           AND (NOW() - query_start) > (v_limite * INTERVAL '1 minute')
    LOOP
        v_alerta := TRUE;
        v_corpo := v_corpo || '<tr><td>' || rec.pid || '</td><td>' || rec.usename || '</td><td>' ||
                   ROUND(rec.tempo_min)::TEXT || '</td><td>' || substring(rec.query from 1 for 200) || '</td></tr>';
    END LOOP;
    v_corpo := v_corpo || '</table>';
    IF v_alerta THEN
        PERFORM grava_email(v_assunto, v_corpo);
    END IF;
END;
$$ LANGUAGE plpgsql;

/*
  Alerta: deadlock
  PostgreSQL registra deadlocks no log do servidor; para capturá‑los é necessário que a configuração
  log_lock_waits esteja ativa. Este alerta verifica a tabela de estatísticas pg_stat_database_conflicts
  para detectar deadlocks recentes.
*/
CREATE OR REPLACE FUNCTION fn_alerta_deadlock() RETURNS VOID AS $$
DECLARE
    v_assunto TEXT := 'Alerta: Deadlock Detectado';
    v_corpo   TEXT;
    v_count   INTEGER;
BEGIN
    SELECT SUM(conflicts) INTO v_count
      FROM pg_stat_database_conflicts;
    IF v_count IS NULL THEN
        v_count := 0;
    END IF;
    IF v_count > 0 THEN
        v_corpo := '<p>Foram detectados ' || v_count || ' conflitos (deadlocks) desde o último reset das estatísticas.</p>';
        PERFORM grava_email(v_assunto, v_corpo);
    END IF;
END;
$$ LANGUAGE plpgsql;

/*
  Agendamento via pg_cron
  Se a extensão estiver instalada, cria entradas de cron para cada alerta ativo.
*/
DO $$
DECLARE
    rec RECORD;
    v_exists BOOLEAN;
BEGIN
    -- Verifica se pg_cron está instalado
    SELECT TRUE INTO v_exists FROM pg_extension WHERE extname = 'pg_cron';
    IF NOT FOUND THEN
        RAISE NOTICE 'pg_cron não está instalado; agende funções manualmente via cron do sistema.';
        RETURN;
    END IF;
    -- Para cada alerta ativo, agendar via cron.schedule
    FOR rec IN SELECT id_alerta, nome_alerta, funcao, frequencia_min FROM alertas WHERE ativo = TRUE LOOP
        -- Remove agendamento existente
        PERFORM cron.unschedule(jobid) FROM cron.job WHERE command LIKE format('%%monitoring.%s%%', rec.funcao);
        -- Cria nova agenda (a cada frequencia_min minutos)
        PERFORM cron.schedule(
            format('*/%s * * * *', rec.frequencia_min),
            format('SELECT monitoring.%s()', rec.funcao)
        );
    END LOOP;
END$$;

-- Observação: se não usar pg_cron, utilize o cron do SO para chamar as funções periodicamente:
--  psql -c "SELECT monitoring.fn_alerta_espaco_tbs();"