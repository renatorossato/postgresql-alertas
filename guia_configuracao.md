# Guia de Configuração – PostgreSQL Alertas

Este guia trata da configuração pós‑instalação da solução de monitoria em PostgreSQL.

## Configuração de envio de e‑mail

Ao contrário do SQL Server e do Oracle, o PostgreSQL não possui um mecanismo nativo de envio de e‑mail. Portanto, o envio de notificações deve ser realizado por um script externo que consulte as tabelas de log e envie e‑mails usando SMTP. O diretório `tools/scripts_envio_email` contém exemplos:

* **Python** (`envia_email.py`): script que usa a biblioteca `smtplib` para ler uma consulta e enviar o resultado como HTML.
* **Shell** (`envia_email.sh`): utiliza o utilitário `sendmail` ou `mailx` para enviar relatórios.

### Passos para configurar

1. **Crie uma tabela de log de mensagens** (já prevista nos scripts): os procedimentos de alerta inserem registros nela.
2. **Desenvolva um script externo** que se conecte ao banco via `psql`, execute uma query para ler os registros não enviados e envie por e‑mail. Após envio, marque as linhas como processadas.
3. **Agende o script via cron do sistema** para rodar a cada X minutos. Exemplo de entrada no `crontab`:
   ```cron
   */5 * * * * /usr/bin/python3 /caminho/para/envia_email.py >> /var/log/monitoring_email.log 2>&1
   ```
4. **Configure as variáveis de ambiente** com as credenciais do SMTP (host, porta, usuário, senha) de forma segura. Evite armazenar senhas em texto plano.

## Configuração de parâmetros e thresholds

Os parâmetros dos alertas ficam na tabela `monitoring.parametros_alerta`. Os principais são:

| Parâmetro                   | Descrição                                                       |
|----------------------------|-----------------------------------------------------------------|
| `limite_tablespace_pct`    | Percentual de uso de tablespace para disparo de alerta.         |
| `limite_cpu_pct`           | Percentual de CPU (em pg_stat_activity) para alerta de consumo. |
| `limite_tempo_query_min`   | Tempo em minutos para considerar uma consulta longa.            |
| `limite_bloat_pct`         | Percentual de bloat de tabela/índice (necessita pgstattuple).   |

Altere os valores de acordo com o perfil de uso do seu banco:

```sql
UPDATE monitoring.parametros_alerta SET valor = '85' WHERE nome_parametro = 'limite_tablespace_pct';
COMMIT;
```

## Agendamento de jobs com pg_cron

Se a extensão pg_cron estiver instalada, os alertas são automaticamente agendados no script `2.1_cria_procedures_e_jobs_postgresql.sql`. Para listar jobs:

```sql
SELECT jobid, schedule, command, nodename
  FROM cron.job
 WHERE command LIKE '%fn_alerta_%';
```

Para alterar a frequência de um job:

```sql
SELECT cron.unschedule(jobid) FROM cron.job WHERE command LIKE '%fn_alerta_espaco_tbs%';
SELECT cron.schedule('*/15 * * * *', $$ SELECT monitoring.fn_alerta_espaco_tbs() $$);
```

Caso não tenha pg_cron, adapte o agendamento para o `crontab` do sistema chamando `psql -c "SELECT monitoring.fn_alerta_espaco_tbs();"`.

## Boas práticas adicionais

1. **Vacuum e análise**: assegure que o autovacuum esteja funcionando e considere alertas para tabelas com autovacuum desativado. 
2. **Monitorar replication lag**: em ambientes com replicação streaming, consulte `pg_stat_replication` e dispare alertas quando `write_lag` ou `replay_lag` estiverem altos.
3. **Verificar bloat**: instale a extensão `pgstattuple` para medir bloat de tabelas e índices. O alerta `fn_alerta_fragmentacao_indice` utiliza essa extensão quando disponível.
4. **Ajustar configuração do autovacuum**: valores inadequados podem levar a bloat e degradação de performance. Utilize a monitoria para identificá‑los.