import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://web-production-2e20e.up.railway.app/v1';

  /// Registrar entrada
  Future<List<dynamic>> markIn(String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/attendance/in/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'method': 'nfc', 'token': token}),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al registrar entrada');
    }
  }

  /// Registrar salida
  Future<List<dynamic>> markOut(String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/attendance/out/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'method': 'nfc', 'token': token}),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as List<dynamic>;
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
