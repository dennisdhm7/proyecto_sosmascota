import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sos_mascotas/vista/auth/pantalla_login.dart';
import 'package:sos_mascotas/vistamodelo/auth/login_vm.dart';

// Generamos Mocks para que el ViewModel no falle al iniciarse
@GenerateMocks([FirebaseAuth, FirebaseFirestore, FirebaseMessaging])
import 'pantalla_login_test.mocks.dart';

void main() {
  late LoginVM viewModel;
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseMessaging mockMessaging;

  setUp(() {
    // 1. Inicializamos los servicios falsos
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockMessaging = MockFirebaseMessaging();

    // 2. Creamos el ViewModel REAL pero con servicios FALSOS inyectados
    // Esto permite que textControllers y formKeys funcionen naturalmente
    viewModel = LoginVM(
      auth: mockAuth,
      firestore: mockFirestore,
      messaging: mockMessaging,
    );
  });

  // Función auxiliar para cargar la pantalla en el entorno de prueba
  Future<void> cargarPantalla(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<LoginVM>.value(
          value: viewModel,
          child: const PantallaLogin(),
        ),
        // Definimos rutas vacías para evitar errores si el botón intenta navegar
        routes: {
          '/recuperar': (_) => Container(),
          '/registro': (_) => Container(),
          '/inicio': (_) => Container(),
          '/perfil': (_) => Container(),
        },
      ),
    );
  }

  testWidgets('🟢 Debe mostrar todos los elementos visuales correctamente', (
    WidgetTester tester,
  ) async {
    // Arrange & Act
    await cargarPantalla(tester);

    // Assert: Buscamos textos e iconos clave
    expect(find.text('SOS Mascota'), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);

    // Verificamos los campos de texto por su Label o Hint
    expect(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, 'Contraseña'), findsOneWidget);
  });

  testWidgets('🔴 Debe mostrar errores de validación si los campos están vacíos', (
    WidgetTester tester,
  ) async {
    // 1. Cargar Pantalla
    await cargarPantalla(tester);

    // 2. Act: Tocar el botón "Entrar" sin escribir nada
    await tester.tap(find.text('Entrar'));

    // Re-renderizar la pantalla (pump) para que aparezcan los mensajes de error
    await tester.pump();

    // 3. Assert: Verificar que aparecen los mensajes de validación definidos en tu vista
    expect(find.text('Correo inválido'), findsOneWidget);
    expect(find.text('Mínimo 6 caracteres'), findsOneWidget);
  });

  testWidgets('🔵 Debe escribir en los campos correctamente', (
    WidgetTester tester,
  ) async {
    await cargarPantalla(tester);

    // Escribir en el campo de correo
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      'usuario@test.com',
    );

    // Escribir en el campo de contraseña
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      '123456',
    );

    // Verificar que el ViewModel recibió los cambios (gracias a los controllers)
    expect(viewModel.correoCtrl.text, 'usuario@test.com');
    expect(viewModel.claveCtrl.text, '123456');
  });
}
