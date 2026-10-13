-- ALKE WALLET - MODULO 5 - POSTGRESQL
-- Ejecutar una sola vez en una base nueva con psql.
-- En pgAdmin: ejecutar CREATE DATABASE, abrir alkewallet y omitir \connect.

-- 1. Crear y conectar la base de datos.
CREATE DATABASE alkewallet;
\connect alkewallet

-- 2. Crear las tres tablas con claves y restricciones.
CREATE TABLE moneda (
    currency_id SERIAL PRIMARY KEY,
    currency_name VARCHAR(60) NOT NULL UNIQUE,
    currency_symbol VARCHAR(10) NOT NULL
);

CREATE TABLE usuario (
    user_id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    correo_electronico VARCHAR(100) NOT NULL UNIQUE,
    contrasena VARCHAR(255) NOT NULL,
    saldo NUMERIC(12,2) NOT NULL CHECK (saldo >= 0),
    currency_id INTEGER NOT NULL REFERENCES moneda(currency_id)
);

CREATE TABLE transaccion (
    transaction_id SERIAL PRIMARY KEY,
    sender_user_id INTEGER NOT NULL REFERENCES usuario(user_id),
    receiver_user_id INTEGER NOT NULL REFERENCES usuario(user_id),
    currency_id INTEGER NOT NULL REFERENCES moneda(currency_id),
    importe NUMERIC(12,2) NOT NULL CHECK (importe > 0),
    transaction_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (sender_user_id <> receiver_user_id)
);

CREATE INDEX idx_emisor_fecha ON transaccion(sender_user_id, transaction_date);
CREATE INDEX idx_receptor_fecha ON transaccion(receiver_user_id, transaction_date);

-- 3. Insertar datos ficticios; los hash_demo no son contraseñas reales.
INSERT INTO moneda (currency_name, currency_symbol) VALUES
    ('Peso chileno', '$'), ('Dolar estadounidense', 'US$');
INSERT INTO usuario (nombre, correo_electronico, contrasena, saldo, currency_id) VALUES
    ('Ana Torres', 'ana@example.com', 'hash_demo_ana', 100000, 1),
    ('Bruno Diaz', 'bruno@example.com', 'hash_demo_bruno', 50000, 1),
    ('Carla Soto', 'carla@example.com', 'hash_demo_carla', 75000, 1);

-- 4. Transferencias de ejemplo: actualizar saldos y registrar cada movimiento.
-- Todos los participantes de estos ejemplos usan pesos chilenos.
BEGIN;
UPDATE usuario SET saldo = saldo - 10000 WHERE user_id = 1;
UPDATE usuario SET saldo = saldo + 10000 WHERE user_id = 2;
INSERT INTO transaccion (sender_user_id, receiver_user_id, currency_id, importe)
VALUES (1, 2, 1, 10000);
COMMIT;

BEGIN;
UPDATE usuario SET saldo = saldo - 5000 WHERE user_id = 2;
UPDATE usuario SET saldo = saldo + 5000 WHERE user_id = 3;
INSERT INTO transaccion (sender_user_id, receiver_user_id, currency_id, importe)
VALUES (2, 3, 1, 5000);
COMMIT;

-- 5. Consultas solicitadas.
-- Moneda elegida por el usuario 1.
SELECT u.nombre, m.currency_name AS moneda
FROM usuario u JOIN moneda m ON u.currency_id = m.currency_id
WHERE u.user_id = 1;

-- Todas las transacciones con nombres de emisor y receptor.
SELECT t.transaction_id, e.nombre AS emisor, r.nombre AS receptor,
       t.importe, m.currency_name AS moneda, t.transaction_date
FROM transaccion t
JOIN usuario e ON t.sender_user_id = e.user_id
JOIN usuario r ON t.receiver_user_id = r.user_id
JOIN moneda m ON t.currency_id = m.currency_id
ORDER BY t.transaction_id;

-- Transacciones enviadas por el usuario 1.
SELECT * FROM transaccion WHERE sender_user_id = 1;

-- SELECT basico, filtros, subconsulta y agregaciones.
SELECT user_id, nombre, saldo FROM usuario ORDER BY user_id;
SELECT nombre, saldo FROM usuario WHERE saldo >= 60000 AND currency_id = 1;
SELECT u.nombre, (SELECT COUNT(*) FROM transaccion t
    WHERE t.sender_user_id = u.user_id OR t.receiver_user_id = u.user_id) AS movimientos
FROM usuario u;
SELECT currency_id, COUNT(*) AS cantidad, SUM(importe) AS total
FROM transaccion GROUP BY currency_id;

-- 6. Modificar el correo electronico de un usuario especifico.
UPDATE usuario SET correo_electronico = 'ana.torres@example.com' WHERE user_id = 1;
SELECT nombre, correo_electronico FROM usuario WHERE user_id = 1;

-- 7. Borrar una fila y revertir el ejemplo para conservar el historial.
BEGIN;
DELETE FROM transaccion WHERE transaction_id = 2;
SELECT COUNT(*) AS filas_tras_delete FROM transaccion WHERE transaction_id = 2;
ROLLBACK;
SELECT COUNT(*) AS filas_tras_rollback FROM transaccion WHERE transaction_id = 2;

-- 8. Inspeccionar tablas y columnas (equivalente a DESCRIBE en PostgreSQL).
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' ORDER BY table_name;
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;

-- 9. Error referencial: ejecutar este bloque POR SEPARADO, sin /* y */.
-- El receptor 999 no existe: el INSERT falla y ROLLBACK deshace el debito.
/*
BEGIN;
UPDATE usuario SET saldo = saldo - 100 WHERE user_id = 1;
INSERT INTO transaccion (sender_user_id, receiver_user_id, currency_id, importe)
VALUES (1, 999, 1, 100);
ROLLBACK;
SELECT nombre, saldo FROM usuario WHERE user_id = 1;
*/
