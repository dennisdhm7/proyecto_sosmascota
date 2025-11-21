import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiDniServicio {
  final String baseUrl = "https://miapi.cloud/v1/dni";
  final String bearerToken;
  final http.Client client; // 👈 INYECTADO

  ApiDniServicio({required this.bearerToken, http.Client? client})
    : client = client ?? http.Client(); // por defecto usa http real

  Future<Map<String, dynamic>?> consultarDni(String dni) async {
    final uri = Uri.parse("$baseUrl/$dni");
    try {
      final resp = await client.get(
        uri,
        headers: {
          "Authorization": "Bearer $bearerToken",
          "Content-Type": "application/json",
        },
      );

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        if (body["success"] == true && body["datos"] != null) {
          return Map<String, dynamic>.from(body["datos"]);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
