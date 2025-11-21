import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sos_mascotas/vistamodelo/auth/recuperar_vm.dart';

// Generamos Mock de FirebaseAuth
@GenerateMocks([FirebaseAuth])
import 'recuperar_vm_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecuperarVM viewModel;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    viewModel = RecuperarVM(auth: mockAuth);
  });

  group('🧪 Pruebas de RecuperarVM', () {
    test('Debe enviar correo de recuperación exitosamente', () async {
      // 1. ARRANGE
      viewModel.correoCtrl.text = "usuario@test.com";

      // Simulamos que Firebase responde bien (Future void)
      when(
        mockAuth.sendPasswordResetEmail(email: "usuario@test.com"),
      ).thenAnswer((_) async => {});

      // 2. ACT
      // Llamamos sin contexto (null) para probar solo la lógica
      final exito = await viewModel.enviarCorreo(context: null);

      // 3. ASSERT
      expect(exito, true);
      expect(viewModel.enviando, false);
      expect(viewModel.error, isNull);

      // Verificar que se llamó a la función de Firebase
      verify(
        mockAuth.sendPasswordResetEmail(email: "usuario@test.com"),
      ).called(1);
    });

    test('Debe manejar error si el correo no existe o falla', () async {
      // 1. ARRANGE
      viewModel.correoCtrl.text = "error@test.com";

      // Simulamos error de Firebase
      when(mockAuth.sendPasswordResetEmail(email: anyNamed('email'))).thenThrow(
        FirebaseAuthException(
          code: 'user-not-found',
          message: 'Usuario no encontrado',
        ),
      );

      // 2. ACT
      final exito = await viewModel.enviarCorreo(context: null);

      // 3. ASSERT
      expect(exito, false); // Debe fallar
      expect(viewModel.enviando, false);
      expect(
        viewModel.error,
        'Usuario no encontrado',
      ); // El mensaje debe guardarse
    });
  });
}
