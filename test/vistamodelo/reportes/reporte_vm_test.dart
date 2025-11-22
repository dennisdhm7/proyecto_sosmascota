import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:sos_mascotas/vistamodelo/reportes/reporte_vm.dart';

// Import obligatorio del archivo generado
import 'reporte_vm_test.mocks.dart';

// Tipos concretos
typedef CollectionReferenceMap = CollectionReference<Map<String, dynamic>>;
typedef DocumentReferenceMap = DocumentReference<Map<String, dynamic>>;

@GenerateMocks(
  [
    FirebaseAuth,
    FirebaseFirestore,
    User,
    CollectionReferenceMap,
    DocumentReferenceMap,
    ReporteServiciosExternos,
    Reference,
    UploadTask,
    TaskSnapshot,
  ],
  customMocks: [MockSpec<FirebaseStorage>(as: #MockFirebaseStorage2)],
)
void main() {
  late ReporteMascotaVM viewModel;

  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseStorage2 mockStorage;
  late MockReporteServiciosExternos mockServicios;
  late MockUser mockUser;

  late MockCollectionReferenceMap mockCollection;
  late MockDocumentReferenceMap mockDocument;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockStorage = MockFirebaseStorage2();
    mockServicios = MockReporteServiciosExternos();
    mockUser = MockUser();

    mockCollection = MockCollectionReferenceMap();
    mockDocument = MockDocumentReferenceMap();

    when(mockAuth.currentUser).thenAnswer((_) => mockUser);
    when(mockUser.uid).thenAnswer((_) => "usuario_prueba_123");

    viewModel = ReporteMascotaVM(
      auth: mockAuth,
      firestore: mockFirestore,
      storage: mockStorage,
      servicios: mockServicios,
    );
  });

  // ----------------------------------------------------------
  //     TESTS DE WIZARD
  // ----------------------------------------------------------
  group('ReporteMascotaVM - Wizard y Navegación', () {
    test('Debe iniciar en el paso 0', () {
      expect(viewModel.paso, 0);
    });

    test('Debe avanzar pasos correctamente pero no pasar de 2', () {
      viewModel.siguientePaso();
      expect(viewModel.paso, 1);
      viewModel.siguientePaso();
      expect(viewModel.paso, 2);
      viewModel.siguientePaso();
      expect(viewModel.paso, 2);
    });

    test('Debe retroceder pasos', () {
      viewModel.setPaso(2);
      viewModel.pasoAnterior();
      expect(viewModel.paso, 1);
    });
  });

  // ----------------------------------------------------------
  //     TESTS DE GUARDADO EN FIRESTORE
  // ----------------------------------------------------------
  group('ReporteMascotaVM - Guardado en Firestore', () {
    test('Guardar reporte exitoso retorna true y envía notificación', () async {
      when(
        mockFirestore.collection("reportes_mascotas"),
      ).thenReturn(mockCollection);

      when(mockCollection.doc(any)).thenReturn(mockDocument);

      when(mockDocument.id).thenReturn("nuevo_id_reporte");

      when(mockDocument.set(any)).thenAnswer((_) async => Future.value());

      when(
        mockServicios.enviarPush(
          titulo: anyNamed("titulo"),
          cuerpo: anyNamed("cuerpo"),
        ),
      ).thenAnswer((_) async {});

      viewModel.reporte.nombre = "Firulais";

      final resultado = await viewModel.guardarReporte();

      expect(resultado, true);
      expect(viewModel.cargando, false);
      expect(viewModel.reporte.id, "nuevo_id_reporte");
    });

    test('Guardar reporte maneja errores y retorna false', () async {
      when(mockFirestore.collection(any)).thenThrow(Exception("Error de red"));

      final resultado = await viewModel.guardarReporte();

      expect(resultado, false);
      expect(viewModel.cargando, false);
    });
  });

  // ----------------------------------------------------------
  //     TESTS DE IA
  // ----------------------------------------------------------
  group('ReporteMascotaVM - Validación de Imágenes (IA)', () {
    test('Debe lanzar error si la confianza es baja', () async {
      final mockFile = File('path/falso.jpg');

      when(
        mockServicios.comprimirImagen(any),
      ).thenAnswer((_) async => mockFile);

      when(
        mockServicios.detectarAnimal(any),
      ).thenAnswer((_) async => {"etiqueta": "perro", "confianza": 0.40});

      expect(() => viewModel.subirFoto(mockFile), throwsA(isA<Exception>()));
    });

    test('subirFoto() debe comprimir → validar IA → subir → dar URL', () async {
      final mockFile = File('foto_fake.jpg');

      final mockRefRoot = MockReference();
      final mockRefFolder = MockReference();
      final mockUserFolder = MockReference();
      final mockRefFinal = MockReference();
      final mockUploadTask = MockUploadTask();
      final mockSnapshot = MockTaskSnapshot();

      // 1. Compresión
      when(
        mockServicios.comprimirImagen(any),
      ).thenAnswer((_) async => mockFile);

      // 2. IA válida
      when(
        mockServicios.detectarAnimal(any),
      ).thenAnswer((_) async => {"etiqueta": "perro", "confianza": 0.95});

      // 3. Firebase Storage – refs
      when(mockStorage.ref()).thenReturn(mockRefRoot);
      when(mockRefRoot.child("reportes_mascotas")).thenReturn(mockRefFolder);
      when(
        mockRefFolder.child("usuario_prueba_123"),
      ).thenReturn(mockUserFolder);

      // Archivo dinámico tipo "123123123.jpg"
      when(mockUserFolder.child(any)).thenReturn(mockRefFinal);

      // SUBIR FOTO
      when(mockRefFinal.putFile(any)).thenAnswer((_) => mockUploadTask);

      // Necesario porque UploadTask es un Future y usa THEN().
      when(mockUploadTask.then(any, onError: anyNamed('onError'))).thenAnswer((
        inv,
      ) async {
        final onValue = inv.positionalArguments.first;
        return onValue(mockSnapshot);
      });

      // whenComplete()
      when(mockUploadTask.whenComplete(any)).thenAnswer((inv) async {
        final cb = inv.positionalArguments.first;
        cb();
        return mockSnapshot;
      });

      // URL final
      when(
        mockRefFinal.getDownloadURL(),
      ).thenAnswer((_) async => "https://fakeurl.com/foto.jpg");

      // Ejecutar
      final url = await viewModel.subirFoto(mockFile);

      // Verificar
      expect(url, "https://fakeurl.com/foto.jpg");
    });
    // -------------------------------------------------------------------------
    // SUBIR VIDEO
    // -------------------------------------------------------------------------
    test(
      'subirVideo() debe subir archivo al Storage y devolver la URL',
      () async {
        final mockFile = File('video_fake.mp4');

        final mockRefRoot = MockReference();
        final mockRefFolder = MockReference();
        final mockUserFolder = MockReference();
        final mockRefFinal = MockReference();
        final mockUploadTask = MockUploadTask();
        final mockSnapshot = MockTaskSnapshot();

        // refs
        when(mockStorage.ref()).thenReturn(mockRefRoot);
        when(mockRefRoot.child("reportes_mascotas")).thenReturn(mockRefFolder);
        when(
          mockRefFolder.child("usuario_prueba_123"),
        ).thenReturn(mockUserFolder);

        // archivo dinámico
        when(mockUserFolder.child(any)).thenReturn(mockRefFinal);

        // subir archivo
        when(mockRefFinal.putFile(any)).thenAnswer((_) => mockUploadTask);

        // NECESARIO — UploadTask es Future → usa .then()
        when(mockUploadTask.then(any, onError: anyNamed('onError'))).thenAnswer(
          (inv) async {
            final onValue = inv.positionalArguments.first;
            return onValue(mockSnapshot);
          },
        );

        // whenComplete
        when(mockUploadTask.whenComplete(any)).thenAnswer((inv) async {
          final cb = inv.positionalArguments.first;
          cb();
          return mockSnapshot;
        });

        // URL final
        when(
          mockRefFinal.getDownloadURL(),
        ).thenAnswer((_) async => "https://fakeurl.com/video.mp4");

        // ejecutar
        final url = await viewModel.subirVideo(mockFile);

        // verificar
        expect(url, "https://fakeurl.com/video.mp4");
      },
    );
  });
}
