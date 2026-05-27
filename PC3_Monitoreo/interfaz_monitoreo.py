import json
import sys
from datetime import datetime

import zmq


def log(mensaje):
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] [MONITOREO-CLIENTE] {mensaje}")


class ClientePersistencia:
    """Clase encargada de realizar consultas con tolerancia a fallas y failover transparente."""

    def __init__(self, context, ip_principal, port_principal, ip_replica, port_replica):
        self.context = context
        self.ip_principal = ip_principal
        self.port_principal = port_principal
        self.ip_replica = ip_replica
        self.port_replica = port_replica

        self.active_db = "principal"
        self.socket = self.context.socket(zmq.REQ)
        self._conectar()

    def _conectar(self):
        try:
            self.socket.close(linger=0)
        except Exception:
            pass
        self.socket = self.context.socket(zmq.REQ)
        if self.active_db == "principal":
            url = f"tcp://{self.ip_principal}:{self.port_principal}"
        else:
            url = f"tcp://{self.ip_replica}:{self.port_replica}"
        self.socket.connect(url)
        self.socket.setsockopt(zmq.RCVTIMEO, 2000)  # Timeout de 2 segundos exigido
        self.socket.setsockopt(zmq.LINGER, 0)

    def enviar_consulta(self, payload):
        try:
            self.socket.send_string(json.dumps(payload))
            respuesta_raw = self.socket.recv_string()
            return json.loads(respuesta_raw)
        except zmq.Again:
            if self.active_db == "principal":
                print(
                    f"\n⚠️ [FAILOVER] La BD Principal ({self.ip_principal}:{self.port_principal}) no respondió en 2 segundos."
                )
                print(
                    f"🔄 Conmutando automáticamente a la BD Réplica ({self.ip_replica}:{self.port_replica})..."
                )
                self.active_db = "replica"
                self._conectar()

                try:
                    self.socket.send_string(json.dumps(payload))
                    respuesta_raw = self.socket.recv_string()
                    print(
                        "✅ [FAILOVER] Consulta recuperada con éxito desde la BD Réplica."
                    )
                    return json.loads(respuesta_raw)
                except zmq.Again:
                    print("❌ [FAILOVER ERROR] La BD Réplica tampoco respondió.")
                    raise zmq.Again
            else:
                print(
                    f"\n⚠️ [FAILBACK CHECK] La BD Réplica no respondió. Intentando reconectar a la BD Principal..."
                )
                self.active_db = "principal"
                self._conectar()
                try:
                    self.socket.send_string(json.dumps(payload))
                    respuesta_raw = self.socket.recv_string()
                    print("✅ [FAILBACK] Conexión recuperada con la BD Principal.")
                    return json.loads(respuesta_raw)
                except zmq.Again:
                    print(
                        "❌ [ERROR CRÍTICO] Ni la BD Principal ni la BD Réplica están disponibles."
                    )
                    raise zmq.Again

    def close(self):
        if self.socket:
            self.socket.close(linger=0)


def mostrar_menu():
    print("\n" + "=" * 50)
    print("      SISTEMA DE GESTIÓN INTELIGENTE DE TRÁFICO")
    print("=" * 50)
    print("1. [CONSULTA] Verificar estado de la BD Principal")
    print("2. [PRIORIDAD] Forzar Ola Verde (Paso de Ambulancia)")
    print("3. Salir del sistema")
    print("=" * 50)


