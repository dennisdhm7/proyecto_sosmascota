import 'package:flutter_test/flutter_test.dart';
import 'package:sos_mascotas/vistamodelo/auth/login_vm.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generamos el Mock de Messaging para evitar que el test intente usar el real
@GenerateMocks([FirebaseMessaging])
import 'login_vm_test.mocks.dart';

// Clase auxiliar para simular error de Auth
class FakeAuthThrows extends MockFirebaseAuth {
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    throw FirebaseAuthException(
      code: 'user-not-found',
      message: "Usuario no existe",
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoginVM vm;
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore mockFirestore;
  late MockFirebaseMessaging mockMessaging; // 👈 Nuevo Mock
  late MockUser mockUser;

  setUp(() {
    // 1. Inicializamos Mocks
    mockFirestore = FakeFirebaseFirestore();
    mockMessaging = MockFirebaseMessaging(); // 👈 Inicializamos

    // Simulamos que getToken devuelve algo para que no falle si se llama
    when(mockMessaging.getToken()).thenAnswer((_) async => "token_falso_123");

    mockUser = MockUser(
      uid: "user123",
      email: "test@test.com",
      isEmailVerified: true,
    );

    mockAuth = MockFirebaseAuth(mockUser: mockUser);

    // 2. 💉 INYECCIÓN COMPLETA (La clave del éxito)
    vm = LoginVM(
      auth: mockAuth,
      firestore: mockFirestore,
      messaging: mockMessaging, // 👈 ¡Aquí evitamos el error [core/no-app]!
    );
  });

  group("🧪 Pruebas de LoginVM", () {
    test("✔ Login exitoso con credenciales correctas", () async {
      vm.correoCtrl.text = "test@test.com";
      vm.claveCtrl.text = "123456";

      final result = await vm.login();

      expect(result, true);
      expect(vm.cargando, false);
      expect(vm.error, isNull);
    });

    test("❌ Login falla si el email NO está verificado", () async {
      final userSinVerificar = MockUser(
        uid: "user999",
        email: "no_verificado@test.com",
        isEmailVerified: false,
      );
      final authSinVerificar = MockFirebaseAuth(mockUser: userSinVerificar);

      // Inyectamos mockMessaging también aquí
      vm = LoginVM(
        auth: authSinVerificar,
        firestore: mockFirestore,
        messaging: mockMessaging,
      );

      vm.correoCtrl.text = "no_verificado@test.com";
      vm.claveCtrl.text = "123456";

      final result = await vm.login();

      expect(result, false);
      expect(vm.error, contains("verificar su correo"));
    });

    test("❌ Manejo de error 'Usuario no encontrado'", () async {
      final authFalla = FakeAuthThrows();
      // Inyectamos mockMessaging también aquí
      vm = LoginVM(
        auth: authFalla,
        firestore: mockFirestore,
        messaging: mockMessaging,
      );

      vm.correoCtrl.text = "noexiste@test.com";
      vm.claveCtrl.text = "123456";

      final result = await vm.login();

      expect(result, false);
      expect(vm.error, contains("Usuario no existe"));
    });

    test("✔ loginYDeterminarRuta retorna /perfil si no tiene foto", () async {
      await mockFirestore.collection("usuarios").doc("user123").set({
        "nombre": "Dennis",
        "fotoPerfil": "",
        "token": "",
      });

      vm.correoCtrl.text = "test@test.com";
      vm.claveCtrl.text = "123456";

      final ruta = await vm.loginYDeterminarRuta();

      expect(ruta, "/perfil");
    });

    test("✔ loginYDeterminarRuta retorna /inicio si YA tiene foto", () async {
      await mockFirestore.collection("usuarios").doc("user123").set({
        "nombre": "Dennis",
        "fotoPerfil": "https://foto.com/yo.jpg",
        "token": "",
      });

      vm.correoCtrl.text = "test@test.com";
      vm.claveCtrl.text = "123456";

      final ruta = await vm.loginYDeterminarRuta();

      expect(ruta, "/inicio");
    });
  });
}
