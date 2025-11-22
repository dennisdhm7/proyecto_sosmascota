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

import 'pantalla_reporte_mascota_test.mocks.dart';

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

    // ✅ SOLUCIÓN: Buscamos cualquier Dropdown, ignorando si es <String> o <dynamic>
    final dropdownFinder = find.byWidgetPredicate(
      (widget) => widget is DropdownButtonFormField,
    );

    // Hacemos scroll hasta verlo y lo tocamos
    await tester.dragUntilVisible(
      dropdownFinder,
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    // Seleccionamos la opción
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

    // 2. Dropdown (Usando el buscador corregido)
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

    // 3. Foto Falsa
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
  testWidgets('🟣 Debe completar el Paso 3 y guardar el reporte', (
    WidgetTester tester,
  ) async {
    // 1. Configurar Mocks profundos
    final mockCollection = MockCollectionReferenceMap();
    final mockDocument = MockDocumentReferenceMap();

    when(
      mockFirestore.collection("reportes_mascotas"),
    ).thenReturn(mockCollection);

    // ✅ CORRECCIÓN CLAVE: Mockeamos la llamada sin argumentos .doc()
    when(mockCollection.doc()).thenReturn(mockDocument);
    // Por seguridad, mockeamos también si se llamara con argumentos
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
    // Usamos pump() para procesar el microtask del Future y mostrar el SnackBar
    await tester.pump();

    // Verificamos que aparezca el mensaje
    expect(find.text('✅ Reporte guardado con éxito'), findsOneWidget);
  });
}

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
