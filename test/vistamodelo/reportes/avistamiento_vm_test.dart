import 'package:flutter_test/flutter_test.dart';
import 'package:sos_mascotas/vistamodelo/reportes/avistamiento_vm.dart';

void main() {
  group('AvistamientoVM - additional tests', () {
    late AvistamientoVM vm;

    setUp(() {
      vm = AvistamientoVM();
    });

    test('actualizarUbicacion notifies listeners once', () {
      var notifyCount = 0;
      vm.addListener(() {
        notifyCount++;
      });

      vm.actualizarUbicacion(
        direccion: 'Calle Test',
        distrito: 'Distrito Test',
        latitud: -10.0,
        longitud: -70.0,
      );

      expect(notifyCount, 1);
    });

    test('validarCampos treats description with only spaces as empty', () {
      vm.avistamiento.descripcion = '   ';
      vm.avistamiento.foto = 'http://example.com/f.jpg';
      vm.avistamiento.latitud = -12.0;
      vm.avistamiento.longitud = -77.0;

      final res = vm.validarCampos();
      expect(res, 'La descripción no puede estar vacía');
    });

    test('validarCampos treats photo with only spaces as missing', () {
      vm.avistamiento.descripcion = 'Mascota vista';
      vm.avistamiento.foto = '   ';
      vm.avistamiento.latitud = -12.0;
      vm.avistamiento.longitud = -77.0;

      final res = vm.validarCampos();
      expect(res, 'Debe adjuntar una foto del avistamiento');
    });
  });
}
