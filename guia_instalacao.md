# Guia de Instalação – PostgreSQL Alertas

Este guia explica como instalar a solução de alertas e monitoria em um ambiente PostgreSQL.

## 1. Preparação do ambiente

1. **Versão do PostgreSQL**: recomenda‑se utilizar a versão 12 ou superior. A solução pode funcionar em versões anteriores com ajustes menores, mas algumas funções de catálogo podem não existir.
2. **Permissões**: o usuário que executará os scripts deve ter privilégios de superusuário ou permissões equivalentes para criar schemas, tabelas, funções, executar comandos `COPY PROGRAM` e acessar views de sistema (`pg_stat_*`, `pg_locks`, `pg_stat_activity`, etc.).
3. **Extensão pg_cron** (opcional): se desejar agendar jobs diretamente no PostgreSQL, instale a extensão pg_cron. Caso não seja possível, agende chamadas às funções via cron do SO.

## 2. Criação do schema de monitoria

Conecte‑se ao banco de dados onde deseja instalar a monitoria e execute:

```sql
CREATE SCHEMA IF NOT EXISTS monitoring;
ALTER ROLE current_user SET search_path = public, monitoring;
```

Isso garantirá que todos os objetos sejam criados no schema `monitoring`.

## 3. Execução dos scripts

1. **Tabelas e parâmetros**: execute `scripts/2.0_cria_tabelas_alertas.sql` para criar todas as tabelas necessárias e a carga inicial de parâmetros.
2. **Funções de alerta e jobs**: execute `scripts/2.1_cria_procedures_e_jobs_postgresql.sql` para criar as funções de monitoria e agendar os jobs via pg_cron (se instalado). Se não houver pg_cron, apenas as funções serão criadas; será necessário agendá‑las externamente.
3. **Verificação de corrupção** (opcional): execute `scripts/3.0_verifica_corrupcao.sql` para criar a função que verifica integridade através de `pg_checksums` ou `pg_dump`.
4. **Checklist diário**: execute `scripts/4.0_checklist_procedures_postgresql.sql` para criar as funções de checklist e agendar o job diário.

Todos os scripts devem ser executados conectado ao banco de dados como o usuário configurado. Para facilitar, utilize `psql` ou uma ferramenta como pgAdmin.

## 4. Ajuste de parâmetros

Após executar os scripts, personalize thresholds na tabela `monitoring.parametros_alerta`:

```sql
UPDATE monitoring.parametros_alerta SET valor = '80' WHERE nome_parametro = 'limite_tablespace_pct';
UPDATE monitoring.parametros_alerta SET valor = '15' WHERE nome_parametro = 'limite_tempo_query_min';
-- etc.
```

Verifique as descrições de cada parâmetro no script `2.0_cria_tabelas_alertas.sql`. Novos parâmetros podem ser adicionados conforme novas funções forem implementadas.

## 5. Testando a solução

Antes de utilizar em produção, teste cada alerta:

* **Espaço em tablespace**: crie uma tabela grande ou restrinja a quota para simular falta de espaço e verifique se a função `fn_alerta_espaco_tbs` registra eventos.
* **Processos bloqueados**: inicie duas sessões que bloqueiem uma à outra e execute `fn_alerta_processo_bloqueado`.
* **Bloat de índices**: se instalar a extensão `pgstattuple`, insira e delete registros repetidamente em uma tabela e execute `fn_alerta_fragmentacao_indice`.
* **Sessões longas**: execute uma consulta que dure mais de X minutos e chame `fn_alerta_sessoes_longas`.

Os resultados podem ser verificados nas tabelas de log (`log_espaco_tbs`, `log_bloqueio`, etc.) e no histórico do checklist.