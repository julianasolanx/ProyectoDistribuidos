import sys
import zmq
import json
import sqlite3
from datetime import datetime

DB_NAME = "trafico_principal.db"

def log(mensaje):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    print(f"[{ts}] [BD-PRINCIPAL-PC3] {mensaje}")

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

def obtener_ultimo_id_local():
    """Consulta en SQLite cuál fue el último ID secuencial global guardado con éxito."""
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    cursor.execute("SELECT MAX(ejecucion_id) FROM historico_sensores")
    resultado = cursor.fetchone()[0]
    conn.close()
    return resultado if resultado is not None else 0

def ejecutar_sincronizacion_diferencial(ip_replica):
    """Mecanismo de reconciliación post-falla exigido por el evaluador."""
    log("Iniciando fase de validación de consistencia distribuida con la réplica...")
    ultimo_id = obtener_ultimo_id_local()
    
    context = zmq.Context()
    socket_sync = context.socket(zmq.REQ)
    socket_sync.setsockopt(zmq.RCVTIMEO, 3000) 
    
    url_replica = f"tcp://{ip_replica}:5561"
    socket_sync.connect(url_replica)

    try:
        
        peticion = {"ultimo_id_recibido": ultimo_id}
        socket_sync.send_string(json.dumps(peticion))
        
        respuesta_raw = socket_sync.recv_string()
        respuesta = json.loads(respuesta_raw)
        
        registros_perdidos = respuesta.get("registros", [])
        
        if registros_perdidos:
            log(f"⚙️ Detectada asincronía de red: Faltan {len(registros_perdidos)} registros. Aplicando inserción diferencial...")
            
            conn = sqlite3.connect(DB_NAME)
            cursor = conn.cursor()
            
            for reg in registros_perdidos:
                cursor.execute("""
                    INSERT OR IGNORE INTO historico_sensores 
                    (ejecucion_id, interseccion, sensor_origen, payload_raw, timestamp) 
                    VALUES (?, ?, ?, ?, ?)
                """, (reg['ejecucion_id'], reg['interseccion'], reg['sensor_origen'], reg['payload_raw'], reg['timestamp']))
                
            conn.commit()
            conn.close()
            log("Sincronización diferencial completada de forma exitosa. Estado de consistencia: OK.")
        else:
            log("No se detectaron registros perdidos. Las bases de datos se encuentran sincronizadas.")
            
    except zmq.Again:
        log("[ADVERTENCIA] No se pudo establecer conexión con la Réplica para la sincronización diferencial.")
    finally:
        socket_sync.close()

def guardar_evento_directo(datos):
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    try:
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
    except sqlite3.Error as e:
        log(f"[ERROR SQLITE]: {e}")
    finally:
        conn.close()

def main():
    if len(sys.argv) != 5:
        print("\n[ERROR] Parámetros incorrectos.")
        print("Uso correcto:")
        print("  python base_datos_principal.py <ip_local> <puerto_pull> <puerto_rep_queries> <ip_replica>")
        print("Ejemplo local:")
        print("  python PC3_Monitoreo/base_datos_principal.py 127.0.0.1 5558 5560 127.0.0.1\n")
        sys.exit(1)

    IP_LOCAL     = sys.argv[1]
    PORT_PULL    = sys.argv[2]
    PORT_REP     = sys.argv[3]
    IP_REPLICA   = sys.argv[4]

    inicializar_bd()
    
    
    ejecutar_sincronizacion_diferencial(IP_REPLICA)

    context = zmq.Context()
    socket_pull = context.socket(zmq.PULL)
    socket_pull.bind(f"tcp://{IP_LOCAL}:{PORT_PULL}")

    socket_rep = context.socket(zmq.REP)
    socket_rep.bind(f"tcp://{IP_LOCAL}:{PORT_REP}")

    poller = zmq.Poller()
    poller.register(socket_pull, zmq.POLLIN)
    poller.register(socket_rep,  zmq.POLLIN)

    log("Servidor BD Principal en línea escuchando ingesta continua...")

    try:
        while True:
            socks = dict(poller.poll(timeout=500))

            if socket_pull in socks:
                msg_raw = socket_pull.recv_string()
                datos = json.loads(msg_raw)
                guardar_evento_directo(datos)

            if socket_rep in socks:
                query_raw = socket_rep.recv_string()
                req_query = json.loads(query_raw)
                
                accion_q = req_query.get("accion")
                
                if accion_q == "ping_estado":
                    socket_rep.send_string(json.dumps({"status": "ACK", "ultimo_id": obtener_ultimo_id_local()}))
                
                elif accion_q == "consulta_historica":
                    hora_inicio = req_query.get("hora_inicio") 
                    hora_fin    = req_query.get("hora_fin")
                    
                    log(f"🔎 Procesando consulta histórica de tráfico entre {hora_inicio} y {hora_fin}")
                    
                    conn = sqlite3.connect(DB_NAME)
                    cursor = conn.cursor()
                   
                    cursor.execute("""
                        SELECT ejecucion_id, interseccion, sensor_origen, timestamp 
                        FROM historico_sensores 
                        WHERE time(timestamp) BETWEEN time(?) AND time(?)
                        ORDER BY timestamp ASC
                    """, (hora_inicio, hora_fin))
                    
                    filas = cursor.fetchall()
                    conn.close()
                    
                
                    resultados = [{"id": f[0], "interseccion": f[1], "sensor": f[2], "ts": f[3]} for f in filas]
                    socket_rep.send_string(json.dumps({"status": "SUCCESS", "datos": resultados}))

    except KeyboardInterrupt:
        log("Apagando base de datos principal.")
    finally:
        socket_pull.close()
        socket_rep.close()
        context.term()

if __name__ == "__main__":
    main()