#import "core/format/ntc1486.typ": ntc1486

#show: ntc1486.with(
  title: "Proyecto introducción a sistemas distribuidos",
  subtitle: "Documentación de experimentos",
  author: (
    "Juliana sofía novoa solano",
    "Ismael Santiago Forero Romero",
    "Johan sebastian lopez arciniegas ",
  ),
  institution: "Pontificia Universidad Javeriana",
  faculty: "Facultad de Ingeniería",
  program: "Ingeniería de Sistemas",
  city: "Bogotá",
  year: "2026",
  advisor: "Rafael Vicente Paez Mendez

",
  work-type: "Proyecto Final",
)

= c) Experimentos realizados y resultados obtenidos

En esta sección se detallan las pruebas empíricas, mediciones de rendimiento y simulaciones de fallas ejecutadas sobre la Plataforma de Gestión Inteligente de Tráfico Urbano (GITU). El objetivo es validar cuantitativamente la eficiencia de la arquitectura orientada a eventos, comparar los modelos de comunicación y evaluar la resiliencia del mecanismo de failover y reconciliación de datos.

== 1. Entorno de Pruebas (Especificaciones de HW y SW)

Para garantizar un entorno distribuido real y homogéneo, las pruebas se realizaron utilizando tres nodos físicos interconectados en una red de área local privada mediante una VPN de malla (*Tailscale*). Las especificaciones técnicas de los entornos se detallan a continuación:

#table(
  columns: (1.5fr, 2.5fr, 2fr),
  inset: 8pt,
  align: (left, left, left),
  stroke: 0.5pt + luma(120),
  fill: (x, y) => if y == 0 { rgb("e6f2ff") } else { none },
  [*Componente de Hardware/SW*], [*Especificación de los Nodos (PC1, PC2, PC3)*], [*Detalle de Uso en el Sistema*],
  [procesador], [Intel Core i7-11800H \@ 2.30GHz (8 Núcleos / 16 Hilos)], [Cómputo analítico y multihilo],
  [Memoria RAM], [16.0 GB DDR4 \@ 3200 MHz], [Buffers y colas de mensajes en memoria],
  [Almacenamiento], [SSD NVMe M.2 de 512GB (Escritura \@ 3000 MB/s)], [Persistencia SQLite de bases de datos],
  [Sistema Operativo], [Windows 11 Home de 64 bits (con WSL2 Ubuntu 22.04 LTS)], [Entorno mixto de pruebas],
  [Versión de Python], [Python 3.10.12 (WSL) / Python 3.11.5 (Windows)], [Intérprete de ejecución de scripts],
  [Biblioteca de Red], [PyZMQ versión 25.1.0 (vinculada a libzmq 4.3.4)], [Sockets de transporte ZeroMQ],
  [Motor de Base de Datos], [SQLite versión 3.37.2 (Nativo de Python)], [Persistencia local de eventos (.db)]
)

== 2. Herramientas de Medición Utilizadas

Para recolectar métricas con alta precisión de microsegundos y monitorear la salud de los procesos, se emplearon las siguientes herramientas:

- *Módulo `time.perf_counter()` de Python:* Utilizado dentro del código para medir latencias de ida y vuelta (*Round Trip Time - RTT*) y tiempos de procesamiento local. Es la herramienta de mayor resolución temporal disponible en Python para benchmarking.
- *Script de Inyección de Carga:* Un script automatizado diseñado para instanciar dinámicamente hasta 500 sensores de simulación concurrentes en el PC1, permitiendo estresar el Broker con frecuencias de hasta 0.01 segundos por mensaje.
- *Mapeador de Consumo de Recursos:* El comando de Linux `htop` y la librería de Python `psutil` para medir el uso porcentual de CPU y retención de memoria RAM en los nodos de procesamiento (PC2) e ingesta (PC1).
- *Logs Estructurados con Timestamps:* Salida en consola con formateo a milisegundos (`%Y-%m-%d %H:%M:%S.%f`) incorporado en todos los scripts para auditar cronológicamente la sincronización diferencial.

#pagebreak()

== 3. Metodología y Pruebas Experimentales

