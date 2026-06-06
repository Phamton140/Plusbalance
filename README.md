# +Balance

**+Balance** es una aplicación móvil de finanzas personales pensada para funcionar 100% **offline**. Permite llevar un control detallado de cuentas, categorías, transacciones, servicios recurrentes y metas de ahorro, con un dashboard que muestra el patrimonio y la distribución de gastos en un gráfico de pastel.

> El nombre "+Balance" hace referencia a sumar equilibrio a tus finanzas: registrar, visualizar y planificar.

---

## Tabla de contenidos

- [Capturas de pantalla](#capturas-de-pantalla)
- [Funcionalidades](#funcionalidades)
- [Tecnologías](#tecnologías)
- [Arquitectura](#arquitectura)
- [Instalación](#instalación)
- [Ejecución](#ejecución)
- [Generación de código (Drift)](#generación-de-código-drift)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Pendientes por hacer](#pendientes-por-hacer)
- [Mejoras futuras](#mejoras-futuras)
- [Licencia](#licencia)

---

## Capturas de pantalla

> _Por agregar._

## Funcionalidades

- **Dashboard** con saldo total, gráfico de pastel por categoría y acceso rápido a los módulos.
- **Cuentas y tarjetas** (efectivo, débito, crédito, billetera) con saldo, institución, límite de crédito, día de corte, día de pago y tasa de interés.
- **Categorías personalizables** con ícono y color. Se instalan por defecto: Hogar, Alimentos, Salud, Gym, Transporte, Viajes, Compras y Ahorro/Metas.
- **Transacciones** de gasto, ingreso y transferencia entre cuentas (incluye "A Tercero").
- **Servicios / suscripciones** recurrentes (una vez, semanal, mensual, anual) con recordatorios, etiquetas *want/need* y generación automática de transacción al vencer.
- **Metas de ahorro** con monto objetivo, fecha límite, progreso y abonos que debitan automáticamente de la cuenta seleccionada.
- **Historial** filtrable y exportación a **PDF** tipo estado de cuenta con resumen, saldos por cuenta y detalle de transacciones.
- **Notificaciones** de servicios próximos a vencer y atrasados.
- **Perfil** con biometría (`local_auth`) y almacenamiento seguro (`flutter_secure_storage`).
- **100% offline**: usa SQLite local mediante Drift.

---

## Tecnologías

### Framework y lenguaje
- **[Flutter](https://flutter.dev/)** (SDK `^3.11.0`) — UI multiplataforma (Android, iOS, Web, Windows, macOS, Linux).
- **[Dart](https://dart.dev/)** — Lenguaje principal.

### Estado y navegación
- [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) — Manejo de estado reactivo.
- [`riverpod_annotation`](https://pub.dev/packages/riverpod_annotation) — Anotaciones para generadores de Riverpod.
- [`go_router`](https://pub.dev/packages/go_router) — Navegación declarativa.

### Persistencia
- [`drift`](https://pub.dev/packages/drift) — ORM SQLite con seguridad de tipos y `Streams` reactivos.
- [`sqlite3_flutter_libs`](https://pub.dev/packages/sqlite3_flutter_libs) — Binarios de SQLite.
- [`path_provider`](https://pub.dev/packages/path_provider) — Rutas del sistema de archivos.
- [`path`](https://pub.dev/packages/path) — Manipulación de rutas.

### UI y animaciones
- [`fl_chart`](https://pub.dev/packages/fl_chart) — Gráficos (pastel).
- [`flutter_animate`](https://pub.dev/packages/flutter_animate) — Animaciones declarativas.
- [`google_fonts`](https://pub.dev/packages/google_fonts) — Tipografías.
- [`cupertino_icons`](https://pub.dev/packages/cupertino_icons) — Íconos estilo iOS.

### Autenticación y seguridad
- [`local_auth`](https://pub.dev/packages/local_auth) — Autenticación biométrica.
- [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) — Almacenamiento cifrado.

### Utilidades
- [`uuid`](https://pub.dev/packages/uuid) — Generación de IDs.
- [`intl`](https://pub.dev/packages/intl) — Formato de fechas y números.

### Exportación PDF
- [`pdf`](https://pub.dev/packages/pdf) — Generación de documentos PDF.
- [`printing`](https://pub.dev/packages/printing) — Impresión y compartir PDF (incluye fuentes Google *Roboto*).

### Tooling
- [`build_runner`](https://pub.dev/packages/build_runner) + [`drift_dev`](https://pub.dev/packages/drift_dev) — Generación de código.
- [`flutter_lints`](https://pub.dev/packages/flutter_lints) — Linting.

---

## Arquitectura

El proyecto sigue una separación por **features** con un núcleo compartido:

```
lib/
├── core/                # Núcleo (DB, providers, automatización, tema)
│   ├── database/        # Drift: tablas, DAOs, esquema
│   ├── providers/       # Providers globales (DAOs, streams)
│   └── ...
├── features/            # Módulos de la app
│   ├── accounts/
│   ├── categories/
│   ├── dashboard/
│   ├── goals/
│   ├── notifications/
│   ├── profile/
│   ├── services/
│   └── transactions/
└── main.dart
```

Cada feature expone su capa de **presentación** (screens / widgets) y, cuando aplica, una capa de **dominio** (servicios, modelos) consumida por los providers de Riverpod.

La base de datos se versiona con `schemaVersion = 4`; las migraciones se declaran en `lib/core/database/app_database.dart`.

---

## Instalación

### Requisitos previos

| Herramienta | Versión recomendada |
|-------------|---------------------|
| Flutter SDK  | `>= 3.11.0` (Dart `^3.x`) |
| Git          | cualquiera reciente |
| Android Studio / Xcode | Para emuladores y builds móviles |
| Java JDK     | 17 (para builds Android modernos) |

Verifica tu entorno:

```bash
flutter --version
flutter doctor
```

### Pasos

1. **Clonar el repositorio**

   ```bash
   git clone https://github.com/Phamton140/Plusbalance.git
   cd Plusbalance
   ```

2. **Instalar dependencias de Flutter**

   ```bash
   flutter pub get
   ```

3. **Regenerar código de Drift** (necesario la primera vez y tras tocar tablas/DAOs)

   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

   > El flag `--delete-conflicting-outputs` ya no es aceptado por `build_runner` recientes; el comando equivalente es:
   >
   > ```bash
   > flutter pub run build_runner build
   > ```

---

## Ejecución

### En un emulador o dispositivo conectado

```bash
# Android
flutter run -d android

# iOS (requiere macOS)
flutter run -d ios

# Web (modo experimental)
flutter run -d chrome
```

### Build de release

```bash
flutter build apk --release       # Android APK
flutter build appbundle --release # Android AAB
flutter build ios --release       # iOS
```

### Análisis estático y formato

```bash
flutter analyze
flutter format .
```

### Tests

```bash
flutter test
```

> Este proyecto aún no incluye una suite de tests completa (ver [Pendientes](#pendientes-por-hacer)).

---

## Generación de código (Drift)

Drift genera automáticamente las clases tipadas de las tablas y los *mixins* de los DAOs (`*.g.dart`). Cada vez que modifiques:

- Una tabla en `lib/core/database/tables.dart`
- Un DAO en `lib/core/database/daos/`
- El `schemaVersion` o las migraciones en `app_database.dart`

…debes regenerar:

```bash
flutter pub run build_runner build
```

Para watch continuo durante desarrollo:

```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

---

## Estructura del proyecto

```
lib/
├── core/
│   ├── automation/
│   │   └── automation_engine.dart     # Dispara pagos automáticos de servicios
│   ├── database/
│   │   ├── app_database.dart          # @DriftDatabase + migraciones
│   │   ├── tables.dart                 # Definición de tablas
│   │   └── daos/
│   │       ├── accounts_dao.dart
│   │       ├── categories_dao.dart
│   │       ├── goals_dao.dart
│   │       ├── services_dao.dart
│   │       ├── settings_dao.dart
│   │       └── transactions_dao.dart
│   ├── providers/
│   │   └── database_provider.dart     # Providers de DB y DAOs
│   └── theme/
│       └── app_theme.dart
├── features/
│   ├── accounts/                       # Cuentas y tarjetas
│   ├── categories/                     # Gestión de categorías
│   ├── dashboard/                      # Pantalla principal con gráfico pastel
│   ├── goals/                          # Metas de ahorro + abonos
│   ├── notifications/                  # Servicios por vencer / atrasados
│   ├── profile/                        # Perfil y ajustes
│   ├── services/                       # Servicios recurrentes
│   └── transactions/                   # Transacciones + exportación PDF
└── main.dart
```

---

## Pendientes por hacer

Funcionalidades contempladas en el roadmap del proyecto pero **aún no implementadas**:

- [ ] **Sincronización en la nube** (Firebase / Supabase) para respaldar y sincronizar entre dispositivos.
- [ ] **Presupuestos mensuales** por categoría con alertas al acercarse al límite.
- [ ] **Multi-moneda real**: conversión dinámica con tasas de cambio actualizadas (actualmente el campo `exchangeRate` existe en la tabla pero no se utiliza).
- [ ] **Adjuntar comprobantes** (foto/PDF) a las transacciones (la tabla `Attachments` ya existe).
- [ ] **Etiquetas / tags** personalizadas y filtrado por tag (la tabla `Tags` ya existe).
- [ ] **Recordatorios push locales** configurables por servicio (actualmente sólo in-app).
- [ ] **Exportación a Excel / CSV** además de PDF.
- [ ] **Autenticación con PIN / biometría al abrir la app** (la integración con `local_auth` está preparada pero no se exige al inicio).
- [ ] **Dashboard con más indicadores**: evolución del saldo en el tiempo, comparativa mes a mes, top gastos.
- [ ] **Suite de tests**: unitarios para DAOs y lógica de negocio, widget tests para pantallas clave, integración para flujos críticos.
- [ ] **Internacionalización (i18n)** — la app está en español; falta inglés.
- [ ] **Modo oscuro** explícito configurable (ya se usan temas, falta el switch).
- [ ] **Widget de escritorio** con saldo rápido (Android / iOS).

---

## Mejoras futuras

Sugerencias pensadas para una **v2** del producto, más allá del MVP:

- **Inteligencia artificial para categorización automática** de transacciones a partir de la descripción.
- **Open Finance** — conexión con bancos vía APIs (Plaid, Belvo, etc.) para importar transacciones automáticamente.
- **Metas compartidas** — invitar a otra persona a contribuir a una misma meta.
- **Reglas de transacción** — "si descripción contiene X, asignar categoría Y y cuenta Z".
- **Análisis predictivo** — proyección de gastos del mes y alerta de posible sobregiro.
- **Gamificación** — rachas de ahorro, logros, badges.
- **Exportación programática** — API local (intents / deep links) para que otras apps (p. ej. una de inversión) lean datos.
- **Modo "compartido"** — cuentas familiares con varios usuarios y permisos.
- **Migración a Drift 3** / `drift_flutter` con isolates para escalar a >100k transacciones.
- **Tema personalizable** — el usuario puede elegir su color de acento.
- **Atajos de iOS / Android** (App Intents / App Actions) para registrar un gasto rápido desde fuera de la app.
- **Widget dinámico de saldo** en home screen.
- **Modo claro automático según hora del día** (sunrise/sunset).
- **Sincronización opcional entre dispositivos del mismo usuario** mediante QR/código de emparejamiento (sin servidor).
- **Soporte para más tipos de cuenta** — cripto, inversiones, deudas, préstamos.

---

## Licencia

Por definir. Por defecto, todos los derechos reservados al autor.
