import json
import sqlite3
import sys
from datetime import datetime

import zmq

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


def obtener_ultimo_id_local():
    """Consulta en SQLite cuál fue el último ID secuencial global guardado con éxito."""
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    cursor.execute("SELECT MAX(ejecucion_id) FROM historico_sensores")
    resultado = cursor.fetchone()[0]
    conn.close()
    return resultado if resultado is not None else 0


def guardar_evento(datos):
    try:
        conn = sqlite3.connect(DB_NAME)
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT OR IGNORE INTO historico_sensores
            (ejecucion_id, interseccion, sensor_origen, payload_raw, timestamp)
            VALUES (?, ?, ?, ?, ?)
        """,
            (
                datos.get("ejecucion_id"),
                datos.get("interseccion"),
                datos.get("sensor_origen"),
                json.dumps(datos.get("datos_capturados", {})),
                datos.get("timestamp"),
            ),
        )
        conn.commit()
        conn.close()
    except Exception as e:
        log(f"[ERROR AL GUARDAR]: {e}")


def main():
    if len(sys.argv) not in [3, 4]:
        print("\n[ERROR] Parámetros insuficientes.")
        print(
            "Uso correcto: python base_datos_replica.py <ip_interface> <port_pull> [<port_rep_query>]"
        )
        sys.exit(1)

    IP_INTERFACE = sys.argv[1]
    PORT_PULL = sys.argv[2]
    PORT_REP_QUERY = sys.argv[3] if len(sys.argv) == 4 else "5565"

    inicializar_bd()

    context = zmq.Context()
    socket_pull = context.socket(zmq.PULL)
    socket_pull.bind(f"tcp://{IP_INTERFACE}:{PORT_PULL}")

    socket_rep_sync = context.socket(zmq.REP)
    socket_rep_sync.bind(f"tcp://{IP_INTERFACE}:5561")

    socket_rep_query = context.socket(zmq.REP)
    socket_rep_query.bind(f"tcp://{IP_INTERFACE}:{PORT_REP_QUERY}")

    poller = zmq.Poller()
    poller.register(socket_pull, zmq.POLLIN)
    poller.register(socket_rep_sync, zmq.POLLIN)
    poller.register(socket_rep_query, zmq.POLLIN)

    log(
        f"Servidor de Réplica escuchando ingesta en puerto {PORT_PULL} y consultas en puerto {PORT_REP_QUERY}..."
    )

    try:
        while True:
            socks = dict(poller.poll(timeout=500))

            if socket_pull in socks:
                msg_raw = socket_pull.recv_string()
                datos = json.loads(msg_raw)
                guardar_evento(datos)
                log(
                    f"Registro respaldado en BD Réplica (PC2) -> {datos.get('interseccion')}"
                )

            if socket_rep_sync in socks:
                msg_sync = socket_rep_sync.recv_string()
                req_sync = json.loads(msg_sync)
                ultimo_id_pc3 = req_sync.get("ultimo_id_recibido", 0)

                conn = sqlite3.connect(DB_NAME)
                conn.row_factory = sqlite3.Row
                cursor = conn.cursor()
                cursor.execute(
                    "SELECT * FROM historico_sensores WHERE ejecucion_id > ? ORDER BY ejecucion_id ASC",
                    (ultimo_id_pc3,),
                )
                filas_perdidas = [dict(row) for row in cursor.fetchall()]
                conn.close()

                socket_rep_sync.send_string(
                    json.dumps({"status": "SUCCESS", "registros": filas_perdidas})
                )

            if socket_rep_query in socks:
                query_raw = socket_rep_query.recv_string()
                req_query = json.loads(query_raw)

                accion_q = req_query.get("accion")

                if accion_q == "ping_estado":
                    socket_rep_query.send_string(
                        json.dumps(
                            {"status": "ACK", "ultimo_id": obtener_ultimo_id_local()}
                        )
                    )

                elif accion_q == "consulta_historica":
                    hora_inicio = req_query.get("hora_inicio")
                    hora_fin = req_query.get("hora_fin")

                    log(
                        f"🔎 [RÉPLICA] Procesando consulta histórica de tráfico entre {hora_inicio} y {hora_fin}"
                    )

                    conn = sqlite3.connect(DB_NAME)
                    cursor = conn.cursor()
                    cursor.execute(
                        """
                        SELECT ejecucion_id, interseccion, sensor_origen, timestamp
                        FROM historico_sensores
                        WHERE time(timestamp) BETWEEN time(?) AND time(?)
                        ORDER BY timestamp ASC
                    """,
                        (hora_inicio, hora_fin),
                    )

                    filas = cursor.fetchall()
                    conn.close()

                    resultados = [
                        {"id": f[0], "interseccion": f[1], "sensor": f[2], "ts": f[3]}
                        for f in filas
                    ]
                    socket_rep_query.send_string(
                        json.dumps({"status": "SUCCESS", "datos": resultados})
                    )

    except KeyboardInterrupt:
        log("Servicio de réplica cerrado.")
    finally:
        socket_pull.close()
        socket_rep_sync.close()
        socket_rep_query.close()
        context.term()


if __name__ == "__main__":
    main()
