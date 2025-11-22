import 'package:flutter_test/flutter_test.dart';
import 'package:sos_mascotas/vistamodelo/reportes/avistamiento_vm.dart';

void main() {
  group('AvistamientoVM - Pruebas de Lógica y Validación', () {
    late AvistamientoVM vm;

    setUp(() {
      vm = AvistamientoVM();
    });

    test('actualizarUbicacion notifica a los listeners correctamente', () {
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

      // Verificar que se actualizaron los datos
      expect(vm.avistamiento.direccion, 'Calle Test');
      expect(vm.avistamiento.latitud, -10.0);
      expect(notifyCount, 1);
    });

    test(
      'guardarAvistamiento falla si la descripción está vacía o son solo espacios',
      () async {
        // 1. Configurar datos inválidos (Descripción vacía)
        vm.avistamiento.descripcion = '   ';
        vm.avistamiento.foto = 'http://example.com/f.jpg';
        vm.avistamiento.latitud = -12.0;
        vm.avistamiento.longitud = -77.0;

        // 2. Ejecutar acción
        final resultado = await vm.guardarAvistamiento();

        // 3. Verificar resultado
        expect(resultado, false, reason: 'Debería retornar false');
        expect(
          vm.estado,
          EstadoCarga.error,
          reason: 'El estado debería ser error',
        );

        // Nota: Asegúrate que este texto coincida EXACTAMENTE con el de tu VM
        expect(vm.mensajeUsuario, 'La descripción no puede estar vacía.');
      },
    );

    test('guardarAvistamiento falla si no hay foto', () async {
      // 1. Configurar datos inválidos (Sin foto)
      vm.avistamiento.descripcion = 'Mascota vista';
      vm.avistamiento.foto = ''; // Vacío
      vm.avistamiento.latitud = -12.0;
      vm.avistamiento.longitud = -77.0;

      // 2. Ejecutar acción
      final resultado = await vm.guardarAvistamiento();

      // 3. Verificar resultado
      expect(resultado, false);
      expect(vm.estado, EstadoCarga.error);

      // Nota: Verifica el texto exacto en tu avistamiento_vm.dart
      expect(vm.mensajeUsuario, 'Debes subir una foto antes de guardar.');
    });

    test(
      'guardarAvistamiento falla si la ubicación es inválida (0,0)',
      () async {
        // 1. Configurar datos inválidos (Ubicación 0,0)
        vm.avistamiento.descripcion = 'Mascota vista';
        vm.avistamiento.foto = 'http://foto.com';
        vm.avistamiento.latitud = 0;
        vm.avistamiento.longitud = 0;

        // 2. Ejecutar acción
        final resultado = await vm.guardarAvistamiento();

        // 3. Verificar resultado
        expect(resultado, false);
        expect(vm.estado, EstadoCarga.error);
        expect(
          vm.mensajeUsuario,
          'Debe seleccionar una ubicación válida en el mapa.',
        );
      },
    );
  });
}
