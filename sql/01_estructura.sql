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
