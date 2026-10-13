USE AlkeWallet;
SHOW TABLES;
DESCRIBE moneda;
DESCRIBE usuario;
DESCRIBE transaccion;
SHOW CREATE TABLE moneda;
SHOW CREATE TABLE usuario;
SHOW CREATE TABLE transaccion;
SELECT VERSION() AS version_mysql, @@transaction_isolation AS aislamiento,
       @@innodb_flush_log_at_trx_commit AS persistencia_commit;
SELECT m.currency_code, SUM(u.saldo) AS saldo_total
FROM usuario u INNER JOIN moneda m ON m.currency_id = u.currency_id
GROUP BY m.currency_id, m.currency_code ORDER BY m.currency_id;
