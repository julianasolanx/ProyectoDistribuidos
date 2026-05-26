import sys
import zmq
import json
from datetime import datetime

def log(mensaje):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    print(f"[{ts}] [ANALITICA-SEGURA] {mensaje}")

class ValidadorSeguridad:
    """Componente encargado del control de acceso y sanitización de datos."""
    
    
    ESQUEMAS = {
        "camara": ["sensor_id", "tipo_sensor", "interseccion", "volumen", "velocidad_promedio", "timestamp"],
        "gps": ["sensor_id", "tipo_sensor", "interseccion", "nivel_congestion", "velocidad_promedio", "timestamp"],
        "espira_inductiva": ["sensor_id", "tipo_sensor", "interseccion", "vehiculos_contados", "intervalo_segundos", "timestamp_inicio", "timestamp_fin"]
    }

    @staticmethod
    def validar_payload_sensor(topico, datos):
        """Verifica la integridad estructural y tipos de datos del mensaje."""
        if topico not in ValidadorSeguridad.ESQUEMAS:
            return False, f"Tópico no autorizado: '{topico}'"

        
        campos_requeridos = ValidadorSeguridad.ESQUEMAS[topico]
        for campo in campos_requeridos:
            if campo not in datos:
                return False, f"Falta campo obligatorio '{campo}' en tópico '{topico}'"

       
        try:
            if not isinstance(datos["interseccion"], str) or not datos["interseccion"].startswith("INT_"):
                return False, "Formato de identificador de intersección inválido o malicioso."
                
            if topico == "camara":
                if not isinstance(datos["volumen"], (int, float)) or not isinstance(datos["velocidad_promedio"], (int, float)):
                    return False, "Tipos numéricos corruptos en reporte de cámara."
            elif topico == "gps":
                if datos["nivel_congestion"] not in ["BAJA", "NORMAL", "ALTA"]:
                    return False, "Inyección de estado de congestión no reconocido."
        except Exception:
            return False, "Error estructural crítico durante el parseo de tipos."

        return True, "Validación de Integridad: exitosa."


class MotorCorrelacion:
    def __init__(self):
        self.bufer_intersecciones = {}

    def actualizar_y_evaluar(self, topico, datos):
        interseccion = datos.get("interseccion")
        if interseccion not in self.bufer_intersecciones:
            self.bufer_intersecciones[interseccion] = {"camara": None, "gps": None, "espira_inductiva": None}
            
        self.bufer_intersecciones[interseccion][topico] = datos

        camara = self.bufer_intersecciones[interseccion]["camara"]
        gps    = self.bufer_intersecciones[interseccion]["gps"]
        espira = self.bufer_intersecciones[interseccion]["espira_inductiva"]

        if not camara or not gps or not espira:
            return "ESPERAR", "Ventana de correlación en proceso de sincronización..."

        q_cola   = camara.get("volumen", 0)
        v_p_cam  = camara.get("velocidad_promedio", 50)
        v_p_gps  = gps.get("velocidad_promedio", 50)
        v_conteo = espira.get("vehiculos_contados", 0)
        nivel_g  = gps.get("nivel_congestion", "BAJA")

        v_promedio_real = (v_p_cam + v_p_gps) / 2

        if q_cola < 5 and v_promedio_real > 35 and nivel_g == "BAJA" and v_conteo <= 5:
            return "cambiar_rojo", "REGLA_1 (Normalidad): Flujo despejado en el eje de la calle."
        elif q_cola >= 13 and v_promedio_real < 15 and nivel_g == "ALTA" and v_conteo >= 16:
            return "extender_verde", "REGLA_2 (Congestión Crítica): Forzando Ola Verde."
        elif 5 <= q_cola < 13 or (15 <= v_promedio_real <= 35) or nivel_g == "NORMAL":
            return "cambiar_verde", "REGLA_3 (Congestión Moderada): Agilizando paso."

        return "mantener", "Malla vial estable dentro de rangos."


