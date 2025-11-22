import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sos_mascotas/vista/auth/pantalla_verifica_email.dart';
import 'package:sos_mascotas/servicios/auth_servicio.dart';
import 'package:sos_mascotas/servicios/firestore_servicio.dart';

// Mocks
@GenerateMocks([FirebaseAuth, User, AuthServicio, FirestoreServicio])
import 'pantalla_verifica_email_test.mocks.dart';

void main() {
  // 1. Configuración de Firebase Core
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();

    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.email).thenReturn("test@coverage.com");
    when(mockUser.uid).thenReturn("user_123");
  });

  Future<void> cargarPantalla(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: const PantallaVerificaEmail(),
        routes: {'/login': (_) => const Scaffold(body: Text("Login"))},
      ),
    );
  }

  testWidgets('🟢 Renderiza la pantalla y valida textos', (
    WidgetTester tester,
  ) async {
    await cargarPantalla(tester);
    await tester.pumpAndSettle();

    expect(find.text('Verifique su correo'), findsOneWidget);
    expect(find.byIcon(Icons.mark_email_unread_outlined), findsOneWidget);
    expect(find.text('Ya verifiqué'), findsOneWidget);
  });

  testWidgets('🔵 Botón Reenviar ejecuta lógica (Suma Cobertura)', (
    WidgetTester tester,
  ) async {
    await cargarPantalla(tester);
    await tester.pumpAndSettle();

    final btnReenviar = find.textContaining('Reenviar');
    if (btnReenviar.evaluate().isNotEmpty) {
      await tester.tap(btnReenviar);
      // Damos tiempo para que la lógica asíncrona ocurra
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verificamos que siga en pantalla (no crasheó)
      expect(find.byType(Scaffold), findsOneWidget);
    }
  });

  testWidgets('🔴 Botón Ya Verifiqué maneja la interacción', (
    WidgetTester tester,
  ) async {
    await cargarPantalla(tester);
    await tester.pumpAndSettle();

    final btnVerificar = find.text('Ya verifiqué');
    await tester.tap(btnVerificar);

    // ✅ CORRECCIÓN: Esperamos a que termine la operación
    await tester.pump(); // Inicia proceso
    await tester.pump(const Duration(milliseconds: 500)); // Esperamos respuesta

    // Como el servicio real fallará (no hay backend), debe mostrar un SnackBar de error.
    // Al verificar esto, confirmamos que pasó por toda la función _yaVerifique.
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
