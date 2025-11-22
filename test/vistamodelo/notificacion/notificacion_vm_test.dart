import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sos_mascotas/vistamodelo/notificacion/notificacion_vm.dart';
import 'package:sos_mascotas/modelo/notificacion.dart';

// ✅ Import del archivo generado
import 'notificacion_vm_test.mocks.dart';

// -------------------------------------------------------------------------
// 1. TYPEDEFS
// -------------------------------------------------------------------------
typedef CollectionReferenceMap = CollectionReference<Map<String, dynamic>>;
typedef QueryMap = Query<Map<String, dynamic>>;
typedef QuerySnapshotMap = QuerySnapshot<Map<String, dynamic>>;
typedef QueryDocumentSnapshotMap = QueryDocumentSnapshot<Map<String, dynamic>>;
typedef DocumentReferenceMap = DocumentReference<Map<String, dynamic>>;

// -------------------------------------------------------------------------
// 2. MOCKS
// -------------------------------------------------------------------------
@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  User,
  NotificacionServiciosExternos,
  WriteBatch,
  CollectionReferenceMap,
  QueryMap,
  QuerySnapshotMap,
  QueryDocumentSnapshotMap,
  DocumentReferenceMap,
])
void main() {
  late NotificacionVM viewModel;
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockNotificacionServiciosExternos mockServicios;
  late MockUser mockUser;

  late MockWriteBatch mockBatch;
  late MockCollectionReferenceMap mockCollection;
  late MockQueryMap mockQuery;
  late MockQuerySnapshotMap mockSnapshot;
  late MockQueryDocumentSnapshotMap mockDocSnapshot;
  late MockDocumentReferenceMap mockDocRef;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockServicios = MockNotificacionServiciosExternos();
    mockUser = MockUser();

    mockBatch = MockWriteBatch();
    mockCollection = MockCollectionReferenceMap();
    mockQuery = MockQueryMap();
    mockSnapshot = MockQuerySnapshotMap();
    mockDocSnapshot = MockQueryDocumentSnapshotMap();
    mockDocRef = MockDocumentReferenceMap();

    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn("user_123");

    viewModel = NotificacionVM(
      auth: mockAuth,
      firestore: mockFirestore,
      servicios: mockServicios,
    );
  });

  group('NotificacionVM', () {
    test('escucharNotificaciones debe actualizar lista y contador', () async {
      // 1. ARRANGE
      // ✅ CORRECCIÓN: Agregamos 'mensaje' y tipamos la lista explícitamente
      final List<Notificacion> listaNotificaciones = [
        Notificacion(
          id: '1',
          titulo: 'Hola',
          mensaje: 'Bienvenido',
          leido: true,
          fecha: DateTime.now(),
          usuarioId: 'user_123',
          tipo: 'sistema', // ✅ Agregado
        ),
        Notificacion(
          id: '2',
          titulo: 'Alerta',
          mensaje: 'Mascota cerca',
          leido: false,
          fecha: DateTime.now(),
          usuarioId: 'user_123',
          tipo: 'avistamiento', // ✅ Agregado
        ),
        Notificacion(
          id: '3',
          titulo: 'Aviso',
          mensaje: 'Nuevo comentario',
          leido: false,
          fecha: DateTime.now(),
          usuarioId: 'user_123',
          tipo: 'comentario', // ✅ Agregado
        ),
      ];

      // Simulamos el Stream
      when(
        mockServicios.obtenerNotificaciones("user_123"),
      ).thenAnswer((_) => Stream.value(listaNotificaciones));

      // 2. ACT
      viewModel.escucharNotificaciones();

      await Future.delayed(Duration.zero);

      // 3. ASSERT
      expect(viewModel.notificaciones.length, 3);
      expect(viewModel.noLeidas, 2);
    });

    test('marcarTodasComoLeidas debe ejecutar batch update', () async {
      // 1. ARRANGE
      when(mockFirestore.batch()).thenReturn(mockBatch);
      when(
        mockFirestore.collection('notificaciones'),
      ).thenReturn(mockCollection);

      when(
        mockCollection.where('usuarioId', isEqualTo: "user_123"),
      ).thenReturn(mockQuery);
      when(mockQuery.where('leido', isEqualTo: false)).thenReturn(mockQuery);

      when(mockQuery.get()).thenAnswer((_) async => mockSnapshot);
      when(mockSnapshot.docs).thenReturn([mockDocSnapshot]);
      when(mockDocSnapshot.reference).thenReturn(mockDocRef);

      // 2. ACT
      await viewModel.marcarTodasComoLeidas();

      // 3. ASSERT
      verify(mockBatch.update(mockDocRef, {'leido': true})).called(1);
      verify(mockBatch.commit()).called(1);
      expect(viewModel.noLeidas, 0);
    });
  });
}
