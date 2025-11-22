import 'package:flutter_test/flutter_test.dart';
import 'package:sos_mascotas/modelo/reporte_mascota.dart';

void main() {
  group('ReporteMascota.fromMap', () {
    test('uses direccion when provided', () {
      final map = {'id': 'abc', 'nombre': 'Fido', 'direccion': 'Calle 123'};

      final reporte = ReporteMascota.fromMap(map);

      expect(reporte.direccion, 'Calle 123');
      expect(reporte.id, 'abc');
      expect(reporte.nombre, 'Fido');
    });

    test('defaults direccion to empty string when missing', () {
      final map = {'id': 'no-direction'};

      final reporte = ReporteMascota.fromMap(map);

      expect(reporte.direccion, '');
      expect(reporte.id, 'no-direction');
    });

    test('defaults direccion to empty string when null', () {
      final map = {'direccion': null};

      final reporte = ReporteMascota.fromMap(map);

      expect(reporte.direccion, '');
    });
  });
}
