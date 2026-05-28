# Plataforma de Gestión Inteligente de Tráfico Urbano (GITU)

Este proyecto implementa una plataforma distribuida orientada a eventos para el monitoreo, análisis y control de tráfico urbano en tiempo real. Utiliza **ZeroMQ (ZMQ)** para desacoplar la ingesta de datos, la analítica, el control semafórico y la interfaz del operador.

El sistema simula una grilla de intersecciones y cuenta con tolerancia a fallos mediante conmutación automática (*failover*) y sincronización diferencial para consistencia eventual entre la base de datos principal y su réplica.

---

## 🛠️ Requisitos e Instalación

En cada una de las tres máquinas se debe tener instalado Python 3 y la biblioteca de comunicación PyZMQ:

```bash
pip install pyzmq
```

---

## 🌐 Guía de Ejecución Distribuida Real (Tus IPs)

Para desplegar el sistema distribuido de forma real en tus tres nodos configurados, ejecuta los comandos en sus respectivas máquinas **siguiendo estrictamente el orden numérico de los pasos**:

### 🎯 Direcciones IP del Entorno:
*   **PC1 (Ingesta):** `100.110.49.29`
*   **PC2 (Procesamiento y Control):** `100.87.47.66`
*   **PC3 (Persistencia y Monitoreo):** `100.90.114.97`

---

### 1️⃣ PASO 1: Iniciar el Broker en el PC1 (`100.110.49.29`)
Abre una terminal en el **PC1** y arranca el intermediario de mensajería (puedes elegir el broker monohilo o el multihilo):

*   **Opción estándar (Secuencial):**
    ```bash
    python PC1_Sensores/broker_zmq.py 100.110.49.29 5555 5556
    ```
*   **Opción multihilo (Alto rendimiento):**
    ```bash
    python PC1_Sensores/broker_multihilo_zmq.py 100.110.49.29 5555 5556
    ```

---

### 2️⃣ PASO 2: Iniciar Servicios de Soporte en el PC2 (`100.87.47.66`)
Abre **dos terminales independientes** en el **PC2**:

*   **Terminal A - Control de Semáforos:**
    ```bash
    python PC2_Procesamiento/control_semaforos.py 100.87.47.66 5557
    ```
*   **Terminal B - Base de Datos Réplica (Respaldo):**
    ```bash
    python PC2_Procesamiento/base_datos_replica.py 100.87.47.66 5559 5565
    ```

---

### 3️⃣ PASO 3: Iniciar Persistencia Principal en el PC3 (`100.90.114.97`)
Abre una terminal en el **PC3** y levanta el servidor de base de datos principal:

```bash
python PC3_Monitoreo/base_datos_principal.py 100.90.114.97 5558 5560 100.87.47.66
```

---

### 4️⃣ PASO 4: Levantar el Servicio de Analítica en el PC2 (`100.87.47.66`)
Abre una **tercera terminal** en el **PC2** y arranca el motor lógico que orquesta todas las tuberías:

```bash
python PC2_Procesamiento/servicio_analitica.py 100.87.47.66 100.110.49.29 5556 100.87.47.66 5557 100.90.114.97 5558 100.87.47.66 5559 5562
```

---

### 5️⃣ PASO 5: Simular Inyección de Sensores en el PC1 (`100.110.49.29`)
Abre terminales adicionales en el **PC1** para simular la red de sensores de una intersección de prueba (ej. `INT_C3`):

*   **Sensor de Cámara (Cola de vehículos):**
    ```bash
    python PC1_Sensores/simulador_sensores.py tcp://100.110.49.29:5555 CAM INT_C3 5 alta
    ```
*   **Sensor de GPS (Velocidad de congestión):**
    ```bash
    python PC1_Sensores/simulador_sensores.py tcp://100.110.49.29:5555 GPS INT_C3 5 alta
    ```
