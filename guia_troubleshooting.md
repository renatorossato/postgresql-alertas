# Guia de Troubleshooting – PostgreSQL Alertas

Este guia fornece dicas para investigar problemas durante o uso da solução de monitoria no PostgreSQL.

## Funções não executam ou retornam erro

* **Permissões insuficientes**: verifique se o usuário possui acesso às views `pg_stat_*`. Para funções que executam `COPY PROGRAM` ou acessam arquivos do sistema, o PostgreSQL exige privilégios de superusuário. Se não for possível, ajuste a implementação para chamar utilitários via script externo.
* **Extensão pg_cron ausente**: se os jobs não estiverem sendo agendados, confirme se a extensão está instalada no banco (`CREATE EXTENSION pg_cron`). Caso não esteja disponível, opte por agendar as funções via cron do sistema.
* **Função não existe**: certifique‑se de que o search_path inclui o schema `monitoring` ou prefixe as chamadas com `monitoring.fn_alerta_espaco_tbs()`.

## Alertas não são enviados

* **Script de e‑mail não configurado**: lembre‑se de que as funções de alerta apenas inserem registros em tabelas; o envio de e‑mail é responsabilidade de um script externo. Verifique se o script está rodando no cron e se os registros de log estão sendo consumidos.
* **Dados de SMTP incorretos**: revise as variáveis de ambiente do script de e‑mail (host, porta, usuário, senha). Execute o script manualmente para validar.

## Jobs agendados pelo pg_cron não aparecem

* Confirme se `shared_preload_libraries` inclui `pg_cron` no arquivo `postgresql.conf` e reinicie o serviço.
* Verifique a tabela `cron.job` para confirmar se os jobs foram criados. Se não, recrie manualmente com `cron.schedule()`.
* Se a extensão não for carregada automaticamente, tente `CREATE EXTENSION pg_cron;` e reinicie.

## Consumo excessivo de recursos

* **Coletas pesadas**: funções que varrem tabelas ou calculam bloat podem consumir I/O. Programe‑as em horários de baixa demanda e limite a análise a bancos ou esquemas específicos.
* **Indices faltantes**: crie índices nas colunas de data das tabelas de log para acelerar consultas de seleção e purga.
* **Número de jobs**: evite agendar muitas tarefas simultâneas com pg_cron; use o parâmetro `max_running_jobs` para controlar concorrência.

## Manutenção e limpeza

* **Purgar dados antigos**: implemente rotinas para apagar registros de log com mais de 30 ou 90 dias para evitar crescimento excessivo das tabelas. Adicione job `cron.schedule('0 3 * * *', $$ DELETE FROM monitoring.log_espaco_tbs WHERE data_evento < NOW() - INTERVAL '90 days' $$);`.
* **Atualizações da solução**: ao atualizar scripts, faça backup das tabelas de parâmetros e log. Execute scripts de upgrade em ambiente de homologação antes de produção.

Se encontrar erros não documentados, registre um problema no repositório ou abra discussão com a comunidade para suporte.