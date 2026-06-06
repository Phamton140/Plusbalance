# +Balance

> **Estado:** ✅ Proyecto **concluido** en su versión 1.0 (MVP completo offline). Este documento describe la versión final entregada y la guía para retomar o extender el proyecto.

**+Balance** es una aplicación móvil de finanzas personales pensada para funcionar 100% **offline**. Permite llevar un control detallado de cuentas, categorías, transacciones, servicios recurrentes, metas de ahorro y recordatorios automáticos, con un dashboard que muestra patrimonio, distribución de gastos y alertas de cargos por vencer. Las transferencias entre cuentas y hacia terceros se registran con un solo toque, y todo el historial puede exportarse a un PDF tipo estado de cuenta.

> El nombre "+Balance" hace referencia a *sumar equilibrio* a tus finanzas: registrar, visualizar y planificar.

---

## Tabla de contenidos

- [Conclusión del proyecto](#conclusión-del-proyecto)
- [Funcionalidades](#funcionalidades)
- [Capturas / Demo](#capturas--demo)
- [Tecnologías](#tecnologías)
- [Arquitectura](#arquitectura)
- [Esquema de la base de datos](#esquema-de-la-base-de-datos)
- [Instalación](#instalación)
- [Ejecución](#ejecución)
- [Generación de código (Drift)](#generación-de-código-drift)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Pendientes por hacer](#pendientes-por-hacer)
- [Mejoras futuras](#mejoras-futuras)
- [Créditos y licencia](#créditos-y-licencia)

---

## Conclusión del proyecto

El MVP está **funcionalmente cerrado**:

- Onboarding, PIN y biometría (`flutter_secure_storage` + `local_auth`).
- Cuentas, categorías, transacciones, transferencias, servicios recurrentes, metas de ahorro, recordatorios, dashboard, exportación PDF.
- Recargas automáticas de cuentas (semanal / quincenal 1ra+2da / mensual) con notificación aplicable en un toque.
- Modo de cuenta de efectivo fijo, no editable más allá de saldo y recurrencia.
- 100% offline, base de datos SQLite gestionada con **Drift** (versión de esquema `8`).
- Tema, accesibilidad y animaciones cuidadas; build de release Android firmado y verificado.

Lo que queda son **extensiones de producto** (sync en la nube, presupuestos, multi-moneda real, etc.), no piezas rotas del MVP. Ver [Pendientes](#pendientes-por-hacer) y [Mejoras futuras](#mejoras-futuras).

---

## Funcionalidades

### Autenticación y seguridad
- **PIN de 6 dígitos** almacenado en `flutter_secure_storage` (Android EncryptedSharedPreferences).
- **Huella / Face ID** opcional con `local_auth` como desbloqueo rápido.
- Pantalla de splash con *spinner* y subtítulo "Cargando +Balance…"; la inicialización está envuelta en `try/catch` con *timeout* para que un fallo de almacenamiento no congele la app.
- `MainActivity` extendido de `FlutterFragmentActivity` (requerido por `flutter_secure_storage` v10).
- Reglas de backup en `AndroidManifest.xml` que excluyen `flutter_secure_storage.xml` (Android 12+).

### Cuentas
- **Efectivo, débito, crédito, billetera virtual** con saldo, institución, alias, color y (para crédito) límite, día de corte, día de pago y tasa.
- **Cuenta Efectivo predeterminada** (`id = efectivo-default`), única e inalterable: nombre fijo "Efectivo", color gris fijo, no se puede eliminar ni renombrar. Solo se modifican saldo y recurrencia de recarga.
- **Recurrencia de recarga** opcional: `none` / `weekly` / `biweekly` / `monthly` con próxima fecha, monto y concepto.
  - **Quincenal** admite **dos fechas por mes** (1ra y 2da), cada una con su propio monto. El selector de la 2da fecha se abre en el mismo mes que la 1ra para evitar combinaciones incoherentes.
- Selector de fechas siempre bloquea hoy y días pasados (`firstDate: tomorrow`).

### Categorías
- 8 categorías por defecto con ícono y color únicos: Hogar, Alimentos, Salud, Gym, Transporte, Viajes, Compras, Ahorro/Metas.
- Paleta de 16 colores diferenciados. Los colores **reservados** del sistema (Metas `#00D4AA`, Transferencia `#FB8C00`, Efectivo `#9E9E9E`) están **bloqueados**: el *picker* los muestra atenuados con candado y el guardado los rechaza aunque el usuario force la selección.
- Iconos personalizables (12 opciones).
- Validación de nombre único *case-insensitive*.

### Transacciones
- **Gasto**, **Ingreso** y **Transferencia** conmutables con un `SegmentedButton` (tamaño constante, sin íconos de selección para evitar saltos).
- **Transferencias** entre cuentas propias, o **hacia/desde un Tercero** (con descripción libre).
- En transferencias, la categoría se asigna automáticamente y el *dropdown* se reemplaza por un *chip* "Categoría automática: Transferencia" para evitar errores.
- Validación de saldo insuficiente con `SnackBar`.

### Metas de ahorro
- Nombre, monto objetivo, fecha límite opcional.
- Barra de progreso `Color.lerp(gris, verde, %)` con `ClipRRect`.
- **Abonar a meta** debita automáticamente de la cuenta seleccionada y registra un gasto en la categoría "Ahorro / Metas" para mantener coherencia en el dashboard.

### Servicios recurrentes
- Nombre, monto, cuenta, categoría, fecha de inicio, frecuencia (`once` / `weekly` / `biweekly` / `monthly` / `yearly`), etiquetas *want/need* y estado.
- **Picker de fecha** siempre `>= mañana`.
- **Recordatorios**: pantalla de Notificaciones muestra servicios atrasados y próximos a vencer, con un botón **Aplicar** que crea la transacción, descuenta el saldo de la cuenta y avanza la fecha del servicio en una sola operación atómica.

### Recargas de cuenta
- Proveedor reactivo `upcomingAccountRechargesProvider` emite 1 o 2 `AccountRecharge` por cuenta según la recurrencia (1ra y 2da en quincenal).
- La pantalla de Notificaciones muestra atrasadas y próximas (≤ 7 días) con botón **Aplicar** y `AlertDialog` de confirmación; al aplicar, se crea la transacción y se avanza la fecha de la 1ra o 2da recarga según corresponda.

### Dashboard
- Saldo total, gráfico de pastel por categoría (últimos 30 días), saldo por cuenta.
- Acceso rápido a todas las secciones.

### Historial
- Listado agrupado por día con encabezado de día largo (en español) y tarjeta por transacción mostrando solo la **hora (HH:mm)**.
- Transferencias se distinguen con `Icons.sync_alt`, color azul y sin signo `+/-`.
- Filtros por cuenta, tipo y categoría; búsqueda libre.

### Exportación a PDF
- "Estado de cuenta" con resumen de patrimonio, saldos por cuenta y tabla de transacciones (Fecha con **dd/MM/yyyy HH:mm**, descripción, categoría, cuenta, monto).
- Compartir directamente desde el sistema (`printing`).

### Tema y UX
- Material 3, `google_fonts` (Inter / Roboto), animaciones declarativas (`flutter_animate`).
- **Campos de texto limpios**: sin `onTap` que seleccione todo automáticamente, sin `enableSuggestions:false`/`autocorrect:false` en campos alfabéticos (compatibles con *swipe-to-type* en Gboard).
- **Campo de monto** con `OutlineInputBorder`, prefijo `$`, label "Monto", *hint* "0.00" y tamaño de fuente generoso.

---

## Tecnologías

### Framework y lenguaje
- **[Flutter](https://flutter.dev/)** (SDK `^3.11.0`) — UI multiplataforma.
- **[Dart](https://dart.dev/)** `^3.x` — Lenguaje principal.

### Estado y navegación
- [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) v3 + `Notifier` (no `ChangeNotifier`).
- [`go_router`](https://pub.dev/packages/go_router) — Navegación declarativa.

### Persistencia
- [`drift`](https://pub.dev/packages/drift) — ORM SQLite con tipos seguros y *Streams* reactivos.
- `sqlite3_flutter_libs`, `path_provider`, `path`.

### UI y animaciones
- [`fl_chart`](https://pub.dev/packages/fl_chart), `flutter_animate`, `google_fonts`, `cupertino_icons`.

### Autenticación y seguridad
- [`local_auth`](https://pub.dev/packages/local_auth), [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) v10.

### Exportación PDF
- [`pdf`](https://pub.dev/packages/pdf), [`printing`](https://pub.dev/packages/printing).

### Tooling
- `build_runner` + `drift_dev`, `flutter_lints`.

---

## Arquitectura

Separación por **features** con núcleo compartido. Cada feature expone `presentation/` (screens y widgets) y, cuando aplica, `domain/` (servicios, modelos), consumidos por *providers* de Riverpod.

```
lib/
├── core/
│   ├── automation/         # Motor de pagos/recordatorios
│   ├── database/           # Drift: tablas, DAOs, esquema
│   ├── providers/          # Providers globales
│   ├── security/           # PIN, cifrado
│   └── theme/              # Paleta, tema, paleta de categorías
├── features/
│   ├── accounts/           # Cuentas + recargas
│   ├── categories/         # Categorías personalizables
│   ├── dashboard/          # Resumen + gráfico
│   ├── goals/              # Metas de ahorro
│   ├── notifications/      # Pendientes y recordatorios
│   ├── profile/            # Perfil y biometría
│   ├── services/           # Servicios recurrentes
│   └── transactions/       # Transacciones, historial, PDF
└── main.dart
```

**Flujo de datos típico**: `Screens` → leen `Provider` (Riverpod) → llaman al DAO (Drift) → la base de datos emite un *Stream* → el *provider* lo re-emite → la UI se reconstruye.

---

## Esquema de la base de datos

Drift vive en `lib/core/database/`. Tablas principales:

| Tabla | Notas |
|-------|-------|
| `Accounts` | Saldo, tipo, color, recargas (`rechargeFrequency`, `rechargeNextDate`, `rechargeNextDate2`, `rechargeAmount`, `rechargeAmount2`, `rechargeLabel`, `institutionName`). |
| `Categories` | Nombre único, color, ícono (codepoint). |
| `Transactions` | Monto, fecha, tipo (`expense`/`income`/`transfer`), cuenta, categoría, descripción. |
| `Services` | Frecuencia, próxima fecha, *want/need*, estado, cuenta, categoría. |
| `Goals` | Nombre, monto objetivo, monto actual, fecha límite. |
| `Settings` | Llave/valor (cuenta por defecto, moneda, etc.). |

**Versión de esquema actual: `8`.** Las migraciones se declaran en `AppDatabase.onUpgrade`:

| v | Cambio |
|---|--------|
| 2 | Tabla `categories` + FK desde `services` y `transactions`. |
| 3 | Columna `services.status`. |
| 4 | Categorías por defecto. |
| 5 | Columnas de recarga semanal/mensual. |
| 6 | Columnas de recarga quincenal (1ra y 2da). |
| 7 | `institutionName='Efectivo'` en cuenta por defecto. |
| 8 | Cuenta efectivo siempre gris + colores de categorías reservados. |

Para regenerar el código Drift:

```bash
flutter pub run build_runner build
```

---

## Instalación

### Requisitos

| Herramienta | Versión recomendada |
|-------------|---------------------|
| Flutter SDK | `>= 3.11.0` (Dart `^3.x`) |
| Git | reciente |
| Android Studio / Xcode | Para emuladores y builds móviles |
| Java JDK | 17 (Android moderno) |

```bash
flutter --version
flutter doctor
```

### Pasos

```bash
git clone https://github.com/Phamton140/Plusbalance.git
cd Plusbalance
flutter pub get
flutter pub run build_runner build
```

---

## Ejecución

```bash
flutter run -d android            # Android
flutter run -d ios                # iOS (requiere macOS)
flutter run -d chrome             # Web (experimental)
```

### Build de release

```bash
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
```

### Análisis y formato

```bash
flutter analyze
flutter format .
```

### Tests

> El proyecto no incluye aún una *suite* completa (ver [Pendientes](#pendientes-por-hacer)).

```bash
flutter test
```

---

## Estructura del proyecto

```
lib/
├── core/
│   ├── automation/
│   │   └── automation_engine.dart         # Dispara pagos / recordatorios
│   ├── database/
│   │   ├── app_database.dart               # @DriftDatabase + migraciones v1..v8
│   │   ├── tables.dart                     # Definición de tablas
│   │   └── daos/
│   │       ├── accounts_dao.dart
│   │       ├── categories_dao.dart
│   │       ├── goals_dao.dart
│   │       ├── services_dao.dart
│   │       ├── settings_dao.dart
│   │       └── transactions_dao.dart       # applyServicePayment / applyAccountRecharge
│   ├── providers/
│   │   └── database_provider.dart
│   ├── security/
│   │   └── pin_service.dart                # try/catch + timeout
│   └── theme/
│       ├── app_theme.dart
│       └── category_palette.dart           # Paleta + colores reservados
├── features/
│   ├── accounts/
│   │   ├── domain/account_constants.dart
│   │   └── presentation/
│   │       ├── accounts_screen.dart
│   │       └── screens/account_form_screen.dart
│   ├── categories/
│   │   └── presentation/screens/category_form_screen.dart
│   ├── dashboard/
│   │   └── presentation/dashboard_screen.dart
│   ├── goals/
│   │   └── presentation/
│   │       ├── goals_screen.dart
│   │       └── screens/{goal_form_screen,goal_add_funds_screen}.dart
│   ├── notifications/
│   │   ├── providers/recharge_providers.dart
│   │   └── presentation/notifications_screen.dart
│   ├── profile/
│   │   └── presentation/screens/edit_name_screen.dart
│   ├── services/
│   │   └── presentation/screens/service_form_screen.dart
│   ├── transactions/
│   │   ├── domain/services/pdf_service.dart
│   │   └── presentation/
│   │       ├── transactions_list_screen.dart
│   │       └── screens/transaction_form_screen.dart
│   └── auth/
│       ├── providers/auth_providers.dart
│       └── presentation/pin_screen.dart
└── main.dart
android/app/src/main/
├── AndroidManifest.xml                    # allowBackup=false + dataExtractionRules
├── kotlin/.../MainActivity.kt             # extends FlutterFragmentActivity
└── res/xml/{backup_rules,data_extraction_rules}.xml
```

---

## Pendientes por hacer

Funcionalidades contempladas en el roadmap del MVP que **no se incluyeron** en esta v1.0:

- [ ] **Sincronización en la nube** (Firebase / Supabase) para respaldar y sincronizar entre dispositivos.
- [ ] **Presupuestos mensuales** por categoría con alertas al acercarse al límite.
- [ ] **Multi-moneda real**: conversión dinámica con tasas de cambio actualizadas (el campo `exchangeRate` existe pero no se utiliza).
- [ ] **Adjuntar comprobantes** (foto/PDF) a las transacciones (la tabla `Attachments` ya existe).
- [ ] **Etiquetas / tags** personalizadas y filtrado por tag (la tabla `Tags` ya existe).
- [ ] **Recordatorios push locales** configurables por servicio (actualmente sólo in-app).
- [ ] **Exportación a Excel / CSV** además de PDF.
- [ ] **Suite de tests**: unitarios para DAOs, *widget* tests para pantallas clave, integración para flujos críticos.
- [ ] **Internacionalización (i18n)** — la app está en español; falta inglés.
- [ ] **Modo oscuro** explícito configurable (ya se usan temas, falta el switch).
- [ ] **Widget de escritorio** con saldo rápido (Android / iOS).
- [ ] **Dashboard con más indicadores**: evolución del saldo en el tiempo, comparativa mes a mes, top gastos.
- [ ] **Aplicar PIN al abrir la app** (la integración con `local_auth` ya está; falta la pantalla de bloqueo al inicio).

---

## Mejoras futuras

Pensadas para una **v2** del producto:

- **IA para categorización automática** de transacciones a partir de la descripción.
- **Open Finance** — conexión con bancos vía APIs (Plaid, Belvo, etc.) para importar transacciones automáticamente.
- **Metas compartidas** — invitar a otra persona a contribuir a una misma meta.
- **Reglas de transacción** — "si descripción contiene X, asignar categoría Y y cuenta Z".
- **Análisis predictivo** — proyección de gastos del mes y alerta de posible sobregiro.
- **Gamificación** — rachas de ahorro, logros, *badges*.
- **Exportación programática** — API local (*intents* / *deep links*) para que otras apps lean datos.
- **Modo "compartido"** — cuentas familiares con varios usuarios y permisos.
- **Migración a Drift 3** / `drift_flutter` con *isolates* para escalar a >100k transacciones.
- **Tema personalizable** — el usuario puede elegir su color de acento.
- **Atajos de iOS / Android** (App Intents / App Actions) para registrar un gasto rápido desde fuera de la app.
- **Widget dinámico de saldo** en *home screen*.
- **Modo claro automático según hora del día** (sunrise / sunset).
- **Sincronización opcional entre dispositivos del mismo usuario** mediante QR / código de emparejamiento (sin servidor).
- **Soporte para más tipos de cuenta** — cripto, inversiones, deudas, préstamos.

---

## Créditos y licencia

Desarrollado por **Phamton140** · [github.com/Phamton140/Plusbalance](https://github.com/Phamton140/Plusbalance).

Licencia por definir. Por defecto, todos los derechos reservados al autor.
