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
