--
-- Objetivo: criar função de verificação de integridade de dados em PostgreSQL.
-- Diferente do SQL Server, PostgreSQL não possui comando interno semelhante a CHECKDB. 
-- Para detectar corrupção, pode‑se utilizar utilitários como pg_checksums (a partir do PostgreSQL 12) ou comparar pg_dump com restaurar.
-- Este script fornece uma função template que registra a execução e envia alerta via log_email em caso de falha.

SET search_path TO monitoring, public;

CREATE OR REPLACE FUNCTION fn_verifica_corrupcao() RETURNS VOID AS $$
DECLARE
    v_cmd TEXT;
    v_result TEXT;
    v_assunto TEXT := 'Alerta: Verificação de Corrupção';
BEGIN
    -- Exemplo usando pg_checksums em modo on-line para verificar bloco de checksums (executado via shell)
    -- O utilitário deve ser executado no sistema operacional; aqui apenas inserimos um registro de exemplo.
    v_result := 'OK'; -- substitua pela lógica de execução real (usar programa externo via cron e inserir resultado em tabela)
    IF v_result <> 'OK' THEN
        PERFORM grava_email(v_assunto, '<p>Foi detectado um possível problema de integridade: ' || v_result || '</p>');
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Agendamento via pg_cron (se instalado): verificar semanalmente na madrugada
DO $$
BEGIN
    PERFORM cron.unschedule(jobid) FROM cron.job WHERE command LIKE '%fn_verifica_corrupcao%';
    PERFORM cron.schedule('0 3 * * SUN', 'SELECT monitoring.fn_verifica_corrupcao()');
EXCEPTION WHEN UNDEFINED_TABLE OR UNDEFINED_FUNCTION THEN
    -- pg_cron não instalado ou função indisponível
    RAISE NOTICE 'pg_cron não instalado ou função inexistente; agende manualmente via cron do SO.';
END$$;