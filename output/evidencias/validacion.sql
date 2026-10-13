-- Sentencias efectivamente ejecutadas por verificar.py, sin repeticiones.
-- Archivo de evidencia: incluye errores intencionales y pruebas concurrentes.
-- No se ejecuta como script de instalación.

SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='AlkeWallet' AND table_type='BASE TABLE';

SELECT (SELECT COUNT(*) FROM moneda), (SELECT COUNT(*) FROM usuario), (SELECT COUNT(*) FROM transaccion);

SELECT saldo FROM usuario ORDER BY user_id;

SELECT correo_electronico FROM usuario WHERE user_id=1;

SELECT m.currency_name FROM usuario u JOIN moneda m ON m.currency_id=u.currency_id WHERE u.user_id=1;

SELECT COUNT(*) FROM transaccion WHERE sender_user_id=2 OR receiver_user_id=2;

SELECT currency_id, SUM(saldo) FROM usuario GROUP BY currency_id ORDER BY currency_id;

SELECT user_id, saldo, correo_electronico, currency_id FROM usuario ORDER BY user_id;

SELECT transaction_id, sender_user_id, receiver_user_id, currency_id, importe FROM transaccion ORDER BY transaction_id;

UPDATE usuario SET correo_electronico='bruno@example.com' WHERE user_id=1;

UPDATE usuario SET saldo=-1 WHERE user_id=1;

INSERT INTO transaccion(sender_user_id,receiver_user_id,currency_id,importe) VALUES(1,2,1,0);

INSERT INTO transaccion(sender_user_id,receiver_user_id,currency_id,importe) VALUES(1,1,1,1);

INSERT INTO transaccion(sender_user_id,receiver_user_id,currency_id,importe) VALUES(1,999999,1,1);

INSERT INTO transaccion(sender_user_id,receiver_user_id,currency_id,importe) VALUES(1,4,1,1);

DELETE FROM usuario WHERE user_id=1;

UPDATE usuario SET currency_id=2 WHERE user_id=1;

CALL transferir(1,2,999999.00);

CALL transferir(1,4,1.00);

CALL transferir(1,1,1.00);

CALL transferir(1,2,-1.00);

CALL transferir(1,2,NULL);

CALL transferir(NULL,2,1.00);

CALL transferir(1,999999,1.00);

CALL demostrar_error_referencial();

START TRANSACTION; DELETE FROM transaccion WHERE transaction_id=1; SELECT COUNT(*) FROM transaccion WHERE transaction_id=1; ROLLBACK;

CALL transferir(1,2,50000.00);

CALL transferir(1,3,50000.00);

SELECT saldo FROM usuario WHERE user_id=1;

SELECT receiver_user_id FROM transaccion ORDER BY transaction_id DESC LIMIT 1;

CALL transferir(2,1,50000.00);

START TRANSACTION; DELETE FROM transaccion WHERE transaction_id > 3; COMMIT;

CALL transferir(1,2,75000.00);

SELECT u.currency_id, t.currency_id FROM usuario u JOIN transaccion t ON t.sender_user_id=u.user_id WHERE u.user_id=1 AND t.transaction_id=1;

UPDATE usuario SET currency_id=1 WHERE user_id=1;

CALL transferir(2,1,75000.00);

SHOW DATABASES LIKE 'AlkeWallet'; SHOW TABLES; SELECT VERSION() AS mysql_version, @@transaction_isolation AS aislamiento;

SELECT t.transaction_id, e.nombre AS emisor, r.nombre AS receptor, t.importe, m.currency_code FROM transaccion t JOIN usuario e ON e.user_id=t.sender_user_id JOIN usuario r ON r.user_id=t.receiver_user_id JOIN moneda m ON m.currency_id=t.currency_id ORDER BY t.transaction_id;

DESCRIBE moneda; DESCRIBE usuario; DESCRIBE transaccion;

START TRANSACTION; UPDATE usuario SET correo_electronico='ana.torres@example.com' WHERE user_id=1; COMMIT; SELECT user_id, saldo, correo_electronico FROM usuario WHERE user_id=1; CALL demostrar_error_referencial(); START TRANSACTION; DELETE FROM transaccion WHERE transaction_id=1; SELECT COUNT(*) AS filas_tras_delete FROM transaccion WHERE transaction_id=1; ROLLBACK; SELECT COUNT(*) AS filas_tras_rollback FROM transaccion WHERE transaction_id=1;

SELECT u.nombre,m.currency_name AS moneda FROM usuario u JOIN moneda m ON m.currency_id=u.currency_id WHERE u.user_id=1; SELECT m.currency_code,COUNT(t.transaction_id) AS cantidad,COALESCE(SUM(t.importe),0) AS total FROM moneda m LEFT JOIN transaccion t ON t.currency_id=m.currency_id GROUP BY m.currency_id,m.currency_code ORDER BY m.currency_id;

SELECT VERSION();

SELECT user_id,nombre,saldo,currency_id FROM usuario ORDER BY user_id;

SELECT transaction_id,sender_user_id,receiver_user_id,importe FROM transaccion ORDER BY transaction_id;