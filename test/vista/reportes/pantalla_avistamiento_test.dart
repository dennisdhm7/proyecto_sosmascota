import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sos_mascotas/modelo/avistamiento.dart';
import 'package:sos_mascotas/vista/reportes/pantalla_avistamiento.dart';
import 'package:sos_mascotas/vistamodelo/reportes/avistamiento_vm.dart';

@GenerateMocks([AvistamientoVM])
import 'pantalla_avistamiento_test.mocks.dart';

// ⭐ FakeImagePicker para tests
class FakeImagePicker extends Fake implements ImagePicker {
  XFile? fileToReturn;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    return fileToReturn;
  }
}

// ⭐ PantallaMapaOSM falsa → devuelve datos automáticamente
class FakePantallaMapaOSM extends StatelessWidget {
  const FakePantallaMapaOSM({super.key});

  @override
  Widget build(BuildContext context) {
    Future.microtask(() {
      Navigator.pop(context, {
        "direccion": "Av. Patricio Melendez 123",
        "distrito": "Tacna",
        "lat": -18.006,
        "lng": -70.246,
      });
    });

    return const SizedBox.shrink();
  }
}

// ⭐ Contenedor especial para interceptar Navigator.push
Widget buildTestApp(Widget child) {
  return MaterialApp(
    home: child,
    onGenerateRoute: (settings) {
      if (settings.name == "/mapaFake") {
        return MaterialPageRoute(builder: (_) => const FakePantallaMapaOSM());
      }
      return null;
    },
  );
}

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

  Future<void> cargarPantalla(
    WidgetTester tester, {
    ImagePicker? picker,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: PantallaAvistamiento(viewModelTest: mockVM, pickerTest: picker),
      ),
    );

    await tester.pumpAndSettle();
  }

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

      await tester.scrollUntilVisible(
        btnGuardar,
        500.0,
        scrollable: mainScrollFinder,
      );

      expect(find.byKey(const Key('fieldDireccion')), findsOneWidget);
      expect(btnGuardar, findsOneWidget);
    });

    testWidgets('Debe mostrar errores de validación al guardar vacío', (
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
      await tester.pumpAndSettle();

      verifyNever(mockVM.guardarAvistamiento());

      expect(find.text('Seleccione una ubicación'), findsOneWidget);
      expect(find.text('Seleccione fecha'), findsOneWidget);
      expect(find.text('Ingrese una descripción'), findsOneWidget);
    });

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

    testWidgets('Debe seleccionar imagen y llamar a subirFoto()', (
      tester,
    ) async {
      when(
        mockVM.subirFoto(any),
      ).thenAnswer((_) async => "https://foto_subida.jpg");

      final fakePicker = FakeImagePicker();
      fakePicker.fileToReturn = XFile("fake.jpg");

      await cargarPantalla(tester, picker: fakePicker);

      final btnGaleria = find.byKey(const Key('btnGaleria'));

      await tester.scrollUntilVisible(
        btnGaleria,
        300,
        scrollable: mainScrollFinder,
      );

      await tester.tap(btnGaleria);
      await tester.pumpAndSettle();

      verify(mockVM.subirFoto(any)).called(1);

      final state =
          tester.state(
                find.byWidgetPredicate(
                  (w) => w.runtimeType.toString() == "_FormularioAvistamiento",
                ),
              )
              as dynamic;

      expect(state.imagenesSeleccionadas.length, 1);
      expect(mockVM.avistamiento.foto, "https://foto_subida.jpg");
    });

    // ⭐ TEST FINAL: Cubre Navigator + actualizarUbicacion + asignación al campo
    testWidgets('Debe actualizar ubicación después de regresar del mapa', (
      tester,
    ) async {
      when(
        mockVM.actualizarUbicacion(
          direccion: anyNamed("direccion"),
          distrito: anyNamed("distrito"),
          latitud: anyNamed("latitud"),
          longitud: anyNamed("longitud"),
        ),
      ).thenReturn(null);

      await tester.pumpWidget(
        buildTestApp(
          PantallaAvistamiento(
            viewModelTest: mockVM,
            mapaTest: const FakePantallaMapaOSM(), // ✔ SE INYECTA AQUÍ
          ),
        ),
      );

      await tester.pumpAndSettle();

      final btnMapa = find.byKey(const Key('btnMapa'));

      await tester.scrollUntilVisible(
        btnMapa,
        500,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      // ✔ SOLO hacemos tap — NO navegamos manualmente
      await tester.tap(btnMapa);
      await tester.pumpAndSettle();

      // ✔ Se verifica la llamada correcta
      verify(
        mockVM.actualizarUbicacion(
          direccion: "Av. Patricio Melendez 123",
          distrito: "Tacna",
          latitud: -18.006,
          longitud: -70.246,
        ),
      ).called(1);

      // ✔ Se verifica que se actualizó el campo
      final txtDireccion = find.byKey(const Key('fieldDireccion'));

      expect(
        (tester.widget(txtDireccion) as TextFormField).controller!.text,
        equals("Av. Patricio Melendez 123"),
      );
    });
  });
}
