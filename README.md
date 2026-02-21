# Aurora - App de Toma de Lecturas

Aplicación móvil desarrollada en Flutter para la toma de lecturas de medidores de agua, diseñada para funcionar offline-first.

## 🚀 Requisitos Previos

- **Flutter SDK**: `^3.5.0`
- **Java**: JDK 17 (requerido para compilación Android)
- **Xcode**: Verisón más reciente (requerido para iOS)
- **CocoaPods**: Requerido para dependencias de iOS

## ⚙️ Configuración del Entorno

La aplicación utiliza archivos JSON para manejar variables de entorno. Estos archivos están ignorados en el repositorio (ver `.gitignore`).

### 1. Archivos de Entorno
Crea un archivo por cada entorno en la carpeta `env/`. Puedes usar `env/example.json` como base:

- `env/local.json`
- `env/dev.json`
- `env/prod.json`

**Estructura del archivo JSON:**
```json
{
  "API_BASE_URL": "https://tu-api.com/api/mobile",
  "MAP_API_KEY": "",
  "NOTIFICATION_INTERVAL": "120",
  "DEBUG": "true"
}
```

### 2. Instalación de Dependencias
Ejecuta los siguientes comandos en la raíz del proyecto:

```bash
flutter pub get
```

Para iOS:
```bash
cd ios
pod install
cd ..
```

---

## 📱 Configuración por Plataforma

### Android
- **Permisos**: Asegúrate de que `ACCESS_FINE_LOCATION` y `ACCESS_COARSE_LOCATION` estén habilitados en el `AndroidManifest.xml` (ya configurados).
- **Firmado**: Para generar un release, crea el archivo `android/key.properties` con las credenciales de tu almacén de claves (keystore).

### iOS
- **Permisos**: Los permisos de ubicación están definidos en `ios/Runner/Info.plist` bajo las llaves `NSLocationWhenInUseUsageDescription` y `NSLocationAlwaysUsageDescription`.
- **Arquitectura**: Para simuladores en Mac M1/M2, asegúrate de que CocoaPods esté configurado correctamente para excluir arquitecturas no soportadas si es necesario.

---

## 🏃 Ejecución y Build

Para ejecutar la aplicación con una configuración específica, usa el flag `--dart-define-from-file`:

### Modo Debug (Local)
```bash
flutter run --dart-define-from-file=env/local.json
```

### Modo Release (Android)
```bash
flutter build apk --release --dart-define-from-file=env/prod.json
```

### Modo Release (iOS)
```bash
flutter build ipa --release --dart-define-from-file=env/prod.json
```

---

## 🛠️ Tecnologías Utilizadas

- **Framework**: Flutter
- **Estado**: Flutter Riverpod
- **Navegación**: GoRouter
- **Base de Datos Local**: SQLite (sqflite)
- **Mapas**: flutter_map (OpenStreetMap)
- **Red**: Dio
