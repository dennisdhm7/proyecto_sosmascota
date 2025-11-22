import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:sos_mascotas/servicios/api_dni_servicio.dart';

void main() {
  const bearer = 'token123';

  test(
    'consultarDni returns datos map when API responds 200 and success=true',
    () async {
      final mockClient = MockClient((http.Request req) async {
        expect(req.url.toString(), 'https://miapi.cloud/v1/dni/12345678');
        expect(req.headers['Authorization'], 'Bearer $bearer');
        expect(req.headers['Content-Type'], 'application/json');

        final responseBody = jsonEncode({
          'success': true,
          'datos': {'nombre': 'Juan', 'dni': '12345678'},
        });
        return http.Response(
          responseBody,
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final svc = ApiDniServicio(bearerToken: bearer, client: mockClient);
      final result = await svc.consultarDni('12345678');

      expect(result, isNotNull);
      expect(result!['nombre'], 'Juan');
      expect(result['dni'], '12345678');
    },
  );

  test('consultarDni returns null when status is not 200', () async {
    final mockClient = MockClient((_) async => http.Response('Not Found', 404));

    final svc = ApiDniServicio(bearerToken: bearer, client: mockClient);
    final result = await svc.consultarDni('87654321');

    expect(result, isNull);
  });

  test(
    'consultarDni returns null when success is false or datos missing',
    () async {
      final mockClient = MockClient((_) async {
        final body = jsonEncode({'success': false});
        return http.Response(
          body,
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final svc = ApiDniServicio(bearerToken: bearer, client: mockClient);
      final result = await svc.consultarDni('00000000');

      expect(result, isNull);
    },
  );
}