*   **Sensor de Espira (Conteo vehicular):**
    ```bash
    python PC1_Sensores/simulador_sensores.py tcp://100.110.49.29:5555 ESP INT_C3 5 alta
    ```

---

### 6️⃣ PASO 6: Iniciar Interfaz del Operador en el PC3 (`100.90.114.97`)
Abre una **segunda terminal** en el **PC3** y ejecuta la consola interactiva:

```bash
python PC3_Monitoreo/interfaz_monitoreo.py 100.90.114.97 5560 5562 100.87.47.66 5565
```

---

## 🖥️ Opción B: Ejecución en Entorno Local (127.0.0.1)

Si deseas probar el sistema de manera rápida en una sola máquina física usando terminales locales:

1.  **Broker (PC1):**
    ```bash
    python PC1_Sensores/broker_zmq.py 127.0.0.1 5555 5556
    ```
2.  **Semáforos (PC2):**
    ```bash
    python PC2_Procesamiento/control_semaforos.py 127.0.0.1 5557
    ```
3.  **BD Réplica (PC2):**
    ```bash
    python PC2_Procesamiento/base_datos_replica.py 127.0.0.1 5559 5565
    ```
4.  **BD Principal (PC3):**
    ```bash
    python PC3_Monitoreo/base_datos_principal.py 127.0.0.1 5558 5560 127.0.0.1
    ```
5.  **Servicio Analítica (PC2):**
    ```bash
    python PC2_Procesamiento/servicio_analitica.py 127.0.0.1 127.0.0.1 5556 127.0.0.1 5557 127.0.0.1 5558 127.0.0.1 5559 5562
    ```
6.  **Sensores de Prueba (PC1):**
    ```bash
    python PC1_Sensores/simulador_sensores.py tcp://127.0.0.1:5555 CAM INT_C3 5 alta
    python PC1_Sensores/simulador_sensores.py tcp://127.0.0.1:5555 GPS INT_C3 5 alta
    python PC1_Sensores/simulador_sensores.py tcp://127.0.0.1:5555 ESP INT_C3 5 alta
    ```
7.  **Monitoreo (PC3):**
    ```bash
    python PC3_Monitoreo/interfaz_monitoreo.py 127.0.0.1 5560 5562 127.0.0.1 5565
    ```

---

## 🧪 Pruebas y Escenarios de Validación

Una vez levantado todo el sistema, puedes realizar estas pruebas desde la **Interfaz de Monitoreo (PC3)**:

### 📊 1. Consultas Históricas
*   Selecciona `1` y luego `A` para validar que el clúster está en línea y consultar el último ID registrado.
*   Selecciona `1` y luego `B` para realizar consultas cronológicas sobre la base de datos (ej. entre `15:10:00` y `15:30:00`).

### 🚑 2. Ola Verde (Prioridad de Emergencias)
*   Selecciona la opción `2` e ingresa una intersección activa (ej: `INT_C3`).
*   Verás que en la terminal del controlador de semáforos se suspende el flujo normal para abrir la Calle en **VERDE** durante 30 segundos de manera inmediata.

### 🔌 3. Caída y Failover Transparente
1.  Detén la base de datos principal en el **PC3** presionando `Ctrl + C`.
2.  Realiza una consulta en la interfaz de monitoreo (`1 -> A`).
3.  Verás en pantalla cómo, tras un tiempo de espera de 2 segundos, el sistema redirige la petición a la **BD Réplica (PC2)** de forma transparente sin interrumpir el servicio.

### 🔄 4. Consistencia y Reconciliación Diferencial
1.  Mientras el **PC3** sigue apagado, mantén los sensores enviando datos. Verás que la réplica (`PC2`) sigue guardándolos de forma aislada.
2.  Enciende de nuevo el **PC3** ejecutando su script.
3.  Observa los logs iniciales en la terminal de la BD Principal: detectará la diferencia exacta con la Réplica y ejecutará una sincronización automática (`INSERT OR IGNORE`) recuperando el estado global de consistencia.
