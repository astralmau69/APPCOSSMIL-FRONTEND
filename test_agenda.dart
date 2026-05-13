import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://api.cossmil.mil.bo';
  
  final creds = base64Encode(utf8.encode('frontendapp:12345'));
  final tokenRes = await http.post(
    Uri.parse('$baseUrl/api/security/oauth/token'),
    headers: {
      'Authorization': 'Basic $creds',
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: {
      'grant_type': 'client_credentials'
    }
  );
  
  final tokenData = jsonDecode(tokenRes.body);
  final token = tokenData['access_token'];
  
  final resId = await http.get(
    Uri.parse('$baseUrl/api/programacion/agenda-medico-movil/1/1/17'),
    headers: {
      'Authorization': 'Bearer $token',
    },
  );
  
  print('--- Test Agenda ---');
  print('HTTP ${resId.statusCode}');
  print('Response: ${resId.body}');
}
