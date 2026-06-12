# +Balance

## Tu dinero, bajo control. Sin internet, sin complicaciones.

**+Balance** es la aplicación de finanzas personales que te da claridad total sobre tu dinero. Registra gastos, ingresos y transferencias en segundos. Visualiza dónde va tu dinero. Alcanza tus metas de ahorro. Todo sin necesidad de conexión a internet y con la seguridad de un PIN de 6 dígitos.

---

## ¿Por qué +Balance?

Sabemos que controlar tus finanzas no debería ser complicado. Por eso creamos una app que:

- **Funciona 100% offline** - Tu información está en tu dispositivo, siempre disponible
- **Es increíblemente rápida** - Registra un gasto en menos de 5 segundos
- **Te muestra el panorama completo** - Dashboard con tu patrimonio, gráficos y alertas
- **Protege tu privacidad** - PIN de seguridad y almacenamiento cifrado
- **Se adapta a ti** - Personaliza categorías, cuentas y metas

---

## Características principales

### Control total de tus cuentas
Maneja múltiples cuentas (efectivo, débito, crédito, billeteras virtuales) con saldos actualizados en tiempo real. La app mantiene un registro preciso de cada movimiento.

### Categorías que hacen sentido
10 categorías predefinidas (Hogar, Alimentos, Salud, Transporte, etc.) con la opción de crear las tuyas propias. Cada una con su ícono y color para identificarlas al instante.

### Transacciones en un toque
- **Gastos e ingresos** con monto, categoría y descripción opcional
- **Transferencias** entre tus cuentas o hacia terceros
- **Historial completo** agrupado por día, con filtros por tipo y categoría
- **Exportación a PDF** tipo estado de cuenta para compartir o respaldar

### Metas de ahorro que sí funcionan
Sistema de alcancía centralizada: envía dinero a tu alcancía y todas tus metas muestran el progreso simultáneamente. Cuando tengas suficiente, completa la meta con un solo toque.

### Servicios recurrentes automatizados
Registra suscripciones, pagos mensuales y servicios recurrentes. La app te notifica cuando se acercan las fechas y puedes aplicar el pago con confirmación en un toque.

### Recargas de cuenta programadas
¿Recibes salario o mesada? Programa recargas automáticas (semanales, quincenales o mensuales) y la app te avisa cuando es momento de registrar el ingreso.

### Dashboard inteligente
- **Saldo total** de todas tus cuentas
- **Gráfico de pastel** mostrando distribución de gastos por categoría
- **Accesos rápidos** a todas las secciones
- **Notificaciones** de servicios por vencer y metas por completar

### Seguridad sin compromisos
- **PIN de 6 dígitos** almacenado con cifrado del sistema operativo
- **Desbloqueo biométrico** opcional (huella digital / Face ID)
- **100% offline** - Tu información nunca sale de tu dispositivo

---

## Diseño pensado para ti

### Interfaz moderna y minimalista
Diseñada con Material Design 3, tipografía limpia y animaciones sutiles. Modo claro y oscuro automático según la configuración de tu dispositivo.

### Tarjetas de cuenta estilo crédito
Cada cuenta tiene su propia tarjeta con diseño único, mostrando institución, saldo y características especiales.

### Experiencia fluida
Navegación intuitiva, sin menús complicados. Todo está a máximo 2 toques de distancia.

---

## Instalación

### Para usuarios

**Android:**
```bash
flutter build apk --release
```
El archivo APK se generará en `build/app/outputs/flutter-apk/app-release.apk`

**iOS:**
```bash
flutter build ios --release
```
Abre el proyecto en Xcode para distribuir a TestFlight o App Store.

### Para desarrolladores

```bash
# Clonar repositorio
git clone https://github.com/Phamton140/Plusbalance.git
cd Plusbalance

# Instalar dependencias
flutter pub get

# Generar código de base de datos
flutter pub run build_runner build

# Ejecutar en modo desarrollo
flutter run
```

**Requisitos:**
- Flutter SDK 3.11.0 o superior
- Dart 3.x
- Android Studio / Xcode (para emuladores)

---

## Tecnologías

Construida con tecnologías modernas y probadas:

- **Flutter** - Framework multiplataforma de Google
- **Riverpod** - Gestión de estado reactiva
- **Drift** - Base de datos SQLite con tipos seguros
- **GoRouter** - Navegación declarativa
- **fl_chart** - Gráficos interactivos
- **flutter_secure_storage** - Almacenamiento cifrado
- **local_auth** - Autenticación biométrica
- **pdf** - Generación de reportes

---

## Roadmap

Próximamente en +Balance:

- [ ] Sincronización en la nube (respaldo y multi-dispositivo)
- [ ] Presupuestos mensuales por categoría
- [ ] Multi-moneda con tasas de cambio en tiempo real
- [ ] Adjuntar comprobantes a transacciones
- [ ] Etiquetas personalizadas
- [ ] Recordatorios push configurables
- [ ] Exportación a Excel/CSV
- [ ] Widget de saldo para pantalla de inicio
- [ ] Análisis predictivo de gastos
- [ ] Metas de ahorro compartidas

---

## Capturas de pantalla

*[Próximamente: capturas de pantalla del dashboard, registro de transacciones, metas de ahorro y más]*

---

## Contribuciones

+Balance es un proyecto abierto a mejoras y sugerencias. Si tienes ideas para nuevas funcionalidades o encuentras algún problema, no dudes en abrir un issue o enviar un pull request.

---

## Licencia

© 2024 Phamton140. Todos los derechos reservados.

---

## Contacto

**Desarrollador:** Phamton140  
**GitHub:** [github.com/Phamton140/Plusbalance](https://github.com/Phamton140/Plusbalance)

---

<div align="center">

**+Balance** - Suma equilibrio a tus finanzas

*Registra • Visualiza • Planifica*

</div>
