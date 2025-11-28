import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:sos_mascotas/vista/reportes/pantalla_reporte_mascota.dart';
import 'package:sos_mascotas/vistamodelo/reportes/reporte_vm.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'pantalla_reporte_mascota_test.mocks.dart';

class FakeVideoPickerPlatform extends ImagePickerPlatform {
  String? videoPathToReturn;

  @override
  Future<PickedFile?> pickVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async {
    if (videoPathToReturn != null) {
      return PickedFile(videoPathToReturn!);
    }
    return null;
  }
}

typedef CollectionReferenceMap = CollectionReference<Map<String, dynamic>>;
typedef DocumentReferenceMap = DocumentReference<Map<String, dynamic>>;

@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  FirebaseStorage,
  User,
  ReporteServiciosExternos,
  CollectionReferenceMap,
  DocumentReferenceMap,
])
void main() {
  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
  });

  late ReporteMascotaVM viewModel;
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseStorage mockStorage;
  late MockReporteServiciosExternos mockServicios;
  late MockUser mockUser;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockStorage = MockFirebaseStorage();
    mockServicios = MockReporteServiciosExternos();
    mockUser = MockUser();

    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn("user_123");

    viewModel = ReporteMascotaVM(
      auth: mockAuth,
      firestore: mockFirestore,
      storage: mockStorage,
      servicios: mockServicios,
    );
  });

  Future<void> cargarPantalla(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<ReporteMascotaVM>.value(
          value: viewModel,
          child: const WizardReporte(),
        ),
      ),
    );
  }
  // ---------------------------------------------------------------------------
  // PASO 1
  // ---------------------------------------------------------------------------

  testWidgets('🟢 Debe iniciar en el Paso 1 y mostrar campos', (
    WidgetTester tester,
  ) async {
    await cargarPantalla(tester);
    expect(find.text('Reportar Mascota Perdida'), findsOneWidget);
    expect(find.text('Paso 1 de 3'), findsOneWidget);
  });

  testWidgets('🔴 No debe avanzar si no hay foto (Muestra SnackBar)', (
    WidgetTester tester,
  ) async {
    await cargarPantalla(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre de la mascota'),
      'Firulais',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Raza'),
      'Labrador',
    );

    // Dropdown Tipo de mascota
    final dropdownFinder = find.byWidgetPredicate(
      (widget) => widget is DropdownButtonFormField,
    );

    await tester.dragUntilVisible(
      dropdownFinder,
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    await tester.tap(find.text('🐶 Perro').last);
    await tester.pumpAndSettle();

    // Botón Continuar
    final btnFinder = find.text('Continuar');
    await tester.dragUntilVisible(
      btnFinder,
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.tap(btnFinder);
    await tester.pumpAndSettle();

    expect(
      find.text('Debes agregar al menos una foto o video'),
      findsOneWidget,
    );
    expect(find.text('Paso 1 de 3'), findsOneWidget);
  });

  testWidgets('🔵 Debe avanzar al Paso 2 si todo es válido', (
    WidgetTester tester,
  ) async {
    await cargarPantalla(tester);

    // 1. Llenar textos
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre de la mascota'),
      'Bobby',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Raza'), 'Pug');

    // 2. Dropdown
    final dropdownFinder = find.byWidgetPredicate(
      (widget) => widget is DropdownButtonFormField,
    );
    await tester.dragUntilVisible(
      dropdownFinder,
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('🐶 Perro').last);
    await tester.pumpAndSettle();

    // 3. Foto Falsa (ya subida en VM)
    viewModel.agregarFoto("https://foto-falsa.com/perro.jpg");
    await tester.pump();

    // 4. Continuar
    final btnFinder = find.text('Continuar');
    await tester.dragUntilVisible(
      btnFinder,
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.tap(btnFinder);
    await tester.pumpAndSettle();

    // 5. Verificar cambio de paso
    expect(find.text('Paso 2 de 3'), findsOneWidget);
    expect(find.text('📍 Lugar y momento de pérdida'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // PASO 2
  // ---------------------------------------------------------------------------

  testWidgets('🟠 Paso 2 - No debe avanzar si faltan datos requeridos', (
    WidgetTester tester,
  ) async {
    // Forzamos que el wizard comience en el Paso 2
    viewModel.setPaso(1);

    await cargarPantalla(tester);

    // Confirmamos que estamos en Paso 2
    expect(find.text('Paso 2 de 3'), findsOneWidget);
    expect(find.text('📍 Lugar y momento de pérdida'), findsOneWidget);

    // Botón Continuar
    final btnContinuar = find.text('Continuar');
    await tester.dragUntilVisible(
      btnContinuar,
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.tap(btnContinuar);
    await tester.pumpAndSettle();

    // Sigue en Paso 2
    expect(find.text('Paso 2 de 3'), findsOneWidget);

    // Mensajes de validación visibles
    expect(find.text('Seleccione la fecha'), findsOneWidget);
    expect(find.text('Seleccione la hora'), findsOneWidget);
    expect(find.text('Ingrese la dirección'), findsOneWidget);
    expect(find.text('Describa cómo se perdió'), findsOneWidget);
  });

  testWidgets('🟢 Paso 2 - Debe avanzar al Paso 3 si los datos son válidos', (
    WidgetTester tester,
  ) async {
    // Preconfiguramos datos que se muestran con controllers
    viewModel.reporte.fechaPerdida = "01/01/2025";
    viewModel.reporte.horaPerdida = "10:30";
    viewModel.reporte.direccion = "Av. Principal 123";
    viewModel.reporte.distrito = "Tacna";
    viewModel.setPaso(1); // Paso 2

    await cargarPantalla(tester);

    // Confirmamos que estamos en Paso 2
    expect(find.text('Paso 2 de 3'), findsOneWidget);

    // Campo "¿Cómo se perdió?" (requerido)
    await tester.enterText(
      find.widgetWithText(TextFormField, '¿Cómo se perdió?'),
      'Se escapó por la puerta.',
    );

    // Botón Continuar
    final btnContinuar = find.text('Continuar');
    await tester.dragUntilVisible(
      btnContinuar,
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.tap(btnContinuar);
    await tester.pumpAndSettle();

    // Debe haber navegado al Paso 3
    expect(find.text('Paso 3 de 3'), findsOneWidget);
    expect(find.text('Resumen del reporte'), findsOneWidget);
  });

  testWidgets(
    '🟡 Paso 2 → Debe seleccionar fecha desde showDatePicker y actualizar el modelo',
    (WidgetTester tester) async {
      // 1. Fecha que queremos simular como seleccionada
      final fakeDate = DateTime(2025, 11, 20);

      // 2. Correr en un Zone override para interceptar showDatePicker
      await Zone.current
          .fork(
            zoneValues: {
              #showDatePicker: () async =>
                  fakeDate, // ← aquí devolvemos la fecha simulada
            },
          )
          .run(() async {
            await cargarPantalla(tester);

            // Ir al paso 2
            viewModel.setPaso(1);
            await tester.pumpAndSettle();

            // Buscar el campo "Fecha de pérdida"
            final fechaField = find.widgetWithText(
              TextFormField,
              'Fecha de pérdida',
            );

            expect(fechaField, findsOneWidget);

            // Tocar el campo
            await tester.tap(fechaField);
            await tester.pumpAndSettle();

            // Verificar que el modelo se actualizó
            expect(viewModel.reporte.fechaPerdida, "20/11/2025");
          });
    },
  );

  testWidgets(
    '🟢 Paso 2 → Selección de mapa llena dirección, distrito y coordenadas',
    (WidgetTester tester) async {
      // 🔧 Override del mapa
      WizardOverrides.mapaOverride = () async {
        return {
          "direccion": "Av. Bolognesi",
          "distrito": "Tacna",
          "lat": -18.013,
          "lng": -70.253,
        };
      };

      await cargarPantalla(tester);

      // Avanza al Paso 2
      viewModel.setPaso(1);
      await tester.pumpAndSettle();

      // Busca el botón de mapa
      final btnMapa = find.text("Abrir mapa interactivo");
      expect(btnMapa, findsOneWidget);

      await tester.tap(btnMapa);
      await tester.pumpAndSettle();

      // Verificar que el modelo fue llenado
      expect(viewModel.reporte.direccion, "Av. Bolognesi");
      expect(viewModel.reporte.distrito, "Tacna");
      expect(viewModel.reporte.latitud, -18.013);
      expect(viewModel.reporte.longitud, -70.253);

      // Verificar que se autocompleta el TextField
      expect(find.text("Av. Bolognesi"), findsOneWidget);

      // Quitar override
      WizardOverrides.mapaOverride = null;
    },
  );

  testWidgets(
    '🟢 Paso 2 → Icono del mapa actualiza dirección/distrito/coords',
    (WidgetTester tester) async {
      // Override del mapa
      WizardOverrides.mapaOverride = () async {
        return {
          "direccion": "Av. San Martín",
          "distrito": "Alto Lima",
          "lat": -18.001,
          "lng": -70.220,
        };
      };

      // Pasar al paso 2
      viewModel.setPaso(1);

      await cargarPantalla(tester);
      await tester.pumpAndSettle();

      // Buscar el ícono del mapa dentro del TextField
      final tfDireccion = find.widgetWithText(
        TextFormField,
        "Dirección (puedes editar si lo deseas)",
      );
      final iconFinder = find.descendant(
        of: tfDireccion,
        matching: find.byType(IconButton),
      );

      // Tap
      await tester.tap(iconFinder);
      await tester.pumpAndSettle();

      // Verificar en el modelo
      expect(viewModel.reporte.direccion, "Av. San Martín");
      expect(viewModel.reporte.distrito, "Alto Lima");
      expect(viewModel.reporte.latitud, -18.001);
      expect(viewModel.reporte.longitud, -70.220);

      // Verifica que se autocompletó el campo
      expect(find.text("Av. San Martín"), findsOneWidget);

      // Limpiar override
      WizardOverrides.mapaOverride = null;
    },
  );

  testWidgets(
    '🟡 Paso 2 → Debe seleccionar hora desde showTimePicker y actualizar el modelo',
    (WidgetTester tester) async {
      // 1. Fijar valor esperado
      final fakeTime = TimeOfDay(hour: 15, minute: 45);

      // 2. Ejecutar dentro del Zone override
      await Zone.current
          .fork(zoneValues: {#showTimePicker: () async => fakeTime})
          .run(() async {
            await cargarPantalla(tester);

            // Ir al Paso 2
            viewModel.setPaso(1);
            await tester.pumpAndSettle();

            // Buscar campo de hora
            final horaField = find.widgetWithText(
              TextFormField,
              'Hora aproximada',
            );

            expect(horaField, findsOneWidget);

            // Tocar el campo
            await tester.tap(horaField);
            await tester.pumpAndSettle();

            // Verificar que se actualizó el modelo
            expect(viewModel.reporte.horaPerdida, "15:45");
          });
    },
  );
  // ---------------------------------------------------------------------------
  // PASO 3
  // ---------------------------------------------------------------------------

  testWidgets('🔙 Paso 3 - Botón Atrás debe regresar al Paso 2', (
    WidgetTester tester,
  ) async {
    // Configuramos el VM para que ya esté en Paso 3 con datos mínimos
    viewModel.setPaso(2);
    viewModel.reporte.nombre = "Toby";
    viewModel.reporte.tipo = "Perro";
    viewModel.reporte.raza = "Mestizo";
    viewModel.reporte.fechaPerdida = "02/02/2025";
    viewModel.reporte.horaPerdida = "12:00";
    viewModel.reporte.direccion = "Calle Falsa 123";
    viewModel.agregarFoto("https://foto-falsa.com/perro2.jpg");

    await cargarPantalla(tester);

    // Confirmamos que estamos en Paso 3
    expect(find.text('Paso 3 de 3'), findsOneWidget);
    expect(find.text('Resumen del reporte'), findsOneWidget);

    // Botón Atrás
    final btnAtras = find.text('Atrás');
    await tester.tap(btnAtras);
    await tester.pumpAndSettle();

    // Ahora deberíamos estar en Paso 2
    expect(find.text('Paso 2 de 3'), findsOneWidget);
    expect(find.text('📍 Lugar y momento de pérdida'), findsOneWidget);
  });

  testWidgets('🟣 Debe completar el Paso 3 y guardar el reporte', (
    WidgetTester tester,
  ) async {
    // 1. Configurar Mocks profundos
    final mockCollection = MockCollectionReferenceMap();
    final mockDocument = MockDocumentReferenceMap();

    when(
      mockFirestore.collection("reportes_mascotas"),
    ).thenReturn(mockCollection);

    // Mockeamos la llamada .doc()
    when(mockCollection.doc()).thenReturn(mockDocument);
    when(mockCollection.doc(any)).thenReturn(mockDocument);

    when(mockDocument.id).thenReturn("reporte_final_123");
    when(mockDocument.set(any)).thenAnswer((_) async {});

    when(
      mockServicios.enviarPush(
        titulo: anyNamed('titulo'),
        cuerpo: anyNamed('cuerpo'),
      ),
    ).thenAnswer((_) async {});

    // 2. PRE-CONDICIÓN
    viewModel.setPaso(2);
    viewModel.reporte.nombre = "Max";
    viewModel.reporte.tipo = "Perro";
    viewModel.reporte.raza = "Golden";
    viewModel.reporte.direccion = "Plaza de Armas";
    viewModel.reporte.fechaPerdida = "20/11/2025";
    viewModel.reporte.horaPerdida = "14:30";
    viewModel.agregarFoto("https://foto-falsa.com/perro.jpg");

    await cargarPantalla(tester);

    expect(find.text('Resumen del reporte'), findsOneWidget);

    // 4. Buscar botón y pulsar
    final btnGuardar = find.text('Publicar reporte');
    await tester.dragUntilVisible(
      btnGuardar,
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    await tester.tap(btnGuardar);

    // 5. Verificar éxito
    await tester.pump();

    expect(find.text('✅ Reporte guardado con éxito'), findsOneWidget);
  });
}

// ---------------------------------------------------------------------------
// HTTP Fakes para evitar errores al cargar imágenes en tests
// ---------------------------------------------------------------------------

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient();
  }
}

class _FakeHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _FakeHttpClientRequest();
  }

  @override
  set autoUncompress(bool value) {}
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async {
    return _FakeHttpClientResponse();
  }
}

class _FakeHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => 0;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    const List<int> transparentImage = [
      0x47,
      0x49,
      0x46,
      0x38,
      0x39,
      0x61,
      0x01,
      0x00,
      0x01,
      0x00,
      0x80,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x21,
      0xf9,
      0x04,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x2c,
      0x00,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x01,
      0x00,
      0x00,
      0x02,
      0x02,
      0x44,
      0x01,
      0x00,
      0x3b,
    ];
    return Stream.value(transparentImage).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
