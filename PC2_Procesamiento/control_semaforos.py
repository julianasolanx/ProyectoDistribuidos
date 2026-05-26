import sys
import zmq
import json
from datetime import datetime

def log(mensaje):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    print(f"[{ts}] [CONTROL-SEMAFOROS] {mensaje}")

def main():
    if len(sys.argv) != 3:
        print("\n[ERROR] Parámetros insuficientes.")
        sys.exit(1)

    IP_INTERFAZ = sys.argv[1]
    PUERTO_PULL = sys.argv[2]
    PULL_URL    = f"tcp://{IP_INTERFAZ}:{PUERTO_PULL}"

    context = zmq.Context()
    socket_pull = context.socket(zmq.PULL)
    socket_pull.bind(PULL_URL)
  
    malla_semaforos = {}

    log(f"Servicio de control de semáforos (Multi-Eje) activo en: {PULL_URL}")

    try:
        while True:
            mensaje_raw = socket_pull.recv_string()
            cmd = json.loads(mensaje_raw)

            interseccion = cmd.get("interseccion", "?")
            accion       = cmd.get("accion", "mantener")
            motivo       = cmd.get("motivo", "Rutina")

            
            if interseccion not in malla_semaforos:
                malla_semaforos[interseccion] = {"CALLE": "VERDE", "CARRERA": "ROJO"}

            ant_calle   = malla_semaforos[interseccion]["CALLE"]
            ant_carrera = malla_semaforos[interseccion]["CARRERA"]

      
            if accion in ["cambiar_verde", "extender_verde"]:
             
                malla_semaforos[interseccion]["CALLE"] = "VERDE"
                malla_semaforos[interseccion]["CARRERA"] = "ROJO"
            elif accion == "cambiar_rojo":
              
                malla_semaforos[interseccion]["CALLE"] = "ROJO"
                malla_semaforos[interseccion]["CARRERA"] = "VERDE"

            act_calle   = malla_semaforos[interseccion]["CALLE"]
            act_carrera = malla_semaforos[interseccion]["CARRERA"]

          
            if act_calle != ant_calle or act_carrera != ant_carrera:
                log(f"🔄 [CAMBIO] Intersección {interseccion}:")
                log(f"    🚦 Semáforo CALLE  (Fila)   : [{ant_calle}] ➡️ [{act_calle}]")
                log(f"    🚦 Semáforo CARRERA (Columna): [{ant_carrera}] ➡️ [{act_carrera}]")
                log(f"    ℹ️ Motivo: {motivo}")
            else:
                log(f"⏸️ [SOSTIENE] Intersección {interseccion} sin variaciones -> CALLE: [{act_calle}] | CARRERA: [{act_carrera}]")

    except KeyboardInterrupt:
        log("Servicio de control finalizado por interrupción manual.")
    finally:
        socket_pull.close()
        context.term()

if __name__ == "__main__":
    main()