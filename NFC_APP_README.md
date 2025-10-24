# Guía de Implementación NFC - Aplicación Móvil

Documentación técnica para desarrolladores que implementarán el sistema de marcaje por NFC en aplicaciones móviles usando **Flutter** o **Android nativo (Kotlin)**.

## Resumen del Sistema

La aplicación Android debe leer tokens JWT almacenados en chips **NTAG215** y enviarlos a la API para registrar entrada y salida de empleados. El sistema utiliza autenticación por tokens JWT firmados con clave secreta del servidor.

## Arquitectura de Datos

### Token NFC (NTAG215)
Cada empleado tiene un chip NTAG215 que contiene un **token JWT completo**:

```
eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbXBsb3llZV9pZCI6MiwidGFnX2lkIjoibmZjX3RhZ18xMjM0NSIsImV4cCI6MTczNTY4OTEyMCwiaWF0IjoxNzA0MTUzMTIwfQ.SIGNATURE_GENERADA_CON_SECRET_KEY
```

**Contenido decodificado del JWT:**
```json
{
  "employee_id": 2,
  "tag_id": "nfc_tag_12345", 
  "exp": 1735689120,
  "iat": 1704153120
}
```

### Características del Token
- **Formato**: JWT firmado con HMAC SHA-256
- **Tamaño máximo**: 504 bytes (compatible con NTAG215)
- **Validez**: 1 año desde la creación
- **Seguridad**: Firmado con SECRET_KEY del servidor (imposible de falsificar)

## Tabla de Contenidos
- [Integración con Flutter](#integración-con-flutter-recomendado)
- [Integración con Android Nativo (Kotlin)](#integración-con-android-nativo-kotlin)
- [Endpoints de la API](#endpoints-de-la-api)

---

## Integración con Flutter (Recomendado)

### 1. Dependencias Necesarias

Agregar al `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  nfc_manager: ^3.5.0      # Para lectura/escritura NFC
  http: ^1.2.0             # Para llamadas HTTP a la API
  provider: ^6.1.0         # (Opcional) Para manejo de estado
```

Instalar dependencias:
```bash
flutter pub get
```

### 2. Configuración de Permisos

#### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.NFC" />
    <uses-feature android:name="android.hardware.nfc" android:required="true" />
    <uses-permission android:name="android.permission.INTERNET" />

    <application>
        <!-- Configurar intent filter para NFC -->
        <activity android:name=".MainActivity">
            <intent-filter>
                <action android:name="android.nfc.action.NDEF_DISCOVERED"/>
                <category android:name="android.intent.category.DEFAULT"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>NFCReaderUsageDescription</key>
<string>Esta app necesita leer chips NFC para registrar asistencia</string>
<key>com.apple.developer.nfc.readersession.formats</key>
<array>
    <string>NDEF</string>
</array>
```

### 3. Implementación de Lectura NFC

#### Servicio NFC (`lib/services/nfc_service.dart`)
```dart
import 'package:nfc_manager/nfc_manager.dart';

class NFCService {
  /// Lee el token JWT del chip NFC
  Future<String?> readNFCToken() async {
    String? token;

    // Verificar disponibilidad de NFC
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      throw Exception('NFC no disponible en este dispositivo');
    }

    // Iniciar sesión NFC
    await NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          // Leer NDEF del tag
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            throw Exception('Chip NFC no contiene datos NDEF');
          }

          // Leer mensaje NDEF
          final ndefMessage = await ndef.read();
          if (ndefMessage.records.isEmpty) {
            throw Exception('Chip NFC vacío');
          }

          // Extraer el token JWT del primer record
          final record = ndefMessage.records.first;
          token = String.fromCharCodes(record.payload.skip(3)); // Skip 3 bytes de lenguaje

          // Detener sesión
          await NfcManager.instance.stopSession();
        } catch (e) {
          await NfcManager.instance.stopSession(errorMessage: 'Error al leer chip: $e');
          rethrow;
        }
      },
    );

    return token;
  }
}
```

### 4. Servicio de API (`lib/services/api_service.dart`)

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://tu-api.com/v1'; // Cambiar por tu URL

  /// Registrar entrada
  Future<Map<String, dynamic>> markIn(String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/attendance/in/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token}),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al registrar entrada');
    }
  }

  /// Registrar salida
  Future<Map<String, dynamic>> markOut(String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/attendance/out/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token}),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al registrar salida');
    }
  }

  /// Validar token (opcional)
  Future<Map<String, dynamic>> validateToken(String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/nfc/validate/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Token inválido');
    }
  }
}
```

