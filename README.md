# Plataforma de Gestión Inteligente de Tráfico Urbano (GITU)

Este proyecto implementa una plataforma distribuida orientada a eventos para el monitoreo, análisis y control inteligente de tráfico urbano en tiempo real. Utiliza la librería de mensajería **ZeroMQ (ZMQ)** como middleware para desacoplar la ingesta de sensores, el motor lógico de analítica, el control de semáforos y los servicios de monitoreo de usuario.

El sistema simula una cuadrícula de $N \times M$ intersecciones y cuenta con un mecanismo robusto de **tolerancia a fallos por enmascaramiento con conmutación (failover) transparente** y **sincronización diferencial automática** para mantener la consistencia eventual entre la base de datos principal y su réplica activa.

---

## 🛠️ Requisitos de Sistema y Dependencias

La plataforma es altamente portátil y autocompilable. Solo requiere de Python 3 y la biblioteca de red ZeroMQ.

1. **Python 3.8+** instalado en todas las máquinas.
2. Instalar el paquete de comunicación **PyZMQ**:
   ```bash
   pip install pyzmq
   ```
   *(SQLite no requiere instalación ya que hace parte de la biblioteca estándar de Python).*

---

## 📐 Estructura de Distribución de Componentes

La plataforma se distribuye físicamente en tres nodos independientes:

*   **PC1: Capa de Ingesta (Sensores & Broker)**
    *   `broker_zmq.py` / `broker_multihilo_zmq.py`: Dispositivo central Proxy XSUB/XPUB.
    *   `simulador_sensores.py`: Procesos independientes que simulan Cámaras (CAM), GPS y Espiras Inductivas (ESP).
*   **PC2: Procesamiento y Control (Analítica, Actuación & Réplica)**
    *   `servicio_analitica.py`: Motor de correlación de reglas de tráfico y validador de seguridad.
    *   `control_semaforos.py`: Actuadores lógicos que controlan las luces de Calle y Carrera.
    *   `base_datos_replica.py`: Respaldo en caliente de persistencia y servidor de consultas en failover.
*   **PC3: Persistencia y Monitoreo (Centralización & Operación)**
    *   `base_datos_principal.py`: Histórico centralizado y motor de consistencia.
    *   `interfaz_monitoreo.py`: Consola interactiva para consultas históricas y priorización de emergencias (Ola Verde).

---

## 🖥️ Opción A: Ejecución en Entorno Local (127.0.0.1)

Para realizar una prueba de concepto rápida en una sola máquina física usando terminales separadas, ejecuta los siguientes comandos en orden estricto:

### Paso 1: Inicializar el PC1 (Ingesta)
Abre una terminal y levanta el Broker central:
```bash
python PC1_Sensores/broker_zmq.py 127.0.0.1 5555 5556
```

### Paso 2: Inicializar el PC2 (Control & Réplica)
Abre dos terminales adicionales para los servicios de soporte del PC2:
*   **Terminal de Semáforos:**
    ```bash
    python PC2_Procesamiento/control_semaforos.py 127.0.0.1 5557
    ```
*   **Terminal de BD Réplica:**
    ```bash
    python PC2_Procesamiento/base_datos_replica.py 127.0.0.1 5559 5565
    ```

### Paso 3: Inicializar el PC3 (Persistencia Principal)
Abre una terminal para la Base de Datos Principal:
```bash
python PC3_Monitoreo/base_datos_principal.py 127.0.0.1 5558 5560 127.0.0.1
```

### Paso 4: Inicializar el Procesamiento Lógico en el PC2
Abre otra terminal y ejecuta el motor de analítica, el cual integra todas las tuberías de red:
```bash
python PC2_Procesamiento/servicio_analitica.py 127.0.0.1 127.0.0.1 5556 127.0.0.1 5557 127.0.0.1 5558 127.0.0.1 5559 5562
```

### Paso 5: Lanzar la Red de Sensores (PC1)
Lanza sensores independientes para simular el tráfico en una intersección de prueba (por ejemplo, `INT_C3`):
*   **Sensor de Cámara (Cola de vehículos):**
    ```bash
    python PC1_Sensores/simulador_sensores.py tcp://127.0.0.1:5555 CAM INT_C3 5 alta
    ```
*   **Sensor de GPS (Velocidad de congestión):**
    ```bash
    python PC1_Sensores/simulador_sensores.py tcp://127.0.0.1:5555 GPS INT_C3 5 alta
    ```
*   **Sensor de Espira (Conteo vehicular):**
    ```bash
    python PC1_Sensores/simulador_sensores.py tcp://127.0.0.1:5555 ESP INT_C3 5 alta
    ```

### Paso 6: Arrancar el Monitoreo del Operador (PC3)
Lanza la interfaz de consola interactiva para el operador:
```bash
python PC3_Monitoreo/interfaz_monitoreo.py 127.0.0.1 5560 5562 127.0.0.1 5565
```

---

## 🌐 Opción B: Ejecución Distribuida Real (3 Máquinas Virtuales)

Cuando despliegues en tres nodos de red, primero asegúrate de que las VMs tengan visibilidad de red (`ping` exitoso) e identifica sus direcciones IP. 

Para esta guía de ejemplo, utilizaremos las siguientes IPs simuladas (debes reemplazarlas por las de tu red):
*   **PC1 (VM1 - Ingesta):** `192.168.1.10`
*   **PC2 (VM2 - Procesamiento):** `192.168.1.20`
*   **PC3 (VM3 - Monitoreo):** `192.168.1.30`

### 💻 En el PC1 (`192.168.1.10`)
1.  **Lanzar Broker central:**
    ```bash
    python3 PC1_Sensores/broker_zmq.py 192.168.1.10 5555 5556
    ```