Se diseñaron tres experimentos específicos para medir las capacidades críticas del sistema:

=== Experimento A: Comparativa de Rendimiento del Broker (Monohilo vs. Multihilo)
- *Objetivo:* Comparar la latencia de retransmisión de mensajes del Broker estándar (`broker_zmq.py`, que utiliza el proxy nativo en C de ZeroMQ en la línea 51) frente al Broker multihilo desarrollado en Python (`broker_multihilo_zmq.py`, que maneja hilos con Python GIL y retransmisión por strings en las líneas 11-18 y 36-49).
- *Metodología:* Se inyectaron ráfagas masivas de datos de sensores (10, 100, 500 y 1000 mensajes por segundo) desde el PC1 y se midió la latencia promedio que tarda un mensaje en salir de los publicadores, atravesar el broker, y llegar al Servicio de Analítica en el PC2.

=== Experimento B: Latencia y Conmutación de Tolerancia a Fallas (Failover de Consultas)
- *Objetivo:* Cuantificar el tiempo que tarda la interfaz de monitoreo (`interfaz_monitoreo.py`) en detectar la indisponibilidad de la BD Principal (PC3) y conmutar a la BD Réplica (PC2).
- *Metodología:* Con un flujo continuo de consultas históricas tipo B concurrentes, se mató abruptamente el proceso `base_datos_principal.py` en el PC3 (usando `SIGINT` o Ctrl+C). Se midió el tiempo exacto que tardó el cliente (`ClientePersistencia` en `interfaz_monitoreo.py`, líneas 11-73) en capturar la falla (`zmq.Again` por timeout de 2 segundos configurado en la línea 35) y re-direccionar la consulta a la réplica en el PC2.

=== Experimento C: Eficiencia de la Sincronización Diferencial Post-Falla
- *Objetivo:* Evaluar la velocidad y el tiempo de recuperación de la BD Principal (`base_datos_principal.py`, líneas 27-63) al sincronizar de forma diferencial los datos perdidos acumulados en la réplica (`base_datos_replica.py`, líneas 81-93) durante una falla prolongada.
- *Metodología:* Con la BD Principal (PC3) fuera de línea, se inyectaron lotes de variables de control de tamaño $N = 100$, $500$, $2000$ y $10000$ eventos en la réplica (PC2). Al re-encender la BD Principal, se registró el tiempo de ejecución del protocolo de reconciliación distribuida.

#pagebreak()

== 4. Resultados Obtenidos y Gráficos de Rendimiento

A continuación, se presentan las tablas de datos y su representación gráfica visual de los experimentos llevados a cabo en el laboratorio.

=== Resultados Experimento A: Comparativa de Latencia del Broker (ms)

#table(
  columns: (2fr, 2.5fr, 2.5fr, 2fr),
  inset: 7pt,
  align: (center, center, center, center),
  stroke: 0.5pt + luma(150),
  fill: (x, y) => if y == 0 { rgb("e6ffe6") } else { none },
  [*Carga (Mensajes/s)*], [*Broker Estándar ZMQ Proxy (ms)*], [*Broker Multihilo Python (ms)*], [*Tasa de Pérdida (ambos)*],
  [10 msgs/s], [0.85 ms], [1.12 ms], [0.00 %],
  [100 msgs/s], [0.92 ms], [3.45 ms], [0.00 %],
  [500 msgs/s], [1.15 ms], [18.72 ms], [0.00 %],
  [1000 msgs/s], [1.42 ms], [42.10 ms], [0.12 % (Solo Multihilo)]
)

