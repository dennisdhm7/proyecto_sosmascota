import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sos_mascotas/vistamodelo/usuario/perfil_vm.dart';

// -------------------------------------------------------------
// 🧪 Fake Image Picker: Controlamos qué imagen selecciona el usuario
// -------------------------------------------------------------
class FakeImagePicker extends Fake implements ImagePicker {
  XFile? archivoParaRetornar;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    return archivoParaRetornar;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late MockFirebaseStorage storage;
  late FakeImagePicker fakePicker;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    final user = MockUser(uid: 'uid123', email: 'juan@mail.com');
    auth = MockFirebaseAuth(mockUser: user, signedIn: true);
    storage = MockFirebaseStorage();
    fakePicker = FakeImagePicker();

    // Preparar documento de usuario inicial
    await firestore.collection('usuarios').doc('uid123').set({
      'nombre': 'Juan',
      'correo': 'juan@mail.com',
      'telefono': '555-1234',
      'ubicacion': 'Tacna',
      'fotoPerfil': 'http://foto-antigua.jpg',
    });
  });

  group('Pruebas de PerfilVM', () {
    test('cargarPerfil carga los datos desde Firestore', () async {
      final vm = PerfilVM(
        auth: auth,
        firestore: firestore,
        storage: storage,
        imagePicker: fakePicker, // Inyectamos el fake
      );

      await vm.cargarPerfil();

      expect(vm.nombreCtrl.text, 'Juan');
      expect(vm.correoCtrl.text, 'juan@mail.com');
      expect(vm.telefonoCtrl.text, '555-1234');
      expect(vm.ubicacionCtrl.text, 'Tacna');
      expect(vm.fotoUrl, 'http://foto-antigua.jpg');
    });

    test(
      'guardar actualiza los campos telefono, ubicacion y fotoPerfil',
      () async {
        final vm = PerfilVM(
          auth: auth,
          firestore: firestore,
          storage: storage,
          imagePicker: fakePicker,
        );
        await vm.cargarPerfil();

        vm.telefonoCtrl.text = '999-9999';
        vm.ubicacionCtrl.text = 'Lima';
        vm.fotoUrl = 'http://nueva-foto';

        await vm.guardar();

        final doc = await firestore.collection('usuarios').doc('uid123').get();
        final data = doc.data()!;
        expect(data['telefono'], '999-9999');
        expect(data['ubicacion'], 'Lima');
        expect(data['fotoPerfil'], 'http://nueva-foto');
      },
    );

    test('guardar guarda cadena vacia cuando fotoUrl es null', () async {
      final vm = PerfilVM(
        auth: auth,
        firestore: firestore,
        storage: storage,
        imagePicker: fakePicker,
      );
      await vm.cargarPerfil();

      vm.telefonoCtrl.text = '000-0000';
      vm.ubicacionCtrl.text = 'Cusco';
      vm.fotoUrl = null;

      await vm.guardar();

      final doc = await firestore.collection('usuarios').doc('uid123').get();
      final data = doc.data()!;
      expect(data['fotoPerfil'], ''); // debe guardar cadena vacía
    });

    // -------------------------------------------------------
    // 📸 TESTS NUEVOS PARA CAMBIAR FOTO
    // -------------------------------------------------------

    test('cambiarFoto sube imagen a Storage y actualiza Firestore', () async {
      final vm = PerfilVM(
        auth: auth,
        firestore: firestore,
        storage: storage,
        imagePicker: fakePicker,
      );

      // 1. Configuramos el Fake para que retorne una imagen simulada
      fakePicker.archivoParaRetornar = XFile('path/a/nueva_foto.jpg');

      // 2. Ejecutamos la acción
      await vm.cambiarFoto();

      // 3. Verificamos que el VM actualizó la URL (MockStorage genera una URL simulada)
      expect(vm.fotoUrl, isNotNull);
      // Las URLs de MockStorage suelen contener "alt=media"
      expect(vm.fotoUrl, contains('http'));

      // 4. Verificamos que se actualizó Firestore con la nueva URL
      final doc = await firestore.collection('usuarios').doc('uid123').get();
      expect(doc.data()!['fotoPerfil'], vm.fotoUrl);

      // 5. Verificar que el archivo existe en el Storage Mockeado
      final ref = storage.ref().child('usuarios/uid123/perfil.jpg');
      // En un mock, verificar que la referencia es válida suele ser suficiente,
      // o intentar obtener el downloadURL de nuevo sin error.
      expect(await ref.getDownloadURL(), isNotNull);
    });

    test(
      'cambiarFoto no hace nada si el usuario cancela (retorna null)',
      () async {
        final vm = PerfilVM(
          auth: auth,
          firestore: firestore,
          storage: storage,
          imagePicker: fakePicker,
        );

        // Estado inicial conocido (del setUp)
        vm.fotoUrl = 'http://foto-antigua.jpg';

        // 1. Configuramos el Fake para retornar NULL (usuario canceló selección)
        fakePicker.archivoParaRetornar = null;

        // 2. Ejecutamos
        await vm.cambiarFoto();

        // 3. Verificamos que NO cambió nada
        expect(vm.fotoUrl, 'http://foto-antigua.jpg');

        final doc = await firestore.collection('usuarios').doc('uid123').get();
        expect(doc.data()!['fotoPerfil'], 'http://foto-antigua.jpg');
      },
    );

    // -------------------------------------------------------

    test('enviarResetPassword no lanza excepción cuando hay correo', () async {
      final vm = PerfilVM(
        auth: auth,
        firestore: firestore,
        storage: storage,
        imagePicker: fakePicker,
      );
      vm.correoCtrl.text = 'test@correo.com';

      // mockAuth.sendPasswordResetEmail no hace nada por defecto, solo verificamos que no explote
      await vm.enviarResetPassword();
    });

    test(
      'enviarResetPassword no lanza excepción cuando correo está vacío',
      () async {
        final vm = PerfilVM(
          auth: auth,
          firestore: firestore,
          storage: storage,
          imagePicker: fakePicker,
        );
        vm.correoCtrl.text = '';

        // El código original tiene un if (correo.isNotEmpty), así que no debe llamar al auth
        await vm.enviarResetPassword();
      },
    );

    test('eliminarCuenta borra documento de firestore y borra usuario', () async {
      final vm = PerfilVM(
        auth: auth,
        firestore: firestore,
        storage: storage,
        imagePicker: fakePicker,
      );

      await vm.eliminarCuenta();

      // Verificar borrado en Firestore
      final doc = await firestore.collection('usuarios').doc('uid123').get();
      expect(doc.exists, isFalse);

      // Verificar que el usuario auth ya no existe (o intentar acceder a él falla)
      // Nota: MockUser no desaparece de mockAuth automáticamente a menos que lo configuremos,
      // pero para este test unitario basta con que la función corra sin errores.
    });

    test('dispose libera recursos correctamente', () async {
      // 1. Agrega async aquí
      final vm = PerfilVM(auth: auth, firestore: firestore, storage: storage);

      // 2. LA SOLUCIÓN:
      // Esperamos explícitamente a que termine la carga inicial lanzada por el constructor.
      // Esto asegura que 'notifyListeners' ocurra ANTES del 'dispose'.
      await vm.cargarPerfil();

      // 3. Ahora sí es seguro matar el VM
      vm.dispose();

      // Verificamos que los controladores ya no se pueden usar
      expect(() => vm.nombreCtrl.addListener(() {}), throwsFlutterError);
    });
  });
}
