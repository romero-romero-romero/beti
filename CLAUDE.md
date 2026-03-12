# Documento de Requerimientos: Betty (App de Salud Financiera Minimalista y Offline-First)

## 1. Resumen del Proyecto
Betty es una aplicación móvil (Android/iOS) diseñada para eliminar la fricción de la gestión financiera personal. A diferencia de las hojas de cálculo complejas, Betty procesa ingresos y egresos mediante notas de voz, fotos de tickets o formularios simples. Su núcleo es la **Salud Financiera Emocional**: traduce el estado del presupuesto y deudas en un termómetro de bienestar. 
La aplicación tiene una arquitectura **Offline-First**, lo que garantiza que el usuario pueda registrar transacciones, consultar su salud financiera y recibir análisis sin necesidad de conexión a internet. Toda la inteligencia de la app es impulsada por modelos propios de **TensorFlow** ejecutados localmente en el dispositivo (On-Device ML), garantizando máxima privacidad y velocidad.

## 2. Requerimientos Funcionales

### 2.1 Autenticación y Perfil de Usuario
* Registro e inicio de sesión con Correo/Contraseña y Google (OAuth).
* **Persistencia de sesión:** Una vez autenticado por primera vez (requiere internet), el usuario debe poder abrir y usar la app permanentemente sin conexión.

### 2.2 Gestión de Transacciones (100% Offline)
* **Ingreso por Voz (Local):** El usuario puede dictar un gasto. El sistema debe usar librerías de Speech-to-Text integradas en el dispositivo (ej. Apple Speech / Google On-Device) para procesar el audio sin internet.
* **OCR por Fotografía (Local):** Extracción de texto de tickets usando herramientas en el dispositivo (ej. Google ML Kit On-Device) para obtener monto, fecha y concepto sin consumir datos móviles.
* **Flujo de Corrección:** "Vista Previa" obligatoria para confirmar o corregir la interpretación de la voz o foto antes de guardar.
* Ingreso Manual tradicional disponible. Edición y eliminación de registros.

### 2.3 Motor Financiero y Machine Learning (TensorFlow Lite)
* El análisis de comportamiento, la predicción de categorías y la sugerencia de "Presupuestos Reales" deben ejecutarse localmente utilizando modelos de **TensorFlow Lite (.tflite)** integrados en la aplicación.
* La app debe entrenar (o ajustar pesos) y realizar inferencias sobre los datos almacenados en el teléfono, sin enviar el historial financiero a ningún servidor para su análisis.
* El motor contempla internamente la lógica de finanzas (Ingresos, Gastos, Tarjetas, Créditos, Metas), autocompletando categorías para el usuario.

### 2.4 Módulo de Salud Financiera Emocional
* **Termómetro de Salud Offline:** El índice de bienestar (Paz vs. Malestar) se calcula en tiempo real en el dispositivo basándose en los registros locales.
* Interfaz dinámica que cambia colores y mensajes según el estado de salud financiera del usuario.

### 2.5 Integración Bancaria (API Belvo) y Alertas
* **Sincronización Asíncrona:** La vinculación de cuentas y la actualización de saldos/fechas vía Belvo requerirá conexión a internet. Sin embargo, la app debe guardar en caché el último estado conocido. Si el usuario está offline, podrá ver sus tarjetas y saldos consultados en la última conexión.
* **Sistema de Alertas Locales:** Las notificaciones para prevenir el sobreendeudamiento (exactamente **3 días antes de la fecha de corte** y **3 días antes de la fecha límite de pago**) deben programarse en el sistema operativo del teléfono (Local Notifications) basándose en la última información obtenida, garantizando que suenen incluso si el teléfono lleva días sin internet o en modo avión.
* Posibilidad de activar/desactivar alertas por tarjeta.

## 3. Requerimientos No Funcionales

### 3.1 Interfaz y Experiencia de Usuario (UI/UX)
* **Minimalismo:** Ocultar la complejidad matemática.
* Respuesta inmediata (< 100ms) al no depender de tiempos de carga de red para interactuar con la interfaz.
* Modo Claro/Oscuro y diseño enfocado en la psicología del color para la retroalimentación emocional.

### 3.2 Arquitectura de Datos y Backend (Offline-First)
* **Base de Datos Local (Primaria):** La app debe utilizar una base de datos local robusta como fuente única de la verdad. Toda lectura y escritura en la app se hace aquí.
* **Sincronización en Segundo Plano (Supabase):** Supabase actuará únicamente como respaldo (Backup) y gestor de Auth. Cuando la app detecte conexión a internet, un proceso en segundo plano (Background Sync) actualizará silenciosamente la base de datos de Supabase y subirá las imágenes de los tickets comprimidas a *Supabase Storage*.

### 3.3 Seguridad y Privacidad
* Toda la inferencia de Inteligencia Artificial (TensorFlow) ocurre dentro del hardware del usuario.
* Las llamadas a Belvo seguirán ocurriendo a través de Edge Functions en la nube (cuando haya conexión) para proteger las credenciales y tokens del backend.

### 3.4 Disponibilidad
* La aplicación no tendrá pantallas de carga bloqueantes por falta de red. Todo guardado o análisis es inmediato.

## 4. Directrices de Arquitectura Sugeridas (Para el Tech Lead)

Para garantizar un desarrollo escalable, optimizado y con la mejor experiencia de usuario, se deben considerar las siguientes directrices técnicas durante la implementación:

### 4.1 Estrategia de IA y Modelo Híbrido (MVP)
* Para la primera versión (MVP), implementar un motor híbrido de categorización. Utilizar algoritmos de coincidencia de palabras clave (Regex/Tokenization) en el dispositivo. Las categorizaciones manuales del usuario alimentarán la base de datos local para entrenar y refinar el modelo de **TensorFlow Lite** en fases posteriores.
* Utilizar `google_mlkit_text_recognition` para el OCR y dependencias nativas para el Speech-to-Text, asegurando que el procesamiento sea 100% offline.

### 4.2 Base de Datos Local y Optimización de Batería
* **Isar Database:** Utilizar Isar como la base de datos local principal en Flutter debido a su rendimiento superior, soporte NoSQL y capacidad de búsqueda de texto completo rápida (esencial para el motor financiero).
* **Sincronización por Ciclo de Vida:** La sincronización con Supabase (Backup) no debe depender exclusivamente de Cron Jobs que drenen la batería. Debe estar atada al `AppLifecycleState` (disparando la sincronización silenciosa cuando la app pasa de estado `paused` a `resumed` y hay conexión).
* **Webhooks + Silent Pushes:** Para las actualizaciones de Belvo, configurar Webhooks en el backend (Edge Functions). Cuando Belvo detecte un cambio en las cuentas, Supabase enviará una "Silent Push Notification" para despertar la app brevemente, actualizar Isar localmente y reprogramar las alertas locales de los 3 días si es necesario.

### 4.3 Experiencia de Usuario Extendida
* **Micro-interacciones (Rive/Lottie):** Implementar animaciones basadas en estados (State Machines) para representar la Salud Financiera Emocional. Por ejemplo, una animación suave de "respiración" para el estado de paz financiera y pulsos más ágiles para alertas de malestar.
* **Onboarding "Offline-First":** Al vincular Belvo por primera vez, presentar una pantalla de carga inmersiva que informe al usuario que la app está "organizando su historial localmente" para poder funcionar sin internet, mitigando la fricción del tiempo de descarga inicial.