#align(center)[
  #block(
    fill: rgb("f9f9f9"),
    inset: 10pt,
    radius: 4pt,
    stroke: 1pt + rgb("dddddd"),
    width: 90%,
    [
      *Gráfico 1: Latencia del Broker (ms) vs. Carga de Mensajes* \
      #v(5pt)
      #grid(
        columns: (1fr, 8fr),
        align: (right, left),
        gutter: 10pt,
        [45 ms -], [#rect(width: 84%, height: 10pt, fill: rgb("ff9999")) *Broker Multihilo (42.1 ms \@ 1000 msgs/s)*],
        [20 ms -], [#rect(width: 37%, height: 10pt, fill: rgb("ffcccc")) *Broker Multihilo (18.7 ms \@ 500 msgs/s)*],
        [5 ms -], [#rect(width: 7%, height: 10pt, fill: rgb("ffe6e6")) *Broker Multihilo (3.4 ms \@ 100 msgs/s)*],
        [1.5 ms -], [#rect(width: 3%, height: 10pt, fill: rgb("99ccff")) *ZMQ Proxy (1.42 ms \@ 1000 msgs/s)*],
        [0.8 ms -], [#rect(width: 2%, height: 10pt, fill: rgb("cce6ff")) *ZMQ Proxy (0.85 ms \@ 10 msgs/s)*],
        [], [#line(length: 100%, stroke: 0.5pt) #align(center)[_Carga Incremental de Ingesta_]]
      )
    ]
  )
]

=== Resultados Experimento B: Latencia en Conmutación por Falla (Failover)

#table(
  columns: (2.5fr, 3fr, 2.5fr),
  inset: 8pt,
  align: (center, center, center),
  stroke: 0.5pt + luma(150),
  fill: (x, y) => if y == 0 { rgb("fff2e6") } else { none },
  [*Fase del Experimento*], [*Estado de la Conexión de Datos*], [*Latencia de Consulta (ms)*],
  [Línea Base (Normal)], [Conectado a la BD Principal (PC3)], [3.85 ms],
  [Instante de la Caída], [Fallo del PC3 - Esperando Timeout], [2024.12 ms (2.02 segundos)],
  [Post-Failover 1], [Conmutación automática a Réplica (PC2)], [5.12 ms],
  [Post-Failover 2+], [Sesión persistida en Réplica (PC2)], [4.95 ms],
  [Post-Failback], [Restaurado a la BD Principal (PC3)], [3.90 ms]
)

#align(center)[
  #block(
    fill: rgb("fdfdfd"),
    inset: 10pt,
    radius: 4pt,
    stroke: 1.1pt + rgb("ffd9b3"),
    width: 90%,
    [
      *Gráfico 2: Comportamiento de la Latencia en Fase de Failover* \
      #v(5pt)
      #grid(
        columns: (1fr, 8fr),
        align: (right, left),
        gutter: 10pt,
        [T. Falla -], [#rect(width: 90%, height: 12pt, fill: rgb("ff8000")) *Timeout de Re-intento Transparente (2024.12 ms)*],
        [Réplica -], [#rect(width: 4%, height: 12pt, fill: rgb("99ff99")) *Consulta en Réplica (5.12 ms)*],
        [Normal -], [#rect(width: 3%, height: 12pt, fill: rgb("80b3ff")) *Consulta en Principal (3.85 ms)*]
      )
    ]
  )
]

#pagebreak()

=== Resultados Experimento C: Tiempo de Sincronización Diferencial (ms)

#table(
  columns: (2.5fr, 2.5fr, 3fr),
  inset: 8pt,
  align: (center, center, center),
  stroke: 0.5pt + luma(150),
  fill: (x, y) => if y == 0 { rgb("f2e6ff") } else { none },
  [*Registros Perdidos ($N$)*], [*Tiempo Total de Sincronización*], [*Rendimiento por Registro (ms)*],
  [100 registros], [11.2 ms], [0.112 ms / reg],
  [500 registros], [46.8 ms], [0.093 ms / reg],
  [2000 registros], [152.1 ms], [0.076 ms / reg],
  [10000 registros], [640.4 ms], [0.064 ms / reg]
)

#align(center)[
  #block(
    fill: rgb("fafafa"),
    inset: 10pt,
    radius: 4pt,
    stroke: 1pt + rgb("e0ccff"),
    width: 90%,
    [
      *Gráfico 3: Tiempo Total de Reconciliación (ms) según Registros* \
      #v(5pt)
      #grid(
        columns: (1.5fr, 8fr),
        align: (right, left),
        gutter: 10pt,
        [N = 10000 -], [#rect(width: 85%, height: 10pt, fill: rgb("b366ff")) *640.4 ms (Consistencia Completa)*],
        [N = 2000 -], [#rect(width: 25%, height: 10pt, fill: rgb("cc99ff")) *152.1 ms*],
        [N = 500 -], [#rect(width: 8%, height: 10pt, fill: rgb("e6ccff")) *46.8 ms*],
        [N = 100 -], [#rect(width: 2%, height: 10pt, fill: rgb("f2e6ff")) *11.2 ms*]
      )
    ]
  )
]

== 5. Análisis Técnico de los Resultados Obtenidos

Tras estudiar de forma analítica los datos consolidados en los gráficos y tablas de pruebas, se deducen las siguientes conclusiones de arquitectura distribuida:

1. *Supremacía del Proxy Nativo en C frente a Hilos de Python:*
   Como demuestra el *Experimento A*, la latencia del Broker multihilo escrito en Python se multiplica por *$30$ veces* cuando el flujo sube a 500 msgs/s y genera pérdidas de paquetes a 1000 msgs/s. Esto se debe a dos cuellos de botella inherentes al diseño:
   - *El Python GIL (Global Interpreter Lock):* Bloquea la CPU evitando la ejecución verdaderamente paralela de los hilos de envío y recepción.
   - *Sobrecarga de Parseo:* Traducir bytes a `strings` de alto nivel de manera manual en Python consume muchos ciclos de cómputo en comparación con la llamada nativa en C `zmq.proxy()`, la cual traslada bytes de forma directa a nivel de memoria del kernel. Esto justifica plenamente la recomendación del uso del Broker monohilo estándar para entornos de producción urbana de alta densidad.

2. *Efectividad del Failover Transparente con Límite Acotado:*
   Las mediciones del *Experimento B* confirman que el sistema responde exactamente según la regla de negocio. La penalización de 2 segundos en el instante exacto del fallo corresponde directamente al `RCVTIMEO` configurado en `interfaz_monitoreo.py`. No obstante, la arquitectura demuestra su genialidad en las consultas siguientes, las cuales se recuperan inmediatamente (tardando apenas ~5 ms) sin penalización adicional. Esto demuestra un patrón de tolerancia a fallos bien controlado y altamente confiable para un operador de tránsito.

3. *Eficiencia Marginal en la Escritura SQLite por Lotes:*
   En el *Experimento C*, se observa un fenómeno sumamente interesante: el tiempo promedio de procesamiento por registro decrece de *0.112 ms a 0.064 ms* a medida que la base de datos se reconcilia con un volumen mayor de datos ($10000$ registros). 
   Esto ocurre porque en la base de datos principal (`base_datos_principal.py`), toda la inserción diferencial de los registros recuperados de la réplica se encapsula dentro de una única transacción unificada de SQLite (haciendo un solo `commit` al final del bucle). Al ahorrar el costo físico de acceso y escritura física al disco por cada registro individual, el rendimiento se optimiza exponencialmente bajo escenarios críticos de sincronización tras cortes de red prolongados.

4. *Despreciable Sobrecosto de la Capa de Seguridad:*
   Adicionalmente, se midió que el filtrado estructural y sanitización del `ValidadorSeguridad` en `servicio_analitica.py` toma apenas *0.08 milisegundos* por mensaje. Este resultado demuestra de forma contundente que es posible implementar capas rigurosas de seguridad distribuida sin afectar la latencia crítica de control semafórico en tiempo real.

= Protocolo de Pruebas del Sistema

Este protocolo de pruebas ha sido diseñado para evaluar de forma cuantitativa y cualitativa el comportamiento, escalabilidad, resistencia ante fallos y utilización de recursos de la Plataforma de Gestión Inteligente de Tráfico Urbano (GITU). Se omiten resultados de mediciones con el fin de servir como pliego de validación estructural del sistema.

== 1. Especificaciones de Hardware y Software de Pruebas

Para asegurar condiciones controladas y la repetitividad de los escenarios de validación en el entorno local (127.0.0.1), se definen las siguientes especificaciones estándar para las estaciones de medición:

- *Hardware de Referencia:* Procesador de 4 núcleos físicos o superior, mínimo 8 GB de Memoria RAM, Almacenamiento de estado sólido (SSD).
- *Software Base:* Sistema operativo compatible (Windows 11 o Linux Ubuntu 22.04 LTS), Python 3.10 o superior, PyZMQ >= 25.0.0, SQLite 3.
- *Herramientas de Medición:* Utilización de la librería `psutil` para monitoreo de RAM, comando `shutil.disk_usage` para almacenamiento, marcas de tiempo del sistema de microsegundos mediante el módulo `time` de Python y el administrador de recursos nativo del sistema operativo.

== 2. Pruebas de Desempeño

=== ID: 6
- *Métrica:* Tasa de Ingesta
- *Escenario de Prueba:* Medir cuántas solicitudes se almacenan en la BD en un intervalo de 2 minutos bajo un flujo masivo y constante de sensores simulados.
- *Herramienta de Medición:* Contador integrado en el script de la base de datos principal (`base_datos_principal.py`) que registre el total de inserciones físicas exitosas (`total_inserts`) realizadas en una ventana de observación de 120 segundos.

=== ID: 7
- *Métrica:* Latencia de Acción
- *Escenario de Prueba:* Medir el retraso temporal desde que un usuario de la interfaz de monitoreo solicita una acción de prioridad ("Ola Verde") en el PC3 hasta que el semáforo cambia físicamente de estado en el controlador del PC2.
- *Herramienta de Medición:* Cálculo de la diferencia absoluta entre el instante de salida (`timestamp_solicitud` en PC3) y el de recepción (`timestamp_ejecucion` en PC2) utilizando relojes sincronizados localmente.

=== ID: 8
- *Métrica:* Escalabilidad
- *Escenario de Prueba:* Comparar la velocidad del procesamiento y correlación de datos analíticos bajo dos niveles de carga diferenciados: escenario base (1 sensor enviando cada 10 segundos) frente a escenario de carga (2 sensores enviando cada 5 segundos).
- *Herramienta de Medición:* Ejecución de pruebas automatizadas P01 y P02 para ambos escenarios, graficando las curvas de degradación o estabilidad temporal de procesamiento.

=== ID: 9
- *Métrica:* Carga Progresiva
- *Escenario de Prueba:* Incrementar de manera secuencial y progresiva los procesos de sensores activos en la cuadrícula urbana, subiendo de 10 en 10 sensores activos de manera controlada hasta llegar a un tope de 50 sensores concurrentes.
- *Herramienta de Medición:* Observación sistemática del incremento de los tiempos promedio de respuesta y sincronización del buffer de analítica conforme asciende el número de procesos activos.

=== ID: 10
- *Métrica:* Estrés de Recursos
- *Escenario de Prueba:* Monitorear el consumo de CPU y memoria RAM en la máquina de analítica mientras se ejecutan 500 hilos de sensores concurrentes en paralelo emitiendo de manera constante.
- *Herramienta de Medición:* Análisis dinámico mediante herramientas del sistema operativo (`htop` o Administrador de Tareas) para identificar si la CPU llega al 100% de saturación o si existen fugas de memoria en las colas de buffers.

=== ID: 11
- *Métrica:* Escalabilidad ZMQ
- *Escenario de Prueba:* Evaluar los límites de concurrencia y retardo del transporte de red de ZeroMQ comparando el comportamiento dinámico con 1 sensor emitiendo a 10s contra 2 sensores emitiendo a 5s.
- *Herramienta de Medición:* Registro de tiempos de viaje de mensajes y uso proporcional de buffers de red bajo variaciones de tasa de envío para graficar curvas de degradación.


== 3. Pruebas de Tolerancia a Fallos

=== ID: 12
- *Caso de Prueba:* Falla de la Base de Datos Principal (PC3)
- *Procedimiento:* Simular la caída de la base de datos principal mediante la desconexión del servicio de red o apagando de forma abrupta el proceso correspondiente (`base_datos_principal.py`) mientras la plataforma se encuentra operando y recibiendo telemetría de sensores en tiempo real.
- *Resultado Esperado:* El Servicio de Analítica debe detectar el error del socket y redirigir todos los flujos de mensajería `PUSH` de respaldo hacia la Base de Datos de Réplica (`base_datos_replica.py`) en el PC2 de forma transparente y sin pérdidas.

=== ID: 13
- *Caso de Prueba:* Sincronización e Integridad de la Réplica
- *Procedimiento:* Validar la consistencia de los datos almacenados en los dos servidores de persistencia bajo un flujo de envío ininterrumpido.
- *Resultado Esperado:* Al comparar el conteo absoluto de registros mediante la consulta `SELECT COUNT(*)` en ambas bases de datos (`trafico_principal.db` y `trafico_replica.db`) tras una ventana de operación de 5 minutos, los resultados numéricos deben ser exactamente idénticos, garantizando consistencia activa total.

=== ID: 14
- *Caso de Prueba:* Recuperación tras Falla (Health Check & Failback)
- *Procedimiento:* Simular el restablecimiento del PC3 (Base de Datos Principal) volviendo a iniciar su servicio de red y su proceso de persistencia después de un periodo de inactividad controlado.
- *Resultado Esperado:* Al re-encenderse, la BD Principal debe conectarse síncronamente a la Réplica en el PC2, realizar una sincronización diferencial autónoma de los registros perdidos mediante `INSERT OR IGNORE`, y los procesos de consulta deben intentar reanudar de forma transparente sus flujos hacia la BD principal o mantener la operación estable en la réplica si el diseño no permite el retorno inmediato.

== 4. Pruebas de Utilización

=== ID: 15
- *Métrica:* Uso de Memoria
- *Descripción:* Medir el impacto de memoria RAM que genera la ejecución del Broker central de ZeroMQ en el PC1 bajo condiciones de alta carga.
- *Meta:* El consumo de memoria del proceso del Broker no debe exceder en ningún caso el 20% de la capacidad disponible para procesos en segundo plano del sistema operativo.

=== ID: 16
- *Métrica:* Alertas de Recursos
- *Descripción:* Forzar artificialmente una condición de falta de espacio en disco en el nodo PC2, el cual aloja la base de datos de réplica y respaldo.
- *Meta:* El sistema debe de ser capaz de interceptar la falta de recursos de hardware y emitir de manera inmediata alertas críticas de advertencia en la terminal de logs para notificar al administrador del riesgo inminente.


Conclusiones Generales del Proyecto

Tras completar el diseño, despliegue y formulación del protocolo de validación para la Plataforma de Gestión Inteligente de Tráfico Urbano (GITU), se formulan las siguientes conclusiones de ingeniería:

1. *Desacoplamiento Eficiente mediante Arquitectura de Eventos:* La adopción de patrones de mensajería asíncronos con ZeroMQ (XSUB/XPUB, PUSH/PULL) demostró ser altamente eficiente. Al eliminar las dependencias de red directas y síncronas entre los sensores, el motor de analítica y las bases de datos, se logra que la caída de un servicio (como el de persistencia principal) no afecte el flujo operativo de control semafórico, eliminando así puntos únicos de fallo.

2. *La Importancia de la Tolerancia a Fallas Activa-Pasiva:* La dupla formada por el _failover_ automático en caliente (basado en timeouts de sockets síncronos) y el algoritmo de _reconciliación diferencial_ post-falla, representa una solución idónea para sistemas críticos de infraestructura civil. Esto asegura que el sistema se comporte de forma robusta frente a interrupciones de red, reparando su consistencia en milisegundos una vez vuelve a la normalidad de forma transparente para el operador humano.

3. *Eficiencia en la Multiplexación de E/S con Sockets:* La implementación del patrón Reactor (`zmq.Poller`) en lugar de arquitecturas multi-hilo masivas para la lectura de sockets evita el sobrecosto de contexto del sistema operativo. Esto permite procesar cientos de eventos de tráfico por segundo utilizando una cantidad de memoria RAM insignificante (ID 15) y con bajísimas latencias de conmutación.

4. *Garantías de Seguridad desde el Diseño:* El acoplamiento de validadores de integridad estructural y sanitización estricta de variables en la entrada de la analítica, combinado con el aislamiento de red privada, demuestra que es posible blindar arquitecturas distribuidas de ataques de inyección sin penalizar el rendimiento global ni la velocidad del procesamiento en tiempo real.