def main():
    if len(sys.argv) != 11:
        print("\n[ERROR] Parámetros incorrectos para la topología distribuida segura.")
        print("Uso correcto:")
        print("  python servicio_analitica.py <ip_escucha_rep> <ip_broker> <port_sub> <ip_control> <port_push> \\")
        print("                               <ip_bd_p> <port_bd_p> <ip_bd_r> <port_bd_r> <port_rep_monitoreo>")
        sys.exit(1)

    IP_LOCAL_REP = sys.argv[1]  
    IP_BROKER    = sys.argv[2]
    PORT_SUB     = sys.argv[3]
    IP_CONTROL   = sys.argv[4]
    PORT_CONTROL = sys.argv[5]
    IP_BD_P      = sys.argv[6]
    PORT_BD_P    = sys.argv[7]
    IP_BD_R      = sys.argv[8]
    PORT_BD_R    = sys.argv[9]
    PORT_REP     = sys.argv[10]

    context = zmq.Context()

    socket_sub = context.socket(zmq.SUB)
    socket_sub.connect(f"tcp://{IP_BROKER}:{PORT_SUB}")
    for t in ["camara", "gps", "espira_inductiva"]:
        socket_sub.setsockopt_string(zmq.SUBSCRIBE, t)

    socket_control = context.socket(zmq.PUSH)
    socket_control.connect(f"tcp://{IP_CONTROL}:{PORT_CONTROL}")

    socket_bd_p = context.socket(zmq.PUSH)
    socket_bd_p.connect(f"tcp://{IP_BD_P}:{PORT_BD_P}")
    socket_bd_r = context.socket(zmq.PUSH)
    socket_bd_r.connect(f"tcp://{IP_BD_R}:{PORT_BD_R}")

   
    socket_rep_monitoreo = context.socket(zmq.REP)
    socket_rep_monitoreo.bind(f"tcp://{IP_LOCAL_REP}:{PORT_REP}")

    poller = zmq.Poller()
    poller.register(socket_sub, zmq.POLLIN)
    poller.register(socket_rep_monitoreo, zmq.POLLIN)

    log(f"Servicio de Analítica Hardened activo. Interfaz de control acoplada a: {IP_LOCAL_REP}:{PORT_REP}")

    motor = MotorCorrelacion()
    mensajes_procesados = 0

    try:
        while True:
            socks = dict(poller.poll(timeout=500))

            if socket_sub in socks:
                msg_raw = socket_sub.recv_string()
                partes = msg_raw.split(" ", 1)
                if len(partes) != 2:
                    log("[ALERTA SEGURIDAD] Mensaje recibido sin delimitador de tópico estructural.")
                    continue

                topico, contenido_json = partes
                
                try:
                    datos = json.loads(contenido_json)
                except json.JSONDecodeError:
                    log("[ALERTA SEGURIDAD] Intento de desbordamiento: El payload no es un JSON parseable.")
                    continue

               
                es_valido, motivo_seguridad = ValidadorSeguridad.validar_payload_sensor(topico, datos)
                if not es_valido:
                    log(f"🚨 [MENSAJE RECHAZADO] Violación de integridad detectada: {motivo_seguridad}")
                    continue  

                interseccion = datos.get("interseccion")
                mensajes_procesados += 1
                
                accion, motivo = motor.actualizar_y_evaluar(topico, datos)

                if accion in ["cambiar_verde", "cambiar_rojo", "extender_verde"]:
                    cmd = {"interseccion": interseccion, "accion": accion, "motivo": motivo}
                    socket_control.send_string(json.dumps(cmd))

              
                estado_calle   = "VERDE" if accion in ["cambiar_verde", "extender_verde", "mantener"] else "ROJO"
                estado_carrera = "ROJO" if estado_calle == "VERDE" else "VERDE"

                payload_log = {
                    "ejecucion_id": mensajes_procesados,
                    "interseccion": interseccion,
                    "sensor_origen": topico,
                    "datos_capturados": datos,
                    "accion_derived": accion,
                    "estado_semaforo_calle": estado_calle,
                    "estado_semaforo_carrera": estado_carrera,
                    "timestamp": datetime.now().strftime("%Y-%m-%dT%H:%M:%SZ")
                }
                msg_send = json.dumps(payload_log)

                try: socket_bd_p.send_string(msg_send, zmq.NOBLOCK)
                except zmq.Again: log("[FALLO EN PC3] Persistencia en canal secundario.")
                try: socket_bd_r.send_string(msg_send, zmq.NOBLOCK)
                except zmq.Again: pass

            if socket_rep_monitoreo in socks:
                msg_manual_raw = socket_rep_monitoreo.recv_string()
                
                try:
                    cmd_manual = json.loads(msg_manual_raw)
                except json.JSONDecodeError:
                    socket_rep_monitoreo.send_string(json.dumps({"status": "REJECTED", "mensaje": "Payload corrupto"}))
                    continue

               
                interseccion_m = cmd_manual.get("interseccion")
                if not isinstance(interseccion_m, str) or len(interseccion_m) > 10:
                    socket_rep_monitoreo.send_string(json.dumps({"status": "REJECTED", "mensaje": "Inyección string inválida"}))
                    continue

                log(f"⚠️ Indicación manual validada con éxito para: {interseccion_m}")
                cmd_directo = {"interseccion": interseccion_m, "accion": "extender_verde", "motivo": cmd_manual.get("motivo")}
                socket_control.send_string(json.dumps(cmd_directo))
                
                socket_rep_monitoreo.send_string(json.dumps({
                    "status": "SUCCESS", 
                    "mensaje": f"Ola verde propagada con éxito de forma segura."
                }))

    except KeyboardInterrupt:
        log("Apagando analítica segura.")
    finally:
        socket_sub.close()
        socket_control.close()
        socket_bd_p.close()
        socket_bd_r.close()
        socket_rep_monitoreo.close()
        context.term()

if __name__ == "__main__":
    main()