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
