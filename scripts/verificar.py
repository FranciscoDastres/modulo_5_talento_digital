#!/usr/bin/env python3
"""Ejecuta la entrega en MySQL real y conserva SQL, resultados y pruebas."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
import json
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/evidencias'
OUT.mkdir(parents=True, exist_ok=True)
COMMAND = ['docker', 'compose', 'exec', '-T', 'mysql', 'mysql', '-uroot', '--default-character-set=utf8mb4']
tests = []
executed = []


def mysql(sql, *, table=False, database=True):
    args = COMMAND + (['--table', '--verbose'] if table else ['--batch', '--raw'])
    if database:
        args += ['AlkeWallet']
    return subprocess.run(args, input=sql, text=True, capture_output=True, cwd=ROOT)


def query(sql):
    executed.append(sql)
    result = mysql(sql)
    if result.returncode:
        raise RuntimeError(result.stderr)
    lines = result.stdout.strip().splitlines()
    return [line.split('\t') for line in lines[1:]]


def check(label, condition, detail=''):
    tests.append({'prueba': label, 'estado': 'OK' if condition else 'FALLO', 'detalle': detail})
    print(f'{tests[-1]["estado"]}: {label}', flush=True)
    if not condition:
        raise AssertionError(f'{label}: {detail}')


def state():
    return query('SELECT user_id, saldo, correo_electronico, currency_id FROM usuario ORDER BY user_id;'), query(
        'SELECT transaction_id, sender_user_id, receiver_user_id, currency_id, importe FROM transaccion ORDER BY transaction_id;')


def reject(label, sql, expected):
    before = state()
    executed.append(sql)
    result = mysql(sql)
    ok = result.returncode != 0 and expected in result.stderr and state() == before
    check(label, ok, result.stderr.strip())


def main():
    sources = sorted((ROOT / 'sql').glob('0[1-7]_*.sql'))
    combined = '-- Alke Wallet | Evaluación módulo 5 | MySQL 8.0.16 o superior\n\n' + '\n\n'.join(
        f'-- ARCHIVO: {path.name}\n{path.read_text()}' for path in sources)
    (ROOT / 'AlkeWallet.sql').write_text(combined)
    exists = mysql("SHOW DATABASES LIKE 'AlkeWallet';", database=False)
    if 'AlkeWallet' in exists.stdout:
        raise RuntimeError('La base AlkeWallet ya existe en este contenedor. Utiliza un contenedor nuevo para repetir la instalación; no se borran datos automáticamente.')
    result = mysql(combined, table=True, database=False)
    (OUT / 'ejecucion_mysql.txt').write_text(result.stdout + result.stderr)
    check('Ejecución completa del SQL sin errores', result.returncode == 0, result.stderr.strip())
    check('Tres tablas base', query("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='AlkeWallet' AND table_type='BASE TABLE';") == [['3']])
    check('Tres monedas, seis usuarios y tres transacciones', query('SELECT (SELECT COUNT(*) FROM moneda), (SELECT COUNT(*) FROM usuario), (SELECT COUNT(*) FROM transaccion);') == [['3', '6', '3']])
    check('Saldos iniciales y transferencias confirmadas', query('SELECT saldo FROM usuario ORDER BY user_id;') == [['75000.00'], ['65000.00'], ['85000.00'], ['350.00'], ['400.00'], ['200.00']])
    check('Correo actualizado mediante COMMIT', query('SELECT correo_electronico FROM usuario WHERE user_id=1;') == [['ana.torres@example.com']])
    check('Moneda de un usuario', query('SELECT m.currency_name FROM usuario u JOIN moneda m ON m.currency_id=u.currency_id WHERE u.user_id=1;') == [['Peso chileno']])
    check('Historial de envíos y recepciones', query('SELECT COUNT(*) FROM transaccion WHERE sender_user_id=2 OR receiver_user_id=2;') == [['2']])
    check('Conservación de fondos por moneda', query('SELECT currency_id, SUM(saldo) FROM usuario GROUP BY currency_id ORDER BY currency_id;') == [['1', '225000.00'], ['2', '750.00'], ['3', '200.00']])
    reject('Rechazo de correo duplicado', "UPDATE usuario SET correo_electronico='bruno@example.com' WHERE user_id=1;", '1062')
    reject('Rechazo de saldo negativo', 'UPDATE usuario SET saldo=-1 WHERE user_id=1;', '3819')
    reject('Rechazo de importe cero en tabla', 'INSERT INTO transaccion(sender_user_id,receiver_user_id,currency_id,importe) VALUES(1,2,1,0);', '3819')
    reject('Rechazo de auto transferencia en tabla', 'INSERT INTO transaccion(sender_user_id,receiver_user_id,currency_id,importe) VALUES(1,1,1,1);', '3819')
    reject('FK rechaza receptor inexistente', 'INSERT INTO transaccion(sender_user_id,receiver_user_id,currency_id,importe) VALUES(1,999999,1,1);', '1452')
    reject('Trigger rechaza monedas incompatibles', 'INSERT INTO transaccion(sender_user_id,receiver_user_id,currency_id,importe) VALUES(1,4,1,1);', 'Moneda de transaccion incompatible')
    reject('No se puede borrar un usuario con historial', 'DELETE FROM usuario WHERE user_id=1;', '1451')
    reject('No se puede cambiar moneda con saldo disponible', 'UPDATE usuario SET currency_id=2 WHERE user_id=1;', 'saldo cero')
    reject('Saldo insuficiente revierte operación', 'CALL transferir(1,2,999999.00);', 'Saldo insuficiente')
    reject('Rechazo de transferencias entre monedas', 'CALL transferir(1,4,1.00);', 'misma moneda')
    reject('Rechazo de auto transferencia en procedimiento', 'CALL transferir(1,1,1.00);', 'Participantes invalidos')
    reject('Rechazo de importe negativo', 'CALL transferir(1,2,-1.00);', 'importe debe ser positivo')
    reject('Rechazo de importe nulo', 'CALL transferir(1,2,NULL);', 'importe debe ser positivo')
    reject('Rechazo de participante nulo', 'CALL transferir(NULL,2,1.00);', 'Participantes invalidos')
    reject('Rechazo de usuario inexistente', 'CALL transferir(1,999999,1.00);', 'Usuario inexistente')

    before = state()
    executed.append('CALL demostrar_error_referencial();')
    result = mysql('CALL demostrar_error_referencial();', table=True)
    check('Error de FK tras débito revierte saldo e historial', result.returncode == 0 and 'ROLLBACK completo' in result.stdout and state() == before)
    before = state()
    executed.append('START TRANSACTION; DELETE FROM transaccion WHERE transaction_id=1; SELECT COUNT(*) FROM transaccion WHERE transaction_id=1; ROLLBACK;')
    result = mysql(executed[-1])
    check('DELETE elimina la fila y ROLLBACK la restaura', result.returncode == 0 and result.stdout.strip().endswith('0') and state() == before)

    # Dos operaciones intentan gastar 50000 de un saldo de 75000 simultáneamente.
    commands = ['CALL transferir(1,2,50000.00);', 'CALL transferir(1,3,50000.00);']
    executed.extend(commands)
    with ThreadPoolExecutor(max_workers=2) as pool:
        concurrent = list(pool.map(mysql, commands))
    check('Concurrencia: solo un gasto confirma y el otro falla', sum(r.returncode == 0 for r in concurrent) == 1 and any('Saldo insuficiente' in r.stderr for r in concurrent))
    check('Concurrencia: saldo correcto sin sobregiro', query('SELECT saldo FROM usuario WHERE user_id=1;') == [['25000.00']])
    receiver = int(query('SELECT receiver_user_id FROM transaccion ORDER BY transaction_id DESC LIMIT 1;')[0][0])
    query(f'CALL transferir({receiver},1,50000.00);')
    # Restaurar la prueba completa dentro del entorno desechable, dejando la entrega base intacta.
    executed.append('START TRANSACTION; DELETE FROM transaccion WHERE transaction_id > 3; COMMIT;')
    result = mysql(executed[-1])
    check('Restauración de datos académicos tras prueba concurrente', result.returncode == 0 and state() == before)

    # El historial conserva su moneda aunque una wallet vacía cambie de moneda.
    before = state()
    query('CALL transferir(1,2,75000.00);')
    query('UPDATE usuario SET currency_id=2 WHERE user_id=1;')
    check('Moneda histórica independiente de la moneda actual', query('SELECT u.currency_id, t.currency_id FROM usuario u JOIN transaccion t ON t.sender_user_id=u.user_id WHERE u.user_id=1 AND t.transaction_id=1;') == [['2', '1']])
    query('UPDATE usuario SET currency_id=1 WHERE user_id=1;')
    query('CALL transferir(2,1,75000.00);')
    query('START TRANSACTION; DELETE FROM transaccion WHERE transaction_id > 3; COMMIT;')
    check('Restauración tras cambio de moneda con saldo cero', state() == before)

    # Durabilidad: lectura desde una nueva sesión y tras reiniciar el mismo servidor.
    snapshot = state()
    subprocess.run(['docker', 'compose', 'restart', 'mysql'], cwd=ROOT, check=True, capture_output=True)
    for _ in range(60):
        if mysql('SELECT 1;').returncode == 0:
            break
        time.sleep(1)
    check('Durabilidad: COMMIT persiste tras reinicio de MySQL', state() == snapshot)

    capture_sql = {
        '01_creacion': "SHOW DATABASES LIKE 'AlkeWallet'; SHOW TABLES; SELECT VERSION() AS mysql_version, @@transaction_isolation AS aislamiento;",
        '02_join': "SELECT t.transaction_id, e.nombre AS emisor, r.nombre AS receptor, t.importe, m.currency_code FROM transaccion t JOIN usuario e ON e.user_id=t.sender_user_id JOIN usuario r ON r.user_id=t.receiver_user_id JOIN moneda m ON m.currency_id=t.currency_id ORDER BY t.transaction_id;",
        '03_ddl': 'DESCRIBE moneda; DESCRIBE usuario; DESCRIBE transaccion;',
        '04_commit_rollback': "START TRANSACTION; UPDATE usuario SET correo_electronico='ana.torres@example.com' WHERE user_id=1; COMMIT; SELECT user_id, saldo, correo_electronico FROM usuario WHERE user_id=1; CALL demostrar_error_referencial(); START TRANSACTION; DELETE FROM transaccion WHERE transaction_id=1; SELECT COUNT(*) AS filas_tras_delete FROM transaccion WHERE transaction_id=1; ROLLBACK; SELECT COUNT(*) AS filas_tras_rollback FROM transaccion WHERE transaction_id=1;",
        '05_consultas': "SELECT u.nombre,m.currency_name AS moneda FROM usuario u JOIN moneda m ON m.currency_id=u.currency_id WHERE u.user_id=1; SELECT m.currency_code,COUNT(t.transaction_id) AS cantidad,COALESCE(SUM(t.importe),0) AS total FROM moneda m LEFT JOIN transaccion t ON t.currency_id=m.currency_id GROUP BY m.currency_id,m.currency_code ORDER BY m.currency_id;",
    }
    captures = []
    for name, sql in capture_sql.items():
        executed.append(sql)
        result = mysql(sql, table=True)
        if result.returncode:
            raise RuntimeError(result.stderr)
        output = result.stdout
        if name == '01_creacion':
            output = (OUT / 'ejecucion_mysql.txt').read_text().split('--------------\nCREATE TABLE moneda', 1)[0] + output
        (OUT / f'{name}.txt').write_text(output)
        captures.append({'nombre': name, 'sql': sql, 'salida': output})
    metadata = {'fecha_utc': datetime.now(timezone.utc).isoformat(), 'motor': query('SELECT VERSION();')[0][0],
                'pruebas': tests, 'capturas': captures,
                'datos_finales': {'usuarios': query('SELECT user_id,nombre,saldo,currency_id FROM usuario ORDER BY user_id;'),
                                 'transacciones': query('SELECT transaction_id,sender_user_id,receiver_user_id,importe FROM transaccion ORDER BY transaction_id;')}}
    (OUT / 'resultados.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2))
    (OUT / 'validacion.sql').write_text('-- Sentencias efectivamente ejecutadas por verificar.py, sin repeticiones.\n-- Archivo de evidencia: incluye errores intencionales y pruebas concurrentes.\n-- No se ejecuta como script de instalación.\n\n' + '\n\n'.join(dict.fromkeys(executed)))
    print(f'Entrega verificada: {len(tests)} pruebas OK; MySQL {metadata["motor"]}', flush=True)


if __name__ == '__main__':
    main()
