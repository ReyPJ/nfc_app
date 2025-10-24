import 'package:flutter/material.dart';
import '../services/nfc_service.dart';
import '../services/api_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final NFCService _nfcService = NFCService();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  String _statusMessage = 'Selecciona una opción para comenzar';

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
      if (mounted) {
        _showSuccessDialog(response[1]['employee_name'].toString());
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
      });

      if (mounted) {
        _showErrorDialog(e.toString());
      }
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
      if (mounted) {
        _showSuccessDialog(response[1]['employee_name'].toString());
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
      });

      if (mounted) {
        _showErrorDialog(e.toString());
      }
    }
  }

  void _showSuccessDialog(String employeeName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Éxito'),
        content: Text('Registro completado para $employeeName'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Asistencia'),
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
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (!_isLoading) ...[
              ElevatedButton.icon(
                onPressed: _handleCheckIn,
                icon: const Icon(Icons.login),
                label: const Text('Registrar Entrada'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _handleCheckOut,
                icon: const Icon(Icons.logout),
                label: const Text('Registrar Salida'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
              ),
            ] else
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
