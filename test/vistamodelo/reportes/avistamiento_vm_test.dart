import 'dart:io';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:http/http.dart' as http;
import 'package:sos_mascotas/vistamodelo/reportes/avistamiento_vm.dart';

// Generamos Mocks
@GenerateMocks([http.Client, AvistamientoServices])
import 'avistamiento_vm_test.mocks.dart';

void main() {
  late AvistamientoVM vm;
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseStorage mockStorage;
  late MockClient mockHttpClient;
  late MockAvistamientoServices mockServices;

  setUp(() {
    // 1. Configurar Mocks
    final user = MockUser(uid: 'test_user');
    mockAuth = MockFirebaseAuth(mockUser: user, signedIn: true);
    fakeFirestore = FakeFirebaseFirestore();
    mockStorage = MockFirebaseStorage();
    mockHttpClient = MockClient();
    mockServices = MockAvistamientoServices();

    // Configurar respuestas por defecto del Servicio Mock
    when(
      mockServices.getTempDir(),
    ).thenAnswer((_) async => Directory.systemTemp);
    when(
      mockServices.compress(any, any),
    ).thenAnswer((_) async => File('test.jpg')); // Retorna archivo falso
    when(
      mockServices.enviarPush(
        titulo: anyNamed('titulo'),
        cuerpo: anyNamed('cuerpo'),
      ),
    ).thenAnswer((_) async => null);

    // 2. Inicializar VM con dependencias
    vm = AvistamientoVM(
      auth: mockAuth,
      firestore: fakeFirestore,
      storage: mockStorage,
      httpClient: mockHttpClient,
      services: mockServices,
    );
  });

  group('Subir Foto', () {
    test('Debe subir foto si la IA detecta un animal', () async {
      final file = File('prueba.jpg');

      // Simulamos que la IA dice "Perro" con 90% de confianza
      when(
        mockServices.detectarAnimal(any),
      ).thenAnswer((_) async => {"etiqueta": "Perro", "confianza": 0.90});

      final url = await vm.subirFoto(file);

      expect(url, isNotNull); // MockStorage genera una URL falsa
      expect(vm.mensajeUsuario, contains("Se detectó un Perro"));
      verify(mockServices.detectarAnimal(any)).called(1);
    });

    test('Debe fallar si la IA detecta "otro" o confianza baja', () async {
      final file = File('prueba.jpg');

      // Simulamos fallo de IA
      when(
        mockServices.detectarAnimal(any),
      ).thenAnswer((_) async => {"etiqueta": "otro", "confianza": 0.40});

      final url = await vm.subirFoto(file);

      expect(url, isNull);
      expect(vm.estado, EstadoCarga.error);
      expect(vm.mensajeUsuario, contains("No se detectó una mascota clara"));
    });
  });

  group('Guardar Avistamiento', () {
    test('Debe guardar exitosamente en Firestore', () async {
      // Pre-condiciones
      vm.avistamiento.descripcion = "Perro visto";
      vm.avistamiento.foto = "http://url.com/foto.jpg";
      vm.avistamiento.latitud = -18.0;
      vm.avistamiento.longitud = -70.0;

      final result = await vm.guardarAvistamiento();

      expect(result, true);
      expect(vm.estado, EstadoCarga.exito);
      expect(vm.mensajeUsuario, contains("guardado correctamente"));

      // Verificar que se guardó en la DB falsa
      final snapshot = await fakeFirestore.collection('avistamientos').get();
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.data()['descripcion'], "Perro visto");
    });

    test('Debe validar campos antes de guardar', () async {
      vm.avistamiento.descripcion = ""; // Inválido

      final result = await vm.guardarAvistamiento();

      expect(result, false);
      expect(vm.estado, EstadoCarga.error);
      expect(vm.mensajeUsuario, contains("Debes subir una foto"));
    });
  });

  group('Coincidencias (Lógica Compleja)', () {
    test('Debe detectar coincidencia y vincular reporte', () async {
      // 1. Crear un reporte perdido en la DB falsa CERCANO (-18.0, -70.0)
      await fakeFirestore.collection('reportes_mascotas').add({
        'estado': 'perdido',
        'latitud': -18.001, // Muy cerca
        'longitud': -70.001,
        'fotos': ['http://url.com/perdido.jpg'],
        'usuarioId': 'otro_usuario',
      });

      // 2. Configurar Avistamiento del VM
      vm.avistamiento.descripcion = "Lo vi";
      vm.avistamiento.foto = "http://url.com/avistado.jpg";
      vm.avistamiento.latitud = -18.0;
      vm.avistamiento.longitud = -70.0;

      // 3. Mocks necesarios para la lógica interna
      // Http client descarga imágenes falsas
      when(
        mockHttpClient.get(any),
      ).thenAnswer((_) async => http.Response('bytes', 200));

      // Servicio compara y dice que son iguales (similitud 0.9)
      when(
        mockServices.compararImagenes(any, any),
      ).thenAnswer((_) async => 0.9);

      // 4. Ejecutar
      await vm.guardarAvistamiento();

      // 5. Verificar vinculación
      final avistamientos = await fakeFirestore
          .collection('avistamientos')
          .get();
      final data = avistamientos.docs.first.data();

      expect(
        data['reporteId'],
        isNotNull,
        reason: "Debería haberse vinculado un ID",
      );
      verify(
        mockServices.enviarPush(
          titulo: anyNamed('titulo'),
          cuerpo: anyNamed('cuerpo'),
        ),
      ).called(greaterThan(0));
    });
  });
}
