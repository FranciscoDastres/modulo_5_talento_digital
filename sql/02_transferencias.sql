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
