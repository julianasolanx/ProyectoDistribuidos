import sys
import zmq
import json
import sqlite3
from datetime import datetime

DB_NAME = "trafico_replica.db"

def log(mensaje):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    print(f"[{ts}] [BD-RÉPLICA-PC2] {mensaje}")

def inicializar_bd():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS historico_sensores (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ejecucion_id INTEGER UNIQUE,
            interseccion TEXT,
            sensor_origen TEXT,
            payload_raw TEXT,
            timestamp TEXT
        )
    """)
    conn.commit()
    conn.close()
    log("Archivo físico de Base de Datos Réplica inicializado en SQLite (*.db).")

def guardar_evento(datos):
    try:
        conn = sqlite3.connect(DB_NAME)
        cursor = conn.cursor()
        cursor.execute("""
            INSERT OR IGNORE INTO historico_sensores 
            (ejecucion_id, interseccion, sensor_origen, payload_raw, timestamp) 
            VALUES (?, ?, ?, ?, ?)
        """, (
            datos.get("ejecucion_id"),
            datos.get("interseccion"),
            datos.get("sensor_origen"),
            json.dumps(datos.get("datos_capturados", {})),
            datos.get("timestamp")
        ))
        conn.commit()
        conn.close()
    except Exception as e:
        log(f"[ERROR AL GUARDAR]: {e}")

def main():
    if len(sys.argv) != 3:
        print("\n[ERROR] Parámetros insuficientes.")
        sys.exit(1)

    IP_INTERFACE = sys.argv[1]
    PORT_PULL    = sys.argv[2]

    inicializar_bd()

    context = zmq.Context()
    socket_pull = context.socket(zmq.PULL)
    socket_pull.bind(f"tcp://{IP_INTERFACE}:{PORT_PULL}")

    socket_rep_sync = context.socket(zmq.REP)
    socket_rep_sync.bind(f"tcp://{IP_INTERFACE}:5561")

    poller = zmq.Poller()
    poller.register(socket_pull, zmq.POLLIN)
    poller.register(socket_rep_sync, zmq.POLLIN)

    log(f"Servidor de Réplica escuchando en puerto {PORT_PULL}...")

    try:
        while True:
            socks = dict(poller.poll(timeout=500))

            if socket_pull in socks:
                msg_raw = socket_pull.recv_string()
                datos = json.loads(msg_raw)
                guardar_evento(datos)
                log(f"Registro respaldado en BD Réplica (PC2) -> {datos.get('interseccion')}")

            if socket_rep_sync in socks:
                msg_sync = socket_rep_sync.recv_string()
                req_sync = json.loads(msg_sync)
                ultimo_id_pc3 = req_sync.get("ultimo_id_recibido", 0)

                conn = sqlite3.connect(DB_NAME)
                conn.row_factory = sqlite3.Row
                cursor = conn.cursor()
                cursor.execute("SELECT * FROM historico_sensores WHERE ejecucion_id > ? ORDER BY ejecucion_id ASC", (ultimo_id_pc3,))
                filas_perdidas = [dict(row) for row in cursor.fetchall()]
                conn.close()

                socket_rep_sync.send_string(json.dumps({"status": "SUCCESS", "registros": filas_perdidas}))

    except KeyboardInterrupt:
        log("Servicio de réplica cerrado.")
    finally:
        socket_pull.close()
        socket_rep_sync.close()
        context.term()

if __name__ == "__main__":
    main()