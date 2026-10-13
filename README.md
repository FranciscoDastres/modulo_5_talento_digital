# Alke Wallet - Módulo 5

Proyecto de **Fundamentos de bases de datos relacionales** para Talento Digital. Implementa el modelo y las consultas SQL solicitadas en el ABP de Alke Wallet.

## Entrega de la evaluación

- [Documento Word con todas las sentencias SQL y capturas](output/entrega/AlkeWallet_Modulo5.docx).
- [Copia PDF del documento](output/pdf/AlkeWallet_Modulo5.pdf).
- [Modelo entidad-relación en PDF](output/pdf/modelo_entidad_relacion.pdf).
- [Modelo ER editable en DBML](docs/modelo.dbml).
- [Script SQL completo](AlkeWallet.sql).

El **Word es el entregable principal** solicitado por el enunciado. Contiene el diseño conceptual, cardinalidades, normalización hasta 3FN, propiedades ACID, sentencias DDL/DML y resultados de ejecución. El repositorio sirve como respaldo del proyecto.

## Requerimientos implementados

- Base de datos `AlkeWallet` y tablas `usuario`, `moneda` y `transaccion`.
- Claves primarias y foráneas, atributos obligatorios, unicidad, restricciones e índices.
- Consulta de la moneda elegida por un usuario.
- Consulta de todas las transacciones y de los movimientos de un usuario.
- Actualización del correo electrónico y eliminación de una fila completa.
- SELECT, WHERE, JOIN, subconsultas, COUNT, SUM y GROUP BY.
- Datos de prueba y actualización de saldos mediante transferencias.
- START TRANSACTION, COMMIT, ROLLBACK y reversión de un error referencial.
- Modelo ER, cardinalidades, opcionalidades y explicación de 1FN, 2FN y 3FN.
- Capturas de creación, consultas, estructura de tablas y transaccionalidad.

Se incluyen también la vista de hasta cinco usuarios con mayor saldo **por moneda**, `ALTER TABLE` para la fecha de creación y el ERD exportado en PDF, ejercicios opcionales del mismo ABP.

## Organización de los SQL

| Archivo | Contenido |
| --- | --- |
| `sql/01_estructura.sql` | Base, tablas, claves, restricciones, índices, ALTER TABLE y vista. |
| `sql/02_transferencias.sql` | Validación de monedas y procedimiento transaccional. |
| `sql/03_datos.sql` | Tres monedas, seis usuarios ficticios y tres transferencias. |
| `sql/04_consultas.sql` | Consultas exigidas, JOIN, filtros, subconsultas y agregaciones. |
| `sql/05_dml_y_rollback.sql` | UPDATE de correo, modificación de saldo y DELETE reversible. |
| `sql/06_error_referencial.sql` | Error de FK después de un débito y ROLLBACK completo. |
| `sql/07_inspeccion.sql` | SHOW TABLES, DESCRIBE, SHOW CREATE TABLE y comprobación de fondos. |

`AlkeWallet.sql` reúne los siete archivos en ese orden. Se ejecuta una sola vez en una base nueva y no borra bases existentes.

## Ejecutar en MySQL

Requiere **MySQL 8.0.16 o superior**, con motor InnoDB. En un servidor propio:

```bash
mysql -u TU_USUARIO -p < AlkeWallet.sql
```

También se puede utilizar SQLTools con su controlador MySQL/MariaDB en VS Code. Configurar la conexión al servidor y ejecutar los archivos del 01 al 07. `DELIMITER` es una instrucción del cliente: si el editor no la admite, ejecutar cada bloque de procedimiento/trigger como una sola sentencia, sin las líneas `DELIMITER`, o utilizar el cliente `mysql`.

El enunciado admite SQLOnline u otra plataforma equivalente. Las evidencias corresponden a **MySQL 8.0.46 real en Docker**.

## Verificar integridad y ACID

Se incluyen `compose.yaml` y `scripts/verificar.py` para reproducir las comprobaciones SQL del proyecto. Requisitos: Docker con Compose y Python 3; el script usa únicamente la biblioteca estándar.

En un contenedor nuevo:

```bash
docker compose up -d --wait
python3 scripts/verificar.py
```

El verificador instala el SQL y prueba restricciones, consultas, ROLLBACK, gastos concurrentes y persistencia tras reiniciar MySQL. Si `AlkeWallet` ya existe, se detiene sin sobrescribirla. El servicio es exclusivo de este proyecto y no publica puertos al host.

Para repetir desde cero, **descartando únicamente los datos de demostración de este proyecto**:

```bash
docker compose down --volumes
docker compose up -d --wait
python3 scripts/verificar.py
```

Para conservar los datos: `docker compose stop` y `docker compose start`.

## Evidencias y resultados

La ejecución registrada aprobó **31 pruebas** en MySQL 8.0.46:

- [Resultados y detalle de las pruebas](output/evidencias/resultados.json).
- [Salida completa del cliente MySQL](output/evidencias/ejecucion_mysql.txt).
- [Sentencias adicionales de validación](output/evidencias/validacion.sql).
- [Diagrama ER](output/evidencias/modelo_er.png).
- [Captura de creación de la base](output/playwright/01_creacion.png).
- [Captura del historial con JOIN](output/playwright/02_join.png).
- [Captura de las tres tablas](output/playwright/03_ddl.png).
- [Captura de COMMIT y ROLLBACK](output/playwright/04_commit_rollback.png).
- [Captura de consultas y agregaciones](output/playwright/05_consultas.png).

Los archivos de texto `01_creacion.txt` a `05_consultas.txt` conservan la salida original presentada en las capturas. `validacion.sql` contiene errores intencionales y restauración de pruebas; es evidencia y **no se utiliza como instalador**.

Estado final: tres monedas, seis usuarios y tres movimientos iniciales. Fondos conservados por moneda: **225000 CLP, 750 USD y 200 EUR**.

## Decisiones del modelo

Cada usuario tiene una moneda actual y un saldo `DECIMAL(15,2)`. Cada transacción conserva la moneda histórica del movimiento. Una wallet con saldo cero puede cambiar de divisa; no se realizan conversiones.

Las transferencias se ejecutan con `CALL transferir(emisor, receptor, importe)` fuera de una transacción abierta. El procedimiento valida participantes, monedas y fondos; bloquea ambos usuarios por orden de ID; actualiza saldos e historial juntos mediante COMMIT o ROLLBACK.

El DELETE solicitado elimina una fila dentro de una demostración y luego la restaura con ROLLBACK, conservando el historial financiero. Los saldos de apertura preceden a las transferencias registradas. Los nombres y correos son ficticios y `contrasena` contiene un hash de ejemplo; la autenticación está fuera del alcance de este módulo.
