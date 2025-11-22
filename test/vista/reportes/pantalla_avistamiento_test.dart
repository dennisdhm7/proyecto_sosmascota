import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sos_mascotas/modelo/avistamiento.dart';
import 'package:sos_mascotas/vista/reportes/pantalla_avistamiento.dart';
import 'package:sos_mascotas/vistamodelo/reportes/avistamiento_vm.dart';

@GenerateMocks([AvistamientoVM])
import 'pantalla_avistamiento_test.mocks.dart';

void main() {
  late MockAvistamientoVM mockVM;

  setUp(() {
    mockVM = MockAvistamientoVM();
    when(mockVM.avistamiento).thenReturn(Avistamiento());
    when(mockVM.cargando).thenReturn(false);
    when(mockVM.estado).thenReturn(EstadoCarga.inicial);
    when(mockVM.mensajeUsuario).thenReturn(null);
    when(mockVM.setDescripcion(any)).thenReturn(null);
    when(mockVM.limpiarMensaje()).thenReturn(null);
  });

  Future<void> cargarPantalla(WidgetTester tester) async {
    // Pantalla gigante (1080px de ancho lógico) para que todo quepa sin overflow
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: PantallaAvistamiento(viewModelTest: mockVM)),
    );
  }

  // CORRECCIÓN FINAL: Agregamos .first
  // Esto selecciona el Scrollable más externo (el de la página) y descarta los internos de los inputs.
  final mainScrollFinder = find
      .descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      )
      .first;

  group('Pruebas de Integración - PantallaAvistamiento', () {
    testWidgets('Debe renderizar correctamente todos los elementos iniciales', (
      tester,
    ) async {
      await cargarPantalla(tester);

      expect(find.text('Registrar Avistamiento'), findsOneWidget);
      expect(find.byKey(const Key('btnCamara')), findsOneWidget);

      final btnGuardar = find.byKey(const Key('btnGuardar'));

      // Usamos el finder corregido
      await tester.scrollUntilVisible(
        btnGuardar,
        500.0,
        scrollable: mainScrollFinder,
      );

      expect(find.byKey(const Key('fieldDireccion')), findsOneWidget);
      expect(btnGuardar, findsOneWidget);
    });

    testWidgets(
      'Debe mostrar errores de validación si se intenta guardar vacío',
      (tester) async {
        await cargarPantalla(tester);

        final btnGuardar = find.byKey(const Key('btnGuardar'));

        // 1. Scroll hacia abajo
        await tester.scrollUntilVisible(
          btnGuardar,
          500,
          scrollable: mainScrollFinder,
        );
        await tester.pumpAndSettle();

        // 2. Tap en Guardar
        await tester.tap(btnGuardar);
        await tester.pumpAndSettle();

        verifyNever(mockVM.guardarAvistamiento());

        // 3. Scroll hacia ARRIBA para ver el error superior
        final errorUbicacion = find.text('Seleccione una ubicación');
        await tester.scrollUntilVisible(
          errorUbicacion,
          -500, // Negativo sube
          scrollable: mainScrollFinder,
        );

        expect(errorUbicacion, findsOneWidget);
        expect(find.text('Seleccione fecha'), findsOneWidget);
        expect(find.text('Ingrese una descripción'), findsOneWidget);
      },
    );

    testWidgets('Debe llamar al VM cuando se escribe una descripción', (
      tester,
    ) async {
      await cargarPantalla(tester);

      final campoDescripcion = find.byKey(const Key('fieldDescripcion'));

      await tester.scrollUntilVisible(
        campoDescripcion,
        500,
        scrollable: mainScrollFinder,
      );
      await tester.pumpAndSettle();

      await tester.enterText(campoDescripcion, 'Perro encontrado');
      await tester.pump();

      verify(mockVM.setDescripcion('Perro encontrado')).called(1);
    });

    testWidgets('Debe intentar guardar si el formulario es válido (simulado)', (
      tester,
    ) async {
      await cargarPantalla(tester);
      final btnGuardar = find.byKey(const Key('btnGuardar'));

      await tester.scrollUntilVisible(
        btnGuardar,
        500,
        scrollable: mainScrollFinder,
      );
      await tester.pumpAndSettle();

      await tester.tap(btnGuardar);
      await tester.pump();

      expect(find.text('Ingrese una descripción'), findsOneWidget);
    });
  });
}
