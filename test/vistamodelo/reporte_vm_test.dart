import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:sos_mascotas/vistamodelo/reportes/reporte_vm.dart';

// ✅ CORRECCIÓN: El import del archivo generado DEBE ir aquí arriba
import 'reporte_vm_test.mocks.dart';

// -------------------------------------------------------------------------
// 1. DEFINICIÓN DE TIPOS
// -------------------------------------------------------------------------
typedef CollectionReferenceMap = CollectionReference<Map<String, dynamic>>;
typedef DocumentReferenceMap = DocumentReference<Map<String, dynamic>>;

// -------------------------------------------------------------------------
// 2. GENERACIÓN DE MOCKS
// -------------------------------------------------------------------------
@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  FirebaseStorage,
  User,
  CollectionReferenceMap, // Usamos el tipo específico definido arriba
  DocumentReferenceMap, // Usamos el tipo específico definido arriba
  ReporteServiciosExternos, // Nuestro wrapper
])
void main() {
  late ReporteMascotaVM viewModel;

  // Mocks principales
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseStorage mockStorage;
  late MockReporteServiciosExternos mockServicios;
  late MockUser mockUser;

  // Mocks específicos de Firestore (Tipados correctamente)
  late MockCollectionReferenceMap mockCollection;
  late MockDocumentReferenceMap mockDocument;

  setUp(() {
    // Inicialización
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockStorage = MockFirebaseStorage();
    mockServicios = MockReporteServiciosExternos();
    mockUser = MockUser();

    mockCollection = MockCollectionReferenceMap();
    mockDocument = MockDocumentReferenceMap();

    // Configuración por defecto: Usuario Logueado
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn("usuario_prueba_123");

    // Inyección de dependencias al ViewModel
    viewModel = ReporteMascotaVM(
      auth: mockAuth,
      firestore: mockFirestore,
      storage: mockStorage,
      servicios: mockServicios,
    );
  });

  group('ReporteMascotaVM - Wizard y Navegación', () {
    test('Debe iniciar en el paso 0', () {
      expect(viewModel.paso, 0);
    });

    test('Debe avanzar pasos correctamente pero no pasar de 2', () {
      viewModel.siguientePaso();
      expect(viewModel.paso, 1);
      viewModel.siguientePaso();
      expect(viewModel.paso, 2);
      viewModel.siguientePaso(); // Intento extra
      expect(viewModel.paso, 2); // Se queda en 2
    });

    test('Debe retroceder pasos', () {
      viewModel.setPaso(2);
      viewModel.pasoAnterior();
      expect(viewModel.paso, 1);
    });
  });

  group('ReporteMascotaVM - Guardado en Firestore', () {
    test('Guardar reporte exitoso retorna true y envía notificación', () async {
      // 1. ARRANGE (Preparar el escenario)

      // Simulamos la llamada a collection()
      when(
        mockFirestore.collection("reportes_mascotas"),
      ).thenReturn(mockCollection);

      // Simulamos la llamada a doc()
      when(mockCollection.doc(any)).thenReturn(mockDocument);

      // Simulamos propiedades del documento
      when(mockDocument.id).thenReturn("nuevo_id_reporte");

      // Simulamos el guardado set() retornando Future void
      when(mockDocument.set(any)).thenAnswer((_) async => Future.value());

      // Simulamos Notificación exitosa
      when(
        mockServicios.enviarPush(
          titulo: anyNamed('titulo'),
          cuerpo: anyNamed('cuerpo'),
        ),
      ).thenAnswer((_) async => Future.value());

      // Llenar datos básicos
      viewModel.reporte.nombre = "Firulais";

      // 2. ACT (Ejecutar)
      final resultado = await viewModel.guardarReporte();

      // 3. ASSERT (Verificar)
      expect(resultado, true);
      expect(viewModel.cargando, false);
      expect(viewModel.reporte.id, "nuevo_id_reporte");

      // Verificar que se llamó a Firestore con los datos esperados
      verify(
        mockDocument.set(
          argThat(
            predicate((Map<String, dynamic> data) {
              return data['usuarioId'] == 'usuario_prueba_123' &&
                  data['estado'] == 'perdido';
            }),
          ),
        ),
      ).called(1);
    });

    test('Guardar reporte maneja errores y retorna false', () async {
      // 1. ARRANGE - Forzamos un error
      when(mockFirestore.collection(any)).thenThrow(Exception("Error de red"));

      // 2. ACT
      final resultado = await viewModel.guardarReporte();

      // 3. ASSERT
      expect(resultado, false);
      expect(viewModel.cargando, false);
    });
  });

  group('ReporteMascotaVM - Validación de Imágenes (IA)', () {
    test('Debe lanzar error si la confianza de TFLite es baja', () async {
      // 1. ARRANGE
      final mockFile = File('path/falso.jpg');

      // Simular compresión (devuelve el mismo archivo)
      when(
        mockServicios.comprimirImagen(any),
      ).thenAnswer((_) async => mockFile);

      // Simular TFLite devolviendo confianza baja (0.4)
      when(mockServicios.detectarAnimal(any)).thenAnswer(
        (_) async => {
          "etiqueta": "perro",
          "confianza": 0.4, // < 0.6, debería fallar
        },
      );

      // 2. ACT & ASSERT
      expect(
        () async => await viewModel.subirFoto(mockFile),
        throwsA(isA<Exception>()),
      );
    });
  });
}
