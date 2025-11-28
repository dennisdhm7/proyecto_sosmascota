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

Future<DateTime?> fakeDatePicker(BuildContext context, DateTime initial) async {
  return DateTime(2024, 12, 25); // 🎯 FECHA SIMULADA
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
  VoidCallback? listenerCapturado;
  setUp(() {
    mockVM = MockAvistamientoVM();
    listenerCapturado = null; // Resetear siempre

    // COBERTURA MÁGICA 1:
    // Cuando la pantalla llame a 'addListener', nosotros robamos esa función
    // y la guardamos en 'listenerCapturado' para usarla después.
    when(mockVM.addListener(any)).thenAnswer((invocation) {
      listenerCapturado = invocation.positionalArguments.first as VoidCallback;
    });

    // ... (resto de tus configuraciones de mocks: avistamiento, cargando, etc.)
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
    Future<DateTime?> fakeDatePicker(
      BuildContext context,
      DateTime initialDate,
    ) async {
      return DateTime(2025, 1, 15);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: PantallaAvistamiento(
          viewModelTest: mockVM,
          pickerTest: picker,
          datePickerTest: fakeDatePicker, // ✔ ya existe
        ),
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
    testWidgets("Debe seleccionar fecha usando el datePicker", (tester) async {
      when(mockVM.avistamiento).thenReturn(Avistamiento());
      await tester.pumpWidget(
        buildTestApp(
          PantallaAvistamiento(
            viewModelTest: mockVM,
            datePickerTest: fakeDatePicker,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Hacer visible el campo
      final campoFecha = find.byKey(const Key("fieldFecha"));

      await tester.scrollUntilVisible(
        campoFecha,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      // Simular tap → abre el fake date picker
      await tester.tap(campoFecha);
      await tester.pumpAndSettle();

      // Validar que el controlador cambió
      final widgetFecha = tester.widget<TextFormField>(campoFecha);

      expect(widgetFecha.controller!.text, "25/12/2024");

      // Validar que se actualizó el VM
      expect(mockVM.avistamiento.fechaAvistamiento, equals("25/12/2024"));
    });

    // ✅ TEST PARA CUBRIR LA LÓGICA DEL LISTENER (SnackBar)
    testWidgets('Debe mostrar SnackBar cuando el VM reporta un error', (
      tester,
    ) async {
      await cargarPantalla(tester);

      // 1. Aseguramos que el listener fue capturado en el initState
      expect(
        listenerCapturado,
        isNotNull,
        reason: "El addListener no fue llamado",
      );

      // 2. SIMULAMOS CAMBIO DE ESTADO EN EL VM
      // Cambiamos lo que devuelve el Mock para simular el error
      when(mockVM.mensajeUsuario).thenReturn("Error de conexión");
      when(mockVM.estado).thenReturn(EstadoCarga.error);

      // 3. ¡DISPARAMOS EL EVENTO MANUALMENTE!
      // Esto es equivalente a que el VM haga notifyListeners()
      listenerCapturado!();

      // 4. Redibujamos la pantalla para que procese el cambio
      await tester.pump();

      // 5. Verificamos que el SnackBar apareció
      expect(find.text("Error de conexión"), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);

      // Verificamos que se llamó a limpiarMensaje
      verify(mockVM.limpiarMensaje()).called(1);
    });

    // ✅ TEST PARA CUBRIR NAVEGACIÓN (Pop)
    testWidgets('Debe cerrar la pantalla (pop) cuando el estado es Exito', (
      tester,
    ) async {
      await cargarPantalla(tester);

      // 1. Validamos captura
      expect(listenerCapturado, isNotNull);

      // 2. Simulamos Éxito
      when(mockVM.estado).thenReturn(EstadoCarga.exito);
      when(mockVM.mensajeUsuario).thenReturn("Guardado"); // Opcional

      // 3. Disparamos listener
      listenerCapturado!();

      // 4. Pump y Settle (para que termine la animación de cierre)
      await tester.pumpAndSettle();

      // 5. Verificamos que ya no estamos en la pantalla
      // (Buscamos un widget que sabíamos que estaba ahí, ahora no debería estar)
      expect(find.text('Registrar Avistamiento'), findsNothing);
    });
    testWidgets('Debe seleccionar imagen desde CÁMARA y llamar a subirFoto()', (
      tester,
    ) async {
      // 1. Preparamos la respuesta del Mock
      when(
        mockVM.subirFoto(any),
      ).thenAnswer((_) async => "https://foto_camara.jpg");

      // 2. Preparamos el Picker Falso
      final fakePicker = FakeImagePicker();
      fakePicker.fileToReturn = XFile("camara.jpg");

      // 3. Cargamos la pantalla
      await cargarPantalla(tester, picker: fakePicker);

      // 4. Buscamos el botón de CÁMARA (btnCamara)
      final btnCamara = find.byKey(const Key('btnCamara'));

      await tester.scrollUntilVisible(
        btnCamara,
        300,
        scrollable: mainScrollFinder,
      );

      // 5. Hacemos Tap
      await tester.tap(btnCamara);
      await tester.pumpAndSettle();

      // 6. Verificamos que se llamó a la lógica
      // Esto ejecuta la línea 173: _seleccionarImagen(ImageSource.camera, vm)
      verify(mockVM.subirFoto(any)).called(1);

      // (Opcional) Verificar que la foto se agregó a la lista visual
      final state =
          tester.state(
                find.byWidgetPredicate(
                  (w) => w.runtimeType.toString() == "_FormularioAvistamiento",
                ),
              )
              as dynamic;

      expect(state.imagenesSeleccionadas.length, 1);
    });
    testWidgets('Debe mostrar el texto del Distrito si el VM tiene el dato', (
      tester,
    ) async {
      // 1. Preparamos un Avistamiento con datos precargados
      final avistamientoConDatos = Avistamiento();
      avistamientoConDatos.distrito =
          'Miraflores'; // 👈 Dato clave para entrar al IF

      // 2. Forzamos al Mock a devolver este objeto en lugar del vacío
      when(mockVM.avistamiento).thenReturn(avistamientoConDatos);

      // 3. Cargamos la pantalla
      await cargarPantalla(tester);

      // 4. Verificamos que el IF se ejecutó y pintó el texto
      // Esto hará que las líneas 248-258 se pongan verdes
      expect(find.text('Distrito: Miraflores'), findsOneWidget);
    });
  });
}
