USE AlkeWallet;
SET @usuario_id = 1;

-- Requerimiento: nombre de la moneda elegida por un usuario específico.
SELECT u.user_id, u.nombre, m.currency_name AS moneda, m.currency_symbol, m.currency_code
FROM usuario u INNER JOIN moneda m ON m.currency_id = u.currency_id
WHERE u.user_id = @usuario_id;

-- Requerimiento: todas las transacciones (JOIN exitoso con sus participantes).
SELECT t.transaction_id, emisor.nombre AS emisor, receptor.nombre AS receptor,
       t.importe, m.currency_code, t.transaction_date
FROM transaccion t
INNER JOIN usuario emisor ON emisor.user_id = t.sender_user_id
INNER JOIN usuario receptor ON receptor.user_id = t.receiver_user_id
INNER JOIN moneda m ON m.currency_id = t.currency_id
ORDER BY t.transaction_id;

-- Requerimiento: todas las transacciones realizadas por un usuario (enviadas).
SELECT * FROM transaccion WHERE sender_user_id = @usuario_id ORDER BY transaction_date, transaction_id;

-- Historial completo: tanto envíos como recepciones.
SELECT transaction_id, sender_user_id, receiver_user_id, importe, currency_id, transaction_date
FROM transaccion
WHERE sender_user_id = @usuario_id OR receiver_user_id = @usuario_id
ORDER BY transaction_date, transaction_id;

-- SELECT básico y filtros parametrizados con operadores lógicos.
SELECT user_id, nombre, correo_electronico, saldo, currency_id FROM usuario ORDER BY user_id;
SET @moneda_id = 1;
SET @saldo_minimo = 60000.00;
SELECT user_id, nombre, saldo FROM usuario
WHERE currency_id = @moneda_id AND saldo >= @saldo_minimo ORDER BY saldo DESC;

-- Subconsulta correlacionada: incluye usuarios sin transacciones.
SELECT u.user_id, u.nombre,
       (SELECT COUNT(*) FROM transaccion t
        WHERE t.sender_user_id = u.user_id OR t.receiver_user_id = u.user_id) AS total_transacciones
FROM usuario u ORDER BY u.user_id;

-- COUNT y SUM con GROUP BY: no se suman monedas diferentes.
SELECT m.currency_code, COUNT(t.transaction_id) AS cantidad, COALESCE(SUM(t.importe), 0) AS total_transferido
FROM moneda m LEFT JOIN transaccion t ON t.currency_id = m.currency_id
GROUP BY m.currency_id, m.currency_code ORDER BY m.currency_id;
SELECT * FROM vista_top_5_saldos ORDER BY currency_code, saldo DESC, user_id;