### 5. Pantalla de Marcaje (`lib/screens/attendance_screen.dart`)

```dart
import 'package:flutter/material.dart';
import '../services/nfc_service.dart';
import '../services/api_service.dart';

class AttendanceScreen extends StatefulWidget {
  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final NFCService _nfcService = NFCService();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  String _statusMessage = 'Acerca tu chip NFC';

  Future<void> _handleCheckIn() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Leyendo chip NFC...';
    });

    try {
      // Leer token del chip
      String? token = await _nfcService.readNFCToken();

      if (token == null || token.isEmpty) {
        throw Exception('No se pudo leer el token del chip');
      }

      setState(() {
        _statusMessage = 'Registrando entrada...';
      });

      // Enviar a la API
      final response = await _apiService.markIn(token);

      setState(() {
        _isLoading = false;
        _statusMessage = response[0]['message'];
      });

      // Mostrar diálogo de éxito
      _showSuccessDialog(response[1]['employee_name'].toString());

    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
      });

      _showErrorDialog(e.toString());
    }
  }

  Future<void> _handleCheckOut() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Leyendo chip NFC...';
    });

    try {
      // Leer token del chip
      String? token = await _nfcService.readNFCToken();

      if (token == null || token.isEmpty) {
        throw Exception('No se pudo leer el token del chip');
      }

      setState(() {
        _statusMessage = 'Registrando salida...';
      });

      // Enviar a la API
      final response = await _apiService.markOut(token);

      setState(() {
        _isLoading = false;
        _statusMessage = response[0]['message'];
      });

      // Mostrar diálogo de éxito
      _showSuccessDialog(response[1]['employee_name'].toString());

    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
      });

      _showErrorDialog(e.toString());
    }
  }

  void _showSuccessDialog(String employeeName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Éxito'),
        content: Text('Registro completado para $employeeName'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registro de Asistencia'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.nfc,
              size: 100,
              color: _isLoading ? Colors.orange : Colors.blue,
            ),
            SizedBox(height: 20),
            Text(
              _statusMessage,
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            if (!_isLoading) ...[
              ElevatedButton.icon(
                onPressed: _handleCheckIn,
                icon: Icon(Icons.login),
                label: Text('Registrar Entrada'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _handleCheckOut,
                icon: Icon(Icons.logout),
                label: Text('Registrar Salida'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
              ),
            ] else
              CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
```

### 6. Estructura del Proyecto Flutter

```
lib/
├── main.dart
├── screens/
│   └── attendance_screen.dart
├── services/
│   ├── nfc_service.dart
│   └── api_service.dart
└── models/
    └── attendance_response.dart (opcional)
```

---

## Integración con Android Nativo (Kotlin)

### 1. Configuración de Permisos Android

Agregar al `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.NFC" />
<uses-feature android:name="android.hardware.nfc" android:required="true" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### 2. Lectura de NFC

La app debe usar las APIs nativas de Android (`NfcAdapter`, `Ndef`) para leer el token completo del chip NTAG215 sin procesarlo ni modificarlo.

---

## Endpoints de la API

Estos endpoints son los mismos tanto para Flutter como para Android nativo.

### Marcaje de Entrada
```
POST /v1/attendance/in/
Content-Type: application/json

{
  "method": "nfc",
  "token": "token_jwt_completo_leido_del_chip"
}
```

**Respuesta exitosa (201):**
```json
[
  {"message": "Entrada registrada exitosamente para juan"},
  {"employee_name": "Juan Médico"}
]
```

#### Marcaje de Salida
```
POST /v1/attendance/out/
Content-Type: application/json

