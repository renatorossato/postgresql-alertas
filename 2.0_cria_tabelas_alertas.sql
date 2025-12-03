--
-- Objetivo: criar as tabelas de configuração e log para os alertas, bem como carregar parâmetros padrão.
-- Banco alvo: PostgreSQL 12 ou superior.
-- Responsável: Adaptado do Script_SQLServer_Alerts.
-- Histórico de versões:
--   v1.0 - Criação inicial de tabelas e parâmetros.

SET search_path TO monitoring, public;

-- Criar tabela principal de alertas
CREATE TABLE IF NOT EXISTS alertas (
    id_alerta     SERIAL PRIMARY KEY,
    nome_alerta   VARCHAR(100) NOT NULL,
    descricao     TEXT,
    funcao        VARCHAR(200) NOT NULL,
    frequencia_min INTEGER NOT NULL DEFAULT 5,
    ativo         BOOLEAN NOT NULL DEFAULT TRUE,
    data_criacao  TIMESTAMP DEFAULT NOW()
);

-- Tabela de parâmetros de configuração
CREATE TABLE IF NOT EXISTS parametros_alerta (
    id_parametro  SERIAL PRIMARY KEY,
    nome_parametro VARCHAR(100) UNIQUE NOT NULL,
    valor          TEXT NOT NULL,
    descricao      TEXT,
    data_criacao   TIMESTAMP DEFAULT NOW()
);

-- Tabela de customização por alerta
CREATE TABLE IF NOT EXISTS alertas_customizacao (
    id_customizacao SERIAL PRIMARY KEY,
    id_alerta       INTEGER REFERENCES alertas(id_alerta),
    chave           VARCHAR(100) NOT NULL,
    valor           TEXT NOT NULL
);

-- Exemplos de tabelas de log
CREATE TABLE IF NOT EXISTS log_espaco_tbs (
    id_log        SERIAL PRIMARY KEY,
    nome_tablespace TEXT NOT NULL,
    pct_utilizado  NUMERIC(5,2),
    tamanho_gb     NUMERIC(10,2),
    livre_gb       NUMERIC(10,2),
    data_evento    TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS log_bloqueio (
    id_log        SERIAL PRIMARY KEY,
    pid_bloqueado  INTEGER,
    pid_bloqueante INTEGER,
    tempo_bloqueio_min INTEGER,
    query_bloqueada  TEXT,
    data_evento    TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS log_bloat (
    id_log        SERIAL PRIMARY KEY,
    schema_name    TEXT,
    table_name     TEXT,
    bloat_pct      NUMERIC(5,2),
    data_evento    TIMESTAMP DEFAULT NOW()
);

-- Carregar alertas padrão
INSERT INTO alertas (nome_alerta, descricao, funcao, frequencia_min, ativo)
VALUES
    ('Espaço em Tablespace', 'Monitora uso de tablespaces e dispara alerta quando percentual excede limite.', 'fn_alerta_espaco_tbs', 30, TRUE),
    ('Processos Bloqueados', 'Identifica processos bloqueados além do tempo configurado.', 'fn_alerta_processo_bloqueado', 5, TRUE),
    ('Fragmentação/Bloat', 'Detecta bloat em tabelas/índices (requer pgstattuple).', 'fn_alerta_fragmentacao_indice', 1440, TRUE),
    ('Sessões Longas', 'Detecta queries em execução acima do tempo configurado.', 'fn_alerta_sessoes_longas', 10, TRUE),
    ('Deadlock', 'Monitora eventos de deadlock (requer configuração de log_line_prefix).', 'fn_alerta_deadlock', 5, TRUE);

-- Carregar parâmetros padrão
INSERT INTO parametros_alerta (nome_parametro, valor, descricao)
VALUES
    ('limite_tablespace_pct', '80', 'Percentual de uso de tablespace para disparo de alerta'),
    ('limite_cpu_pct', '90', 'Percentual de uso de CPU para alerta de alto consumo'),
    ('limite_tempo_query_min', '15', 'Tempo em minutos para considerar uma query longa'),
    ('limite_bloat_pct', '30', 'Percentual de bloat para disparo de alerta'),
    ('email_from', 'monitor@empresa.com', 'Remetente padrão para alertas'),
    ('email_to', 'dba@empresa.com', 'Destinatários padrão, separados por vírgula');

COMMIT;

-- Observação: adicione mais tabelas de log e parâmetros conforme novos alertas forem implementados.