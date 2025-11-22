import 'package:flutter_test/flutter_test.dart';
import 'package:sos_mascotas/modelo/avistamiento.dart';

void main() {
  group('Avistamiento usuarioId mapping', () {
    test('toMap includes usuarioId value', () {
      final a = Avistamiento(usuarioId: 'user123');
      final m = a.toMap();
      expect(m.containsKey('usuarioId'), isTrue);
      expect(m['usuarioId'], equals('user123'));
    });

    test('fromMap sets usuarioId when present', () {
      final map = {
        'id': '1',
        'usuarioId': 'u456',
        'foto': '',
        'direccion': '',
        'distrito': '',
        'fechaAvistamiento': '',
        'horaAvistamiento': '',
        'descripcion': '',
      };
      final a = Avistamiento.fromMap(map);
      expect(a.usuarioId, equals('u456'));
    });

    test('fromMap defaults usuarioId to empty string when missing', () {
      final map = {
        'id': '2',
        'foto': '',
        'direccion': '',
        'distrito': '',
        'fechaAvistamiento': '',
        'horaAvistamiento': '',
        'descripcion': '',
      };
      final a = Avistamiento.fromMap(map);
      expect(a.usuarioId, equals(''));
    });

    test('roundtrip preserves usuarioId', () {
      final original = Avistamiento(
        id: '10',
        usuarioId: 'roundtrip_user',
        latitud: 12.34,
        longitud: 56.78,
        fechaAvistamiento: '2025-01-01',
        horaAvistamiento: '12:00',
      );
      final map = original.toMap();
      final restored = Avistamiento.fromMap(map);
      expect(restored.usuarioId, equals(original.usuarioId));
      expect(restored.latitud, equals(original.latitud));
      expect(restored.longitud, equals(original.longitud));
    });
  });
}
