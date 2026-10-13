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
