import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';

import 'package:sos_mascotas/vistamodelo/usuario/perfil_vm.dart';

// -------------------------------------------------------------
// Tests usando fakes/mocks de los paquetes de Firebase
// -------------------------------------------------------------
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late MockFirebaseStorage storage;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    final user = MockUser(uid: 'uid123', email: 'juan@mail.com');
    auth = MockFirebaseAuth(mockUser: user, signedIn: true);
    storage = MockFirebaseStorage();

    // preparar documento de usuario
    await firestore.collection('usuarios').doc('uid123').set({
      'nombre': 'Juan',
      'correo': 'juan@mail.com',
      'telefono': '555-1234',
      'ubicacion': 'Tacna',
      'fotoPerfil': 'http://foto',
    });
  });

  test('cargarPerfil carga los datos desde Firestore', () async {
    final vm = PerfilVM(auth: auth, firestore: firestore, storage: storage);

    await vm.cargarPerfil();

    expect(vm.nombreCtrl.text, 'Juan');
    expect(vm.correoCtrl.text, 'juan@mail.com');
    expect(vm.telefonoCtrl.text, '555-1234');
    expect(vm.ubicacionCtrl.text, 'Tacna');
    expect(vm.fotoUrl, 'http://foto');
  });

  test(
    'guardar actualiza los campos telefono y ubicacion y fotoPerfil',
    () async {
      final vm = PerfilVM(auth: auth, firestore: firestore, storage: storage);
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
    final vm = PerfilVM(auth: auth, firestore: firestore, storage: storage);
    await vm.cargarPerfil();

    vm.telefonoCtrl.text = '000-0000';
    vm.ubicacionCtrl.text = 'Cusco';
    vm.fotoUrl = null;

    await vm.guardar();

    final doc = await firestore.collection('usuarios').doc('uid123').get();
    final data = doc.data()!;
    expect(data['telefono'], '000-0000');
    expect(data['ubicacion'], 'Cusco');
    expect(
      data['fotoPerfil'],
      '',
    ); // debe guardar cadena vacía si fotoUrl es null
  });

  test('enviarResetPassword no lanza cuando hay correo', () async {
    final vm = PerfilVM(auth: auth, firestore: firestore, storage: storage);
    vm.correoCtrl.text = 'test@correo.com';

    // debe completar sin excepciones
    await vm.enviarResetPassword();
  });

  test('enviarResetPassword no lanza cuando correo vacio', () async {
    final vm = PerfilVM(auth: auth, firestore: firestore, storage: storage);
    vm.correoCtrl.text = '';

    // debe completar sin excepciones
    await vm.enviarResetPassword();
  });

  test('eliminarCuenta borra documento de firestore', () async {
    final vm = PerfilVM(auth: auth, firestore: firestore, storage: storage);

    await vm.eliminarCuenta();

    final doc = await firestore.collection('usuarios').doc('uid123').get();
    expect(doc.exists, isFalse);
  });
}
