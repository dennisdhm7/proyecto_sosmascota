import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sos_mascotas/vista/auth/pantalla_recuperar.dart';
import 'package:sos_mascotas/vistamodelo/auth/recuperar_vm.dart';

// Usamos Mockito para el Auth
@GenerateMocks([FirebaseAuth])
import 'pantalla_recuperar_test.mocks.dart';

void main() {
  late RecuperarVM viewModel;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    // Creamos el VM real con auth mockeado
    viewModel = RecuperarVM(auth: mockAuth);
  });

  Future<void> cargarPantalla(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<RecuperarVM>.value(
          value: viewModel,
          child: const PantallaRecuperar(),
        ),
        // Definimos rutas dummy para que el Navigator no falle
        routes: {'/login': (_) => Container()},
      ),
    );
  }

  testWidgets('🟢 Debe mostrar elementos visuales (Título, Campo, Botón)', (
    WidgetTester tester,
  ) async {
    await cargarPantalla(tester);

    expect(find.text('Recuperar contraseña'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      findsOneWidget,
    );
    expect(find.text('Enviar enlace de recuperación'), findsOneWidget);
  });

  testWidgets('🔴 Debe mostrar error si el correo es inválido', (
    WidgetTester tester,
  ) async {
    await cargarPantalla(tester);

    // 1. Escribir correo mal formado
    await tester.enterText(find.byType(TextFormField), 'correo-sin-arroba');

    // 2. Presionar botón
    await tester.tap(find.text('Enviar enlace de recuperación'));
    await tester.pump(); // Rebuild para mostrar errores

    // 3. Verificar mensaje de error
    expect(find.text('Correo inválido'), findsOneWidget);
  });

  testWidgets('🔵 Debe llamar a enviarCorreo si el formulario es válido', (
    WidgetTester tester,
  ) async {
    // Simulamos respuesta exitosa de Firebase
    when(
      mockAuth.sendPasswordResetEmail(email: anyNamed('email')),
    ).thenAnswer((_) async {});

    await cargarPantalla(tester);

    // 1. Escribir correo válido
    await tester.enterText(find.byType(TextFormField), 'test@valido.com');

    // 2. Presionar botón
    await tester.tap(find.text('Enviar enlace de recuperación'));

    // Esperamos a que el Future se resuelva y la UI reaccione
    await tester.pump();

    // 3. Verificar que el botón cambió a cargando (CircularProgressIndicator)
    // O que se llamó a la función de Firebase
    verify(mockAuth.sendPasswordResetEmail(email: 'test@valido.com')).called(1);
  });
}
