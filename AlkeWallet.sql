-- Alke Wallet | Evaluación módulo 5 | MySQL 8.0.16 o superior

-- ARCHIVO: 01_estructura.sql
-- Lección 1 y 4: creación de la base y de las tres entidades.
-- Ejecutar una sola vez en una base nueva; no se borran bases existentes.
CREATE DATABASE AlkeWallet
    CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE AlkeWallet;
SHOW DATABASES LIKE 'AlkeWallet';

CREATE TABLE moneda (
    currency_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    currency_name VARCHAR(60) NOT NULL,
    currency_symbol VARCHAR(10) NOT NULL,
    currency_code CHAR(3) NOT NULL,
    CONSTRAINT uq_moneda_nombre UNIQUE (currency_name),
    CONSTRAINT uq_moneda_codigo UNIQUE (currency_code)
) ENGINE = InnoDB;

CREATE TABLE usuario (
    user_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    correo_electronico VARCHAR(254) NOT NULL,
    contrasena VARCHAR(255) NOT NULL COMMENT 'Hash; nunca contraseña en texto plano',
    saldo DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    currency_id INT UNSIGNED NOT NULL,
    CONSTRAINT uq_usuario_correo UNIQUE (correo_electronico),
    CONSTRAINT chk_usuario_saldo CHECK (saldo >= 0),
    CONSTRAINT chk_usuario_nombre CHECK (CHAR_LENGTH(TRIM(nombre)) > 0),
    CONSTRAINT chk_usuario_correo CHECK (correo_electronico LIKE '%_@_%._%'),
    CONSTRAINT fk_usuario_moneda FOREIGN KEY (currency_id)
        REFERENCES moneda(currency_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

-- Plus de la lección 4: modificación de una tabla mediante ALTER TABLE.
ALTER TABLE usuario ADD COLUMN fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

CREATE TABLE transaccion (
    transaction_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sender_user_id INT UNSIGNED NOT NULL,
    receiver_user_id INT UNSIGNED NOT NULL,
    currency_id INT UNSIGNED NOT NULL,
    importe DECIMAL(15,2) NOT NULL,
    transaction_date DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT chk_transaccion_importe CHECK (importe > 0),
    CONSTRAINT chk_transaccion_participantes CHECK (sender_user_id <> receiver_user_id),
    CONSTRAINT fk_transaccion_emisor FOREIGN KEY (sender_user_id)
        REFERENCES usuario(user_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_transaccion_receptor FOREIGN KEY (receiver_user_id)
        REFERENCES usuario(user_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_transaccion_moneda FOREIGN KEY (currency_id)
        REFERENCES moneda(currency_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    INDEX idx_transaccion_emisor_fecha (sender_user_id, transaction_date),
    INDEX idx_transaccion_receptor_fecha (receiver_user_id, transaction_date)
) ENGINE = InnoDB;

-- Plus de lección 2: se comparan saldos dentro de la misma moneda.
CREATE VIEW vista_top_5_saldos AS
SELECT user_id, nombre, saldo, currency_code
FROM (
    SELECT u.user_id, u.nombre, u.saldo, m.currency_code,
           ROW_NUMBER() OVER (PARTITION BY u.currency_id ORDER BY u.saldo DESC, u.user_id) AS posicion
    FROM usuario u INNER JOIN moneda m ON m.currency_id = u.currency_id
) AS ranking
WHERE posicion <= 5;


-- ARCHIVO: 02_transferencias.sql
USE AlkeWallet;
-- La moneda actual del usuario y la histórica de una transacción son atributos distintos.
-- El cambio de moneda solo es válido con saldo cero; no hay conversión de divisas.
DELIMITER $$
CREATE TRIGGER validar_cambio_moneda BEFORE UPDATE ON usuario
FOR EACH ROW
BEGIN
    IF NEW.currency_id <> OLD.currency_id AND (OLD.saldo <> 0 OR NEW.saldo <> 0) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cambio de moneda requiere saldo cero';
    END IF;
END$$

CREATE TRIGGER validar_moneda_transaccion BEFORE INSERT ON transaccion
FOR EACH ROW
BEGIN
    DECLARE v_emisor INT UNSIGNED;
    DECLARE v_receptor INT UNSIGNED;
    SET v_emisor = (SELECT currency_id FROM usuario WHERE user_id = NEW.sender_user_id);
    SET v_receptor = (SELECT currency_id FROM usuario WHERE user_id = NEW.receiver_user_id);
    -- Si falta un participante, se deja a la FK generar su error de integridad.
    IF v_emisor IS NOT NULL AND v_receptor IS NOT NULL
       AND (NEW.currency_id <> v_emisor OR NEW.currency_id <> v_receptor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Moneda de transaccion incompatible';
    END IF;
END$$
DELIMITER ;

-- Llamar fuera de una transacción abierta: el procedimiento administra COMMIT/ROLLBACK.
-- Orden fijo de bloqueo de usuarios para reducir conflictos concurrentes.
DELIMITER $$
CREATE PROCEDURE transferir(
    IN p_emisor INT UNSIGNED,
    IN p_receptor INT UNSIGNED,
    IN p_importe DECIMAL(15,2)
)
BEGIN
    DECLARE v_saldo DECIMAL(15,2);
    DECLARE v_moneda_emisor INT UNSIGNED;
    DECLARE v_moneda_receptor INT UNSIGNED;
    DECLARE v_id_bloqueado INT UNSIGNED;
    DECLARE v_falta_usuario BOOLEAN DEFAULT FALSE;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_falta_usuario = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_emisor IS NULL OR p_receptor IS NULL OR p_emisor = p_receptor THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Participantes invalidos';
    END IF;
    IF p_importe IS NULL OR p_importe <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El importe debe ser positivo';
    END IF;

    START TRANSACTION;
    SELECT user_id INTO v_id_bloqueado FROM usuario
        WHERE user_id = LEAST(p_emisor, p_receptor) FOR UPDATE;
    SELECT user_id INTO v_id_bloqueado FROM usuario
        WHERE user_id = GREATEST(p_emisor, p_receptor) FOR UPDATE;
    IF v_falta_usuario THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario inexistente';
    END IF;
    SELECT saldo, currency_id INTO v_saldo, v_moneda_emisor
        FROM usuario WHERE user_id = p_emisor;
    SELECT currency_id INTO v_moneda_receptor
        FROM usuario WHERE user_id = p_receptor;
    IF v_moneda_emisor <> v_moneda_receptor THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Los usuarios deben utilizar la misma moneda';
    END IF;
    IF v_saldo < p_importe THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Saldo insuficiente';
    END IF;

    UPDATE usuario SET saldo = saldo - p_importe WHERE user_id = p_emisor;
    UPDATE usuario SET saldo = saldo + p_importe WHERE user_id = p_receptor;
    INSERT INTO transaccion (sender_user_id, receiver_user_id, currency_id, importe)
        VALUES (p_emisor, p_receptor, v_moneda_emisor, p_importe);
    COMMIT;
END$$
DELIMITER ;


-- ARCHIVO: 03_datos.sql
USE AlkeWallet;
-- Datos ficticios. El hash bcrypt es un valor de prueba, sin autenticación en este módulo.
START TRANSACTION;
INSERT INTO moneda (currency_id, currency_name, currency_symbol, currency_code) VALUES
    (1, 'Peso chileno', '$', 'CLP'),
    (2, 'Dólar estadounidense', 'US$', 'USD'),
    (3, 'Euro', '€', 'EUR');
INSERT INTO usuario (user_id, nombre, correo_electronico, contrasena, saldo, currency_id) VALUES
    (1, 'Ana Torres', 'ana@example.com', '$2b$12$R9h/cIPz0gi.URNNX3kh2OPST9/PgBkqquzi.Ss7KIUgO2t0jWMUW', 100000.00, 1),
    (2, 'Bruno Díaz', 'bruno@example.com', '$2b$12$R9h/cIPz0gi.URNNX3kh2OPST9/PgBkqquzi.Ss7KIUgO2t0jWMUW', 50000.00, 1),
    (3, 'Carla Soto', 'carla@example.com', '$2b$12$R9h/cIPz0gi.URNNX3kh2OPST9/PgBkqquzi.Ss7KIUgO2t0jWMUW', 75000.00, 1),
    (4, 'Diego Rojas', 'diego@example.com', '$2b$12$R9h/cIPz0gi.URNNX3kh2OPST9/PgBkqquzi.Ss7KIUgO2t0jWMUW', 300.00, 2),
    (5, 'Elena Pérez', 'elena@example.com', '$2b$12$R9h/cIPz0gi.URNNX3kh2OPST9/PgBkqquzi.Ss7KIUgO2t0jWMUW', 450.00, 2),
    (6, 'Francisca León', 'francisca@example.com', '$2b$12$R9h/cIPz0gi.URNNX3kh2OPST9/PgBkqquzi.Ss7KIUgO2t0jWMUW', 200.00, 3);
COMMIT;

-- Las tres transacciones iniciales modifican los saldos y registran el historial juntas.
CALL transferir(1, 2, 25000.00);
CALL transferir(2, 3, 10000.00);
CALL transferir(5, 4, 50.00);


-- ARCHIVO: 04_consultas.sql
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


-- ARCHIVO: 05_dml_y_rollback.sql
USE AlkeWallet;
-- Requerimiento: modificar el correo de un usuario específico y confirmar.
START TRANSACTION;
UPDATE usuario SET correo_electronico = 'ana.torres@example.com' WHERE user_id = 1;
COMMIT;
SELECT user_id, nombre, correo_electronico FROM usuario WHERE user_id = 1;

-- ROLLBACK explícito de una modificación de saldo: el valor final se conserva.
SELECT saldo INTO @saldo_antes FROM usuario WHERE user_id = 1;
START TRANSACTION;
UPDATE usuario SET saldo = saldo - 100.00 WHERE user_id = 1;
SELECT saldo AS saldo_temporal FROM usuario WHERE user_id = 1;
ROLLBACK;
SELECT saldo AS saldo_final, @saldo_antes AS saldo_original FROM usuario WHERE user_id = 1;

-- Requerimiento: eliminar una fila completa de transaccion.
-- Ejemplo académico reversible para conservar el historial y los saldos de la entrega.
START TRANSACTION;
DELETE FROM transaccion WHERE transaction_id = 1;
SELECT COUNT(*) AS filas_despues_de_delete FROM transaccion WHERE transaction_id = 1;
ROLLBACK;
SELECT COUNT(*) AS filas_despues_de_rollback FROM transaccion WHERE transaction_id = 1;


-- ARCHIVO: 06_error_referencial.sql
USE AlkeWallet;
-- El procedimiento demuestra un error de FK después de modificar el saldo.
-- Un handler revierte TODA la operación, no solo el INSERT fallido.
DELIMITER $$
CREATE PROCEDURE demostrar_error_referencial()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Error de FK controlado: ROLLBACK completo' AS resultado;
    END;
    START TRANSACTION;
    UPDATE usuario SET saldo = saldo - 100.00 WHERE user_id = 1;
    INSERT INTO transaccion (sender_user_id, receiver_user_id, currency_id, importe)
        VALUES (1, 999999, 1, 100.00);
    COMMIT;
END$$
DELIMITER ;
CALL demostrar_error_referencial();
SELECT user_id, saldo FROM usuario WHERE user_id = 1;


-- ARCHIVO: 07_inspeccion.sql
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
