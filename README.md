# Alke Wallet - Modulo 5

Base de datos en **PostgreSQL** para el ABP de Talento Digital.

- [AlkeWallet.sql](AlkeWallet.sql): tablas, datos de prueba, consultas y ejemplos de COMMIT/ROLLBACK.
- [AlkeWallet.docx](AlkeWallet.docx): entrega con explicacion, diagrama, todas las sentencias SQL y capturas.

## Como ejecutarlo

Con PostgreSQL instalado, ejecutar una sola vez:

```bash
psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f AlkeWallet.sql
```

En **pgAdmin**, ejecutar primero `CREATE DATABASE alkewallet;`. Abrir una consulta en esa base y ejecutar el resto del archivo, omitiendo la linea `\connect alkewallet`.

El ultimo bloque, comentado, se prueba por separado: provoca un error de clave foranea y muestra como revertirlo con `ROLLBACK`.

El proyecto contiene las tablas **usuario**, **moneda** y **transaccion**, las consultas solicitadas y ejemplos sencillos de manipulacion de datos. El DELETE se revierte para conservar los movimientos de muestra. Los datos son ficticios.

**Para entregar al curso:** subir `AlkeWallet.docx`.