def main():
    if len(sys.argv) not in [4, 6]:
        print("\n[ERROR] Parámetros insuficientes.")
        print(
            "Uso correcto: python interfaz_monitoreo.py <ip_bd_pc3> <puerto_rep_bd> <puerto_rep_analitica> [<ip_replica>] [<puerto_rep_replica>]"
        )
        print(
            "Ejemplo local: python PC3_Monitoreo/interfaz_monitoreo.py 127.0.0.1 5560 5562 127.0.0.1 5565\n"
        )
        sys.exit(1)

    IP_BD = sys.argv[1]
    PORT_REP_BD = sys.argv[2]
    PORT_REP_ANALITICA = sys.argv[3]

    # Parámetros para tolerancia a fallos
    IP_REPLICA = sys.argv[4] if len(sys.argv) == 6 else IP_BD
    PORT_REP_REPLICA = sys.argv[5] if len(sys.argv) == 6 else "5565"

    context = zmq.Context()

    # Cliente tolerante a fallas
    cliente_bd = ClientePersistencia(
        context, IP_BD, PORT_REP_BD, IP_REPLICA, PORT_REP_REPLICA
    )

    # Conexión directa al PC2 para control manual prioritario
    socket_req_analitica = context.socket(zmq.REQ)
    socket_req_analitica.connect(f"tcp://{IP_REPLICA}:{PORT_REP_ANALITICA}")
    socket_req_analitica.setsockopt(zmq.RCVTIMEO, 2000)

    while True:
        mostrar_menu()
        opcion = input(
            "Seleccione una opción de control distributed-ready (1-3): "
        ).strip()

        if opcion == "1":
            print("\n--- SUB-MENÚ DE CONSULTAS HISTÓRICAS ---")
            print("A. Verificar estado y último ID global de la BD")
            print("B. Consultar registros por rango de tiempo (Hora Pico)")
            sub_op = input("Seleccione (A/B): ").strip().upper()

            if sub_op == "A":
                try:
                    respuesta = cliente_bd.enviar_consulta({"accion": "ping_estado"})
                    print(
                        f"\n[RESPUESTA BD]: Estado -> {respuesta.get('status')} | Último ID Secuencial: {respuesta.get('ultimo_id')}"
                    )
                except zmq.Again:
                    log("[-] Error: Tiempo de espera agotado con PC3 y réplica en PC2.")

            elif sub_op == "B":
                h_inicio = input(
                    "Ingrese hora de inicio (Format HH:MM:SS, Ej: 15:10:00): "
                ).strip()
                h_fin = input(
                    "Ingrese hora de fin    (Format HH:MM:SS, Ej: 15:25:00): "
                ).strip()

                payload_q = {
                    "accion": "consulta_historica",
                    "hora_inicio": h_inicio,
                    "hora_fin": h_fin,
                }

                try:
                    respuesta = cliente_bd.enviar_consulta(payload_q)
                    registros = respuesta.get("datos", [])

                    print(
                        f"\n================ MÉTRICAS HISTÓRICAS ENCONTRADAS: {len(registros)} ================"
                    )
                    for r in registros:
                        print(
                            f" ID: {r['id']} | {r['interseccion']} | Sensor: {r['sensor'].upper()} | Registrado a las: {r['ts']}"
                        )
                    print("=" * 70)
                except zmq.Again:
                    log(
                        "[-] Error: El servidor de persistencia histórica no responde (ni principal ni réplica)."
                    )

        elif opcion == "2":
            interseccion = (
                input(
                    "Ingrese el identificador de la intersección a priorizar (Ej: INT_C3): "
                )
                .strip()
                .upper()
            )
            log(
                f"Emitiendo indicación directa de OLA VERDE para {interseccion} hacia el PC2..."
            )

            comando_prioritario = {
                "accion": "forzar_verde",
                "interseccion": interseccion,
                "motivo": "EMERGENCIA_AMBULANCIA: Priorización manual de vía solicitada por operador.",
            }

            try:
                socket_req_analitica.send_string(json.dumps(comando_prioritario))
                respuesta = json.loads(socket_req_analitica.recv_string())
                print(
                    f"\n[RESPUESTA ANALÍTICA]: Transición -> {respuesta.get('status')} | {respuesta.get('mensaje')}"
                )
            except zmq.Again:
                log(
                    "[FALLO DETECTADO] El Servicio de Analítica (PC2) no se encuentra disponible."
                )

        elif opcion == "3":
            print("\nCerrando consola de monitoreo. Liberando sockets...")
            break
        else:
            print("\n[ADVERTENCIA] Opción inválida. Elija 1, 2 o 3.")

    cliente_bd.close()
    socket_req_analitica.close()
    context.term()


if __name__ == "__main__":
    main()
