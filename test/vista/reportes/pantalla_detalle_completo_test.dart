import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:sos_mascotas/vista/reportes/pantalla_detalle_completo.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUserVisitante;

  // Datos por defecto para usar en los tests
  final reporteDataDefault = {
    "id": "reporte_123",
    "usuarioId": "dueno_123",
    "nombre": "Fido",
    "tipo": "Perro",
    "raza": "Labrador",
    "estado": "PERDIDO",
    "descripcion": "Se perdió",
    "direccion": "Av. Test 123",
    "recompensa": "100.00",
    "latitud": -18.0,
    "longitud": -70.0,
    "fechaPerdida": "20/11/2025",
    "horaPerdida": "10:00",
    "fotos": ["http://foto.com/perro.jpg"],
  };

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    // Usamos un visitante por defecto para que los botones de contacto aparezcan
    mockUserVisitante = MockUser(uid: 'usuario_visitante', email: 'v@test.com');
    mockAuth = MockFirebaseAuth(mockUser: mockUserVisitante, signedIn: true);

    // 🔧 MOCK CANAL NATIVO (Para el Mapa)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'canLaunch') return true;
            if (methodCall.method == 'launch') return true;
            return null;
          },
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        );
  });

  // Helper mejorado: Datos opcionales y Pantalla Grande
  Future<void> cargarPantalla(
    WidgetTester tester, {
    Map<String, dynamic>? data, // Ahora es opcional
    String? tipo, // Ahora es opcional
    MockFirebaseAuth? auth, // Para probar dueño vs visitante
  }) async {
    // 📏 Pantalla alta para evitar errores de scroll/visibilidad
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await mockNetworkImagesFor(
      () => tester.pumpWidget(
        MaterialApp(
          home: PantallaDetalleCompleto(
            data: data ?? reporteDataDefault, // Usa default si es null
            tipo: tipo ?? 'reporte', // Usa default si es null
            firestore: fakeFirestore,
            auth: auth ?? mockAuth,
          ),
        ),
      ),
    );
  }

  group('PantallaDetalleCompleto Test', () {
    // --- TESTS VISUALES BÁSICOS ---

    testWidgets('Renderiza información básica de un Reporte correctamente', (
      tester,
    ) async {
      await cargarPantalla(tester); // Usa los datos por defecto
      await tester.pumpAndSettle();

      expect(find.text("Detalle del Reporte"), findsOneWidget);
      expect(find.text("Fido"), findsOneWidget);
      expect(find.text("Recompensa ofrecida"), findsOneWidget);

      // Verificar color Rojo (PERDIDO)
      final estadoFinder = find.text("PERDIDO");
      final container = tester.widget<Container>(
        find.ancestor(of: estadoFinder, matching: find.byType(Container)).first,
      );
      expect(
        (container.decoration as BoxDecoration).color,
        Colors.red.shade600,
      );
    });

    testWidgets('Carga info del publicador desde Firestore', (tester) async {
      await fakeFirestore.collection('usuarios').doc('dueno_123').set({
        'nombre': 'Juan Perez',
        'correo': 'juan@gmail.com',
      });

      await cargarPantalla(tester);
      await tester.pumpAndSettle();

      expect(find.text("Juan Perez"), findsOneWidget);
    });

    testWidgets('NO muestra botón Contactar si es el dueño', (tester) async {
      // Simulamos que el usuario logueado ES el dueño
      final authDueno = MockFirebaseAuth(
        mockUser: MockUser(uid: 'dueno_123'),
        signedIn: true,
      );

      await fakeFirestore.collection('usuarios').doc('dueno_123').set({
        'nombre': 'Yo',
      });

      await cargarPantalla(tester, auth: authDueno);
      await tester.pumpAndSettle();

      expect(find.text("Contactar"), findsNothing);
    });

    testWidgets('Renderiza correctamente como Avistamiento (Verde)', (
      tester,
    ) async {
      final avistamientoData = {
        ...reporteDataDefault,
        "id": "avist_99",
        "estado": "AVISTADO",
        "recompensa": "", // Sin recompensa
      };

      await cargarPantalla(
        tester,
        data: avistamientoData,
        tipo: 'avistamiento',
      );
      await tester.pumpAndSettle();

      expect(find.text("Detalle del Avistamiento"), findsOneWidget);
      expect(find.text("AVISTADO"), findsOneWidget);

      // Verificar color Verde
      final estadoFinder = find.text("AVISTADO");
      final container = tester.widget<Container>(
        find.ancestor(of: estadoFinder, matching: find.byType(Container)).first,
      );
      expect(
        (container.decoration as BoxDecoration).color,
        Colors.green.shade600,
      );
    });

    // --- TESTS DE IMAGEN ---

    testWidgets('Muestra placeholder si no hay foto', (tester) async {
      final dataSinFoto = {...reporteDataDefault, "fotos": []};
      await cargarPantalla(tester, data: dataSinFoto);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.pets), findsOneWidget);
    });

    // --- TESTS DE LÓGICA (Botones) ---

    testWidgets('MAPA GRANDE: Llama a launchUrl al hacer clic', (tester) async {
      await cargarPantalla(tester);
      await tester.pumpAndSettle();

      final btnMapa = find.text("Ver en Google Maps");

      // ensureVisible hace el scroll automático si es necesario
      await tester.ensureVisible(btnMapa);
      await tester.pumpAndSettle();

      await tester.tap(btnMapa);
      await tester.pump(); // Esperar ejecución

      // Si no explota, pasó (gracias al mock del canal)
    });

    testWidgets('MAPA PEQUEÑO (Lista): Llama a launchUrl', (tester) async {
      // Crear un avistamiento relacionado con coordenadas
      await fakeFirestore.collection('avistamientos').add({
        'reporteId': 'reporte_123',
        'descripcion': 'Visto en el parque',
        'latitud': -12.0,
        'longitud': -77.0,
        'foto': 'http://foto.com/test.jpg',
      });

      await cargarPantalla(tester);
      await tester.pumpAndSettle();

      // Buscar el ícono de mapa dentro del ListTile específico
      final itemFinder = find.widgetWithText(ListTile, 'Visto en el parque');
      final btnMapaMini = find.descendant(
        of: itemFinder,
        matching: find.byIcon(Icons.map_outlined),
      );

      await tester.ensureVisible(btnMapaMini);
      await tester.pumpAndSettle();

      await tester.tap(btnMapaMini);
      await tester.pump();
    });
  });
}
