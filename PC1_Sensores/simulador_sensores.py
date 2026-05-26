import sys
import time
import random
import json
import os
import zmq
from datetime import datetime, timezone, timedelta

def cargar_topologia_urbana():
    ruta_config = os.path.join(os.path.dirname(__file__), "..", "config_ciudad.json")
    if not os.path.exists(ruta_config):
        print(f"[ERROR] No se encontró el archivo de inicialización de entorno en: {ruta_config}")
        sys.exit(1)
    with open(ruta_config, "r") as f:
        return json.load(f)

def validar_interseccion(interseccion_id, config):
    lista_ids = [interseccion["id"] for interseccion in config["intersecciones"]]
    return interseccion_id in lista_ids



def generar_datos_camara(interseccion, congestion):
   
    if congestion == "baja":
        volumen = random.randint(1, 4)
        velocidad_promedio = random.randint(36, 50)
    elif congestion == "media":
        volumen = random.randint(5, 12)
        velocidad_promedio = random.randint(15, 35)
    else: 
        volumen = random.randint(13, 30) 
        velocidad_promedio = random.randint(2, 14)

    return {
        "sensor_id": f"CAM-{interseccion.split('_')[1]}",
        "tipo_sensor": "camara",
        "interseccion": interseccion,
        "volumen": volumen,
        "velocidad_promedio": velocidad_promedio,
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    }

def generar_datos_espira(interseccion, congestion, intervalo_segundos):

    if congestion == "baja":
        vehiculos_contados = random.randint(0, 5)
    elif congestion == "media":
        vehiculos_contados = random.randint(6, 15)
    else: # alta
        vehiculos_contados = random.randint(16, 35)

    now = datetime.now(timezone.utc)
    timestamp_inicio = now - timedelta(seconds=intervalo_segundos)
    
    return {
        "sensor_id": f"ESP-{interseccion.split('_')[1]}",
        "tipo_sensor": "espira_inductiva",
        "interseccion": interseccion,
        "vehiculos_contados": vehiculos_contados,
        "intervalo_segundos": intervalo_segundos,
        "timestamp_inicio": timestamp_inicio.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "timestamp_fin": now.strftime("%Y-%m-%dT%H:%M:%SZ")
    }

def generar_datos_gps(interseccion, congestion):
    
    if congestion == "baja":
        nivel_congestion = "BAJA" 
        velocidad_promedio = random.randint(40, 50)
    elif congestion == "media":
        nivel_congestion = "NORMAL" 
        velocidad_promedio = random.randint(15, 39)
    else: # alta
        nivel_congestion = "ALTA" 
        velocidad_promedio = random.randint(1, 10)

    return {
        "sensor_id": f"GPS-{interseccion.split('_')[1]}",
        "tipo_sensor": "gps",
        "interseccion": interseccion,
        "nivel_congestion": nivel_congestion,
        "velocidad_promedio": velocidad_promedio,
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    }

def main():
    config_ciudad = cargar_topologia_urbana()

    if len(sys.argv) != 6:
        print("\n[ERROR] Cantidad de parámetros inválida.")
        print("Uso correcto:")
        print("  python3 simulador_sensores.py tcp://<ip_broker>:<puerto_xsub> CAM|ESP|GPS <INT_FilaColumna> <rate_segundos> <baja|media|alta>")
        print("Ejemplos:")
        print("  python3 simulador_sensores.py tcp://192.168.1.10:5555 CAM INT_C5 10 alta")
        print("  python3 simulador_sensores.py tcp://192.168.1.10:5555 ESP INT_A1 30 baja\n")
        sys.exit(1)

    BROKER_URL      = sys.argv[1]
    TIPO_SENSOR     = sys.argv[2].upper()
    INTERSECCION    = sys.argv[3]
    RATE_SEGUNDOS   = int(sys.argv[4])
    CONGESTION_OBJ  = sys.argv[5].lower()

   
    if TIPO_SENSOR not in ["CAM", "ESP", "GPS"]:
        print(f"[ERROR] Tipo de sensor '{TIPO_SENSOR}' inválido. Debe ser CAM, ESP o GPS.")
        sys.exit(1)

    if not validar_interseccion(INTERSECCION, config_ciudad):
        print(f"[ERROR] La intersección '{INTERSECCION}' no existe en la matriz inicializada del archivo de configuración.")
        sys.exit(1)

    if CONGESTION_OBJ not in ["baja", "media", "alta"]:
        print(f"[ERROR] Estado de congestión '{CONGESTION_OBJ}' incorrecto. Elija entre: baja, media o alta.")
        sys.exit(1)

   
    print(f"[%] Conectando contexto ZeroMQ al Broker en: {BROKER_URL}")
    context = zmq.Context()
    socket_pub = context.socket(zmq.PUB)
    
    try:
        socket_pub.connect(BROKER_URL)
        print(f"[OK] Sensor [{TIPO_SENSOR}] inicializado fijamente en la intersección: {INTERSECCION}")
        print(f"[INFO] Transmitiendo cada {RATE_SEGUNDOS}s bajo perfil de tráfico simulado: '{CONGESTION_OBJ.upper()}'\n")

        while True:
        
            if TIPO_SENSOR == "CAM":
                payload = generar_datos_camara(INTERSECCION, CONGESTION_OBJ)
                topico_pub = "camara"
            elif TIPO_SENSOR == "ESP":
                payload = generar_datos_espira(INTERSECCION, CONGESTION_OBJ, RATE_SEGUNDOS)
                topico_pub = "espira_inductiva"
            else: # GPS
                payload = generar_datos_gps(INTERSECCION, CONGESTION_OBJ)
                topico_pub = "gps"

            
            mensaje_json = json.dumps(payload)
            mensaje_completo = f"{topico_pub} {mensaje_json}"
            
            socket_pub.send_string(mensaje_completo)
            
            ts_local = datetime.now().strftime("%H:%M:%S.%f")[:-3]
            print(f"[{ts_local}] Publicado exitosamente en Tópico: '{topico_pub}' -> Payload: {mensaje_json}")
            
            time.sleep(RATE_SEGUNDOS)

    except KeyboardInterrupt:
        print("\n[-] Apagado manual del sensor detectado.")
    except Exception as e:
        print(f"\n[CRÍTICO] Error de comunicación en la red distribuida: {e}")
    finally:
        socket_pub.close()
        context.term()
        print("[!] Recursos liberados. Sensor desconectado.")

if __name__ == "__main__":
    main()