2.  **Lanzar Sensores (tantos como requieras para simular la ciudad):**
    ```bash
    python3 PC1_Sensores/simulador_sensores.py tcp://192.168.1.10:5555 CAM INT_C3 5 alta
    python3 PC1_Sensores/simulador_sensores.py tcp://192.168.1.10:5555 GPS INT_C3 5 alta
    python3 PC1_Sensores/simulador_sensores.py tcp://192.168.1.10:5555 ESP INT_C3 5 alta
    ```

### 💻 En el PC2 (`192.168.1.20`)
1.  **Lanzar Controlador de Semáforos:**
    ```bash
    python3 PC2_Procesamiento/control_semaforos.py 192.168.1.20 5557
    ```
2.  **Lanzar BD Réplica:**
    ```bash
    python3 PC2_Procesamiento/base_datos_replica.py 192.168.1.20 5559 5565
    ```
3.  **Lanzar Servicio de Analítica:**
    ```bash
    python3 PC2_Procesamiento/servicio_analitica.py 192.168.1.20 192.168.1.10 5556 192.168.1.20 5557 192.168.1.30 5558 192.168.1.20 5559 5562
    ```

### 💻 En el PC3 (`192.168.1.30`)
1.  **Lanzar BD Principal:** (Apuntando a la réplica en el PC2 para sincronización diferencial):
    ```bash
    python3 PC3_Monitoreo/base_datos_principal.py 192.168.1.30 5558 5560 192.168.1.20
    ```
2.  **Lanzar Interfaz de Monitoreo:** (Pasándole como parámetros de backup la IP y puerto de la réplica en PC2):
    ```bash
    python3 PC3_Monitoreo/interfaz_monitoreo.py 192.168.1.30 5560 5562 192.168.1.20 5565
    ```

---

## 🧪 Pruebas de Funcionamiento y Casos de Uso

Una vez que todo el sistema distribuido esté corriendo, puedes validar las siguientes funciones clave en vivo:

### 1. Auditoría y Consultas Históricas (REQ/REP)
*   En la **Interfaz de Monitoreo (PC3)**, presiona la opción `1`, luego `A` para comprobar el estado físico de la Base de Datos. Te devolverá el estado del nodo y el último ID de registro secuencial global sincronizado.
*   Selecciona la opción `1`, luego `B` para realizar una consulta por rango de tiempo. Ingresa una hora pico aproximada (por ejemplo, `15:10:00` y `15:25:00`). Verás cómo extrae de forma relacional y ultra-rápida desde SQLite el histórico de eventos ordenados cronológicamente.

### 2. Priorización de Vía de Emergencia - Ola Verde (REQ/REP -> PUSH/PULL)
*   En la **Interfaz de Monitoreo**, presiona la opción `2` e ingresa la intersección a despejar (por ejemplo: `INT_C3`).
*   Mira la pantalla de la terminal de **Control de Semáforos (PC2)**: Verás que de manera instantánea interrumpe su ciclo normal para forzar el semáforo de la Calle a **VERDE** y cerrar la Carrera en **ROJO** durante 30 segundos, registrando detalladamente la auditoría y motivo (`EMERGENCIA_AMBULANCIA: Priorización manual`).

### 3. Prueba de Caída Crítica y Tolerancia a Fallas en Vivo (Failover Activo)
1.  Simula un colapso en el nodo principal de persistencia cancelando el proceso de `base_datos_principal.py` en el **PC3** (presionando `Ctrl + C`).
2.  Ve a la terminal de la **Interfaz de Monitoreo** y realiza una consulta (`Opción 1 -> Opción A`).
3.  El sistema tardará exactamente 2 segundos, detectará que el PC3 no responde, y de forma **automática y transparente** redireccionará su socket de red para consultar la base de datos réplica en el **PC2**. Recibirás tus datos y el sistema continuará en línea sin interrupciones.

### 4. Recuperación de Consistencia (Sincronización Diferencial)
1.  Mientras el PC3 sigue caído, mantén los sensores transmitiendo datos. Verás en los logs del PC2 que los registros se siguen respaldando en el archivo `trafico_replica.db`.
2.  Enciende de nuevo la Base de Datos Principal ejecutando el comando correspondiente en el **PC3**.
3.  Observa detalladamente los logs iniciales de arranque del PC3: verás que detecta de forma automática los registros perdidos durante su ausencia e inserta mediante lote relacional (`INSERT OR IGNORE`) la diferencia exacta, recuperando la consistencia total del clúster en milisegundos.

---

## 📊 Benchmarks de Escalabilidad (Original vs. Multithreading)

Para el informe final de rendimiento, el sistema permite someter las dos arquitecturas de Broker ZMQ a factores de estrés controlados:

### Factores a Evaluar:
*   **Carga Nominal:** 1 sensor de cada tipo transmitiendo datos cada 10 segundos.
*   **Carga Crítica (Estrés):** 2 sensores de cada tipo transmitiendo datos cada 5 segundos.

### Variables a Comparar:
1.  **Cantidad de Solicitudes Registradas:** Cantidad de inserciones seguras que se logran guardar en la base de datos en un intervalo continuo de 2 minutos.
2.  **Latencia de Actuación:** Tiempo efectivo de propagación desde que el operador activa la Ola Verde en el Monitoreo hasta que el semáforo cambia de luz en la pantalla de control.

Para realizar el experimento, detén el broker monohilo secuencial (`broker_zmq.py`) e inicializa el broker multihilo (`broker_multihilo_zmq.py`) en el PC1, sometiéndolos a los mismos flujos de inyección de sensores. Los datos de inserción se verán reflejados cronológicamente en SQLite para tus tablas y gráficos.
