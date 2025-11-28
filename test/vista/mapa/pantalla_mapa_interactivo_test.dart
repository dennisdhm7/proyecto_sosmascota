import 'dart:async';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_mascotas/vista/mapa/pantalla_mapa_interactivo.dart';
import 'package:sos_mascotas/vista/chat/pantalla_chat.dart';

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient();
  }
}

class _FakeHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _FakeHttpClientRequest();
  }

  @override
  void close({bool force = false}) {}
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return _FakeHttpClientResponse();
  }
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {}

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

void main() {
  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
  });

  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore fakeFirestore;
  late MockUser mockUser;

  setUp(() {
    mockUser = MockUser(uid: 'user_123', email: 'test@test.com');
    mockAuth = MockFirebaseAuth(mockUser: mockUser);
    fakeFirestore = FakeFirebaseFirestore();
  });

  Future<void> cargarMapa(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ScaffoldMessenger(
          child: PantallaMapaInteractivo(
            auth: mockAuth,
            firestore: fakeFirestore,
          ),
        ),
      ),
    );
  }

  testWidgets('🟢 Debe cargar la pantalla y mostrar el mapa sin errores', (
    WidgetTester tester,
  ) async {
    await fakeFirestore.collection('reportes_mascotas').add({
      'nombre': 'Firulais',
      'latitud': -18.0066,
      'longitud': -70.2463,
      'tipo': 'reporte',
      'descripcion': 'Perro perdido',
      'usuarioId': 'user_456',
      'fechaPerdida': '20/11/2025',
    });

    await cargarMapa(tester);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Mapa Interactivo'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
  });

  testWidgets('🔵 Al tocar un marcador, muestra la tarjeta de información', (
    WidgetTester tester,
  ) async {
    await fakeFirestore.collection('avistamientos').add({
      'latitud': -18.0066,
      'longitud': -70.2463,
      'tipo': 'avistamiento',
      'direccion': 'Calle Falsa 123',
      'usuarioId': 'user_456',
      'descripcion': 'Gato visto',
      'fechaAvistamiento': '21/11/2025',
    });

    await cargarMapa(tester);
    await tester.pumpAndSettle();

    final marcador = find.byIcon(Icons.location_on);
    await tester.tap(marcador);
    await tester.pumpAndSettle();

    // ✅ CORRECCIÓN: Usamos findsWidgets porque el texto aparece 2 veces (título y dirección)
    expect(find.textContaining('Avistamiento registrado'), findsOneWidget);
    expect(find.text('Calle Falsa 123'), findsWidgets); // <--- CAMBIO AQUÍ
    expect(find.text('Ver detalle'), findsOneWidget);
  });
  testWidgets('⛔ No debe permitir abrir chat consigo mismo', (tester) async {
    await fakeFirestore.collection('reportes_mascotas').add({
      'nombre': 'Toby',
      'latitud': -18.01,
      'longitud': -70.24,
      'tipo': 'reporte',
      'descripcion': 'Perro',
      'usuarioId': mockUser.uid,
      'fechaPerdida': '20/11/2025',
    });

    await cargarMapa(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.location_on));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Contactar"));
    await tester.pump(const Duration(milliseconds: 500));

    // ❌ No navega → PantallaChat NO debe aparecer
    expect(find.byType(PantallaChat), findsNothing);
  });
  // 🟣 1) Sí debe permitir abrir chat cuando el usuario NO es el dueño
  testWidgets('🟠 El botón Contactar aparece solo al seleccionar un marcador', (
    tester,
  ) async {
    await fakeFirestore.collection('reportes_mascotas').add({
      'nombre': 'Rex',
      'latitud': -18.017,
      'longitud': -70.247,
      'tipo': 'reporte',
      'usuarioId': 'user_999',
      'descripcion': 'Perro grande',
      'fechaPerdida': '21/11/2025',
    });

    await cargarMapa(tester);
    await tester.pumpAndSettle();

    // ❌ Al inicio NO debe existir botón contactar
    expect(find.text('Contactar'), findsNothing);

    // Seleccionar marcador
    await tester.tap(find.byIcon(Icons.location_on));
    await tester.pumpAndSettle();

    // ✔ Ahora sí debe mostrarse
    expect(find.text('Contactar'), findsOneWidget);
  });
}