{
  "method": "nfc",
  "token": "token_jwt_completo_leido_del_chip"
}
```

**Respuesta exitosa (201):**
```json
[
  {"message": "Salida registrada exitosamente para juan"},
  {"employee_name": "Juan Médico"}
]
```

### Errores Comunes
- `"Token NFC es requerido"` (400)
- `"Token NFC inválido o revocado"` (400)
- `"Empleado no encontrado"` (404)
- `"No hay registro de entrada pendiente"` (400) - Solo en salida

---

## Notas Importantes para Flutter

### Manejo de Estado de Sesión NFC
```dart
// La sesión NFC debe iniciarse CADA VEZ que se quiera leer
// No mantener sesiones abiertas permanentemente
await NfcManager.instance.startSession(...);
// Siempre cerrar la sesión después de leer
await NfcManager.instance.stopSession();
```

### Compatibilidad de Plataformas
- **Android**: NFC funciona en todos los dispositivos con hardware NFC (Android 5.0+)
- **iOS**: NFC solo funciona en iPhone 7 o posterior (iOS 13+)
- **Verificación recomendada**:
```dart
bool isAvailable = await NfcManager.instance.isAvailable();
if (!isAvailable) {
  // Mostrar mensaje al usuario
}
```

### Depuración y Testing
1. **Testing en dispositivos reales**: NFC no funciona en emuladores
2. **Formato NDEF**: Asegúrate de que el chip esté formateado como NDEF
3. **Logs útiles**:
```dart
print('Token leído: ${token.substring(0, 20)}...'); // No imprimas el token completo en producción
print('Longitud del token: ${token.length} caracteres');
```

### Manejo de Permisos
Flutter manejará automáticamente los permisos de NFC en Android si están correctamente configurados en el `AndroidManifest.xml`. No necesitas solicitar permisos en tiempo de ejecución para NFC.

---

## Implementación Sugerida (Android Nativo - Kotlin)

### Dependencias Necesarias
- Retrofit para llamadas HTTP
- Corrutinas de Kotlin para operaciones asíncronas
- APIs nativas de Android NFC (`NfcAdapter`, `Ndef`)

### Flujo General
1. **Configurar NFC** - Detectar tags y leer contenido
2. **Extraer token** - Obtener el JWT completo del chip
3. **Enviar a API** - POST al endpoint correspondiente (entrada/salida)
4. **Mostrar resultado** - Confirmación o mensaje de error

## Consideraciones de Seguridad

### Lo que SÍ maneja la app:
- ✅ Lectura del token JWT completo del chip NFC
- ✅ Envío del token sin modificaciones a la API
- ✅ Manejo de respuestas y errores de la API
- ✅ Validación de conectividad antes de enviar

### Lo que NO maneja la app:
- ❌ **No** intentes decodificar o validar el JWT localmente
- ❌ **No** manejes la SECRET_KEY (solo el servidor la conoce)
- ❌ **No** modifiques el contenido del token leído
- ❌ **No** almacenes tokens en la app (siempre lee del chip)

## Configuración de la App

### Manejo de NFC
- Configurar `NfcAdapter` para detectar tags NTAG215
- Implementar `onNewIntent()` para manejar eventos NFC
- Validar disponibilidad de hardware NFC

### Manejo de Errores
- Validar conectividad antes de enviar requests
- Mostrar mensajes de error apropiados al usuario
- Implementar retry logic para fallos de red

## Validación Opcional de Token

Si necesitas validar un token sin registrar asistencia:

#### Endpoint
```
POST /v1/auth/nfc/validate/
Content-Type: application/json
```

#### Request
```json
{
  "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
}
```

#### Response (Éxito)
```json
{
  "employee_id": 2,
  "tag_id": "nfc_tag_12345",
  "exp": 1735689120,
  "iat": 1704153120
}
```

## Notas Técnicas

### Compatibilidad NFC
- **Chip requerido**: NTAG215 (504 bytes disponibles)
- **Protocolo**: ISO 14443 Type A
- **Frecuencia**: 13.56 MHz

### Consideraciones de Rendimiento
- **Cache de conectividad**: Verificar conexión antes de intentar marcaje
- **Retry logic**: Reintentar automáticamente en caso de falla de red
- **Feedback visual**: Mostrar estado de lectura NFC y envío a API

### Testing
- Probar con tokens válidos e inválidos
- Simular errores de red y NFC
- Validar comportamiento con chips vacíos o corruptos
- Verificar manejo correcto de respuestas de la API

## Flujo Visual Sugerido

```
1. [Pantalla Inicial] 
   → "Acerca tu chip NFC"

2. [Leyendo NFC]
   → Spinner + "Leyendo chip..."

3. [Enviando a API]
   → Spinner + "Registrando asistencia..."

4. [Resultado]
   → ✅ "Entrada registrada - Juan Médico"
   → ❌ "Error: Token inválido"
```

Esta guía cubre todo lo necesario para implementar la funcionalidad NFC en tu aplicación móvil de forma segura y eficiente.