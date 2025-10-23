import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

void main() {
  runApp(const NfcApp());
}

class NfcApp extends StatelessWidget {
  const NfcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control de Asistencia',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          bodyMedium: TextStyle(
            fontSize: 18,
            color: Colors.black54,
          ),
          labelLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      home: const NfcScreen(),
    );
  }
}

class NfcScreen extends StatefulWidget {
  const NfcScreen({super.key});

  @override
  State<NfcScreen> createState() => _NfcScreenState();
}

class _NfcScreenState extends State<NfcScreen> {
  String status = "Listo para registrar asistencia";
  bool isNfcAvailable = false;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _checkNfc();
  }

  Future<void> _checkNfc() async {
    isNfcAvailable = await NfcManager.instance.isAvailable();
    if (!mounted) return;

    setState(() {
      if (!isNfcAvailable) {
        status = "NFC no disponible. Actívalo en ajustes.";
      } else {
        status = "Listo para registrar asistencia";
      }
    });
  }

  Future<void> _readAndSendNfc(String endpoint, String action) async {
    if (!isNfcAvailable) {
      setState(() {
        status = "NFC no disponible. Actívalo en ajustes.";
      });
      return;
    }

    setState(() {
      status = "Leyendo tag NFC...";
      isProcessing = true;
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef != null) {
              final message = await ndef.read();
              if (message != null && message.records.isNotEmpty) {
                final record = message.records.first;
                final token = _extractTokenFromRecord(record);

                if (token.isNotEmpty && token.contains('.')) {
                  setState(() {
                    status = "Enviando $action...";
                  });
                  await _sendToApi(token, endpoint, action);
                } else {
                  setState(() {
                    status = "Token inválido o vacío";
                  });
                }
              } else {
                setState(() {
                  status = "No se encontraron registros NDEF";
                });
              }
            } else {
              setState(() {
                status = "Tag no compatible con NDEF";
              });
            }
          } catch (e) {
            setState(() {
              status = "Error al leer tag: $e";
            });
          } finally {
            await NfcManager.instance.stopSession();
            if (mounted) {
              setState(() {
                isProcessing = false;
              });
            }
          }
        },
      );
    } catch (e) {
      setState(() {
        status = "Error al iniciar NFC: $e";
        isProcessing = false;
      });
    }
  }

  String _extractTokenFromRecord(dynamic record) {
    try {
      final payload = record.payload;
      if (payload.length > 3) {
        final tokenBytes = payload.sublist(3);
        return String.fromCharCodes(tokenBytes);
      }
    } catch (e) {
      print("Error extrayendo token: $e");
    }
    return '';
  }

  Future<void> _sendToApi(String token, String endpoint, String action) async {
    try {
      // CAMBIA 'localhost' POR LA IP DE TU PC (ej: 192.168.1.100)
      final url = Uri.parse('http://localhost:8000/v1/attendance/$endpoint/');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'method': 'nfc',
          'token': token,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          status = "$action registrada: ${data[1]['employee_name']}";
        });
      } else {
        setState(() {
          status = "Error en API: ${response.statusCode} - ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        status = "Error de red: $e";
      });
    }
  }

  Future<void> _checkIn() async {
    await _readAndSendNfc('in', 'Entrada');
  }

  Future<void> _checkOut() async {
    await _readAndSendNfc('out', 'Salida');
  }

  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Control de Asistencia',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                status,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (isProcessing)
                const Column(
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Acerca el tag NFC a la parte trasera",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: isProcessing ? null : _checkIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Entrada',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  ElevatedButton(
                    onPressed: isProcessing ? null : _checkOut,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Salida',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}