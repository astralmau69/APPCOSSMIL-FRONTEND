import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://api.cossmil.mil.bo';
  
  // 1. Get Token
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
  
  // 2. Query medsuc-buscar with ID
  final bodyId = {
    'idins': 1,
    'idsuc': 1,
    'idesp': 25,
    'esp': '',
  };
  
  final resId = await http.post(
    Uri.parse('$baseUrl/api/programacion/medsuc-buscar'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(bodyId),
  );
  
  print('--- Test {idesp: 25} ---');
  print('HTTP ${resId.statusCode}');
  final jsonDataId = jsonDecode(resId.body);
  print('Data Length: ${(jsonDataId['data'] as List).length}');
  
  // 3. Query medsuc-buscar with Name
  final bodyName = {
    'idins': 1,
    'idsuc': 1,
    'idesp': 0,
    'esp': 'CARDIOLOGIA',
  };
  
  final resName = await http.post(
    Uri.parse('$baseUrl/api/programacion/medsuc-buscar'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(bodyName),
  );
  
  print('--- Test {esp: CARDIOLOGIA} ---');
  print('HTTP ${resName.statusCode}');
  final jsonDataName = jsonDecode(resName.body);
  print('Data Length: ${(jsonDataName['data'] as List).length}');
  
  if ((jsonDataName['data'] as List).isNotEmpty) {
     print('Sample returned: ${jsonDataName['data'][0]['medico']}');
  }
}
