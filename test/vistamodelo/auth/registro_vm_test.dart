import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sos_mascotas/vistamodelo/auth/registro_vm.dart';
import 'package:sos_mascotas/servicios/api_dni_servicio.dart';

import 'registro_vm_test.mocks.dart';

// -------------------------------------------------------------------------
// 1. DEFINICIÓN DE TIPOS EXACTOS
// -------------------------------------------------------------------------
typedef CollectionReferenceMap = CollectionReference<Map<String, dynamic>>;
typedef DocumentReferenceMap = DocumentReference<Map<String, dynamic>>;
typedef QueryMap = Query<Map<String, dynamic>>;
typedef QuerySnapshotMap = QuerySnapshot<Map<String, dynamic>>;
typedef QueryDocumentSnapshotMap = QueryDocumentSnapshot<Map<String, dynamic>>;

// -------------------------------------------------------------------------
// 2. GENERACIÓN DE MOCKS
// -------------------------------------------------------------------------
@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  FirebaseMessaging,
  ApiDniServicio,
  UserCredential,
  User,
  CollectionReferenceMap,
  DocumentReferenceMap,
  QueryMap,
  QuerySnapshotMap,
  QueryDocumentSnapshotMap,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RegistroVM viewModel;
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseMessaging mockMessaging;
  late MockApiDniServicio mockApiDni;

  late MockCollectionReferenceMap mockCollection;
  late MockDocumentReferenceMap mockDocument;
  late MockQueryMap mockQuery;
  late MockQuerySnapshotMap mockQuerySnapshot;
  late MockQueryDocumentSnapshotMap mockQueryDocSnapshot;

  late MockUserCredential mockUserCredential;
  late MockUser mockUser;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockMessaging = MockFirebaseMessaging();
    mockApiDni = MockApiDniServicio();

    mockCollection = MockCollectionReferenceMap();
    mockDocument = MockDocumentReferenceMap();
    mockQuery = MockQueryMap();
    mockQuerySnapshot = MockQuerySnapshotMap();
    mockQueryDocSnapshot = MockQueryDocumentSnapshotMap();

    mockUserCredential = MockUserCredential();
    mockUser = MockUser();

    viewModel = RegistroVM(
      apiDni: mockApiDni,
      auth: mockAuth,
      firestore: mockFirestore,
      messaging: mockMessaging,
    );
  });

  group('RegistroVM - Consulta DNI', () {
    test(
      'Debe llenar el nombre cuando la API responde correctamente',
      () async {
        viewModel.dniCtrl.text = "12345678";

        when(mockApiDni.consultarDni("12345678")).thenAnswer(
          (_) async => {
            'nombres': 'Juan',
            'ape_paterno': 'Perez',
            'ape_materno': 'Lopez',
          },
        );

        final result = await viewModel.buscarYAutocompletarNombre();

        expect(result, true);
        expect(viewModel.nombreCtrl.text, "Juan Perez Lopez");
        expect(viewModel.error, isNull);
      },
    );

    test('Debe mostrar error si la API no encuentra el DNI', () async {
      viewModel.dniCtrl.text = "00000000";
      when(mockApiDni.consultarDni(any)).thenAnswer((_) async => null);

      final result = await viewModel.buscarYAutocompletarNombre();

      expect(result, false);
      expect(viewModel.error, contains("DNI no encontrado"));
    });
  });

  group('RegistroVM - Proceso de Registro', () {
    test('Debe fallar si el DNI ya existe en Firestore', () async {
      viewModel.dniCtrl.text = "12345678";
      viewModel.correoCtrl.text = "test@test.com";
      viewModel.claveCtrl.text = "123456";

      when(mockFirestore.collection("usuarios")).thenReturn(mockCollection);
      when(
        mockCollection.where("dni", isEqualTo: "12345678"),
      ).thenReturn(mockQuery);
      when(mockQuery.limit(1)).thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(mockQuerySnapshot.docs).thenReturn([mockQueryDocSnapshot]);

      final result = await viewModel.registrarUsuario();

      expect(result, false);
      expect(viewModel.error, contains("ya está registrado"));
    });

    test('Debe registrar exitosamente si no hay duplicados', () async {
      // ARRANGE
      viewModel.dniCtrl.text = "87654321"; // DNI que usaremos
      viewModel.correoCtrl.text = "nuevo@test.com";
      viewModel.claveCtrl.text = "123456";

      // 1. Simular búsqueda de duplicados
      when(mockFirestore.collection("usuarios")).thenReturn(mockCollection);

      // ✅ CORRECCIÓN AQUÍ: Usamos el string exacto en lugar de 'any'
      when(
        mockCollection.where("dni", isEqualTo: "87654321"),
      ).thenReturn(mockQuery);

      when(mockQuery.limit(1)).thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(mockQuerySnapshot.docs).thenReturn([]); // No hay duplicados

      // 2. Simular creación en Auth
      when(
        mockAuth.createUserWithEmailAndPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        ),
      ).thenAnswer((_) async => mockUserCredential);
      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockUser.uid).thenReturn("nuevo_uid_123");
      when(mockUser.sendEmailVerification()).thenAnswer((_) async {});

      // 3. Simular guardado en Firestore
      when(mockCollection.doc("nuevo_uid_123")).thenReturn(mockDocument);
      when(mockDocument.set(any)).thenAnswer((_) async {});
      when(mockDocument.update(any)).thenAnswer((_) async {});

      // 4. Simular Token FCM
      when(mockMessaging.getToken()).thenAnswer((_) async => "token_fcm_xyz");

      // ACT
      final result = await viewModel.registrarUsuario();

      // ASSERT
      expect(result, true);
      expect(viewModel.error, isNull);
      verify(mockDocument.set(any)).called(1);
    });
  });
}
