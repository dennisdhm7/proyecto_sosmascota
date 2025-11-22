import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sos_mascotas/vistamodelo/comentarios/comentarios_viewmodel.dart';
import 'package:sos_mascotas/modelo/comentario_model.dart';

// ✅ CORRECCIÓN: El import del archivo generado DEBE ir aquí arriba, junto a los demás
import 'comentarios_viewmodel_test.mocks.dart';

// -------------------------------------------------------------------------
// 1. DEFINICIÓN DE TIPOS (Ahora sí, después de los imports)
// -------------------------------------------------------------------------
typedef CollectionReferenceMap = CollectionReference<Map<String, dynamic>>;
typedef QueryMap = Query<Map<String, dynamic>>;
typedef QuerySnapshotMap = QuerySnapshot<Map<String, dynamic>>;
typedef QueryDocumentSnapshotMap = QueryDocumentSnapshot<Map<String, dynamic>>;

// -------------------------------------------------------------------------
// 2. GENERACIÓN DE MOCKS
// -------------------------------------------------------------------------
@GenerateMocks([
  FirebaseFirestore,
  CollectionReferenceMap,
  QueryMap,
  QuerySnapshotMap,
  QueryDocumentSnapshotMap,
])
void main() {
  late ComentariosViewModel viewModel;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReferenceMap mockCollection;
  late MockQueryMap mockQuery;
  late MockQuerySnapshotMap mockSnapshot;
  late MockQueryDocumentSnapshotMap mockDoc;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReferenceMap();
    mockQuery = MockQueryMap();
    mockSnapshot = MockQuerySnapshotMap();
    mockDoc = MockQueryDocumentSnapshotMap();

    viewModel = ComentariosViewModel(firestore: mockFirestore);
  });

  group('ComentariosViewModel', () {
    test(
      'obtenerComentarios debe emitir una lista de Comentarios desde Firestore',
      () {
        // 1. ARRANGE

        // firestore.collection(...) -> retorna mockCollection
        when(
          mockFirestore.collection('comentarios'),
        ).thenReturn(mockCollection);

        // .orderBy(...) -> retorna mockQuery
        when(
          mockCollection.orderBy('fecha', descending: true),
        ).thenReturn(mockQuery);

        // .snapshots() -> retorna un Stream que emite nuestro mockSnapshot
        when(
          mockQuery.snapshots(),
        ).thenAnswer((_) => Stream.value(mockSnapshot));

        // Configuramos el Snapshot para que contenga 1 documento falso
        when(mockSnapshot.docs).thenReturn([mockDoc]);
        when(mockDoc.id).thenReturn('comentario_1');
        when(mockDoc.data()).thenReturn({
          'texto': 'Hola mundo',
          'autor': 'Juan',
          'uid': 'user123',
          // Agrega campos requeridos si tu modelo Comentario explota por nulos
          'fecha': Timestamp.now(),
          'likes': [],
          'dislikes': [],
          'shares': 0,
        });

        // 2. ACT & ASSERT
        // Esperamos que el stream emita una lista con 1 elemento
        expect(
          viewModel.obtenerComentarios(),
          emits(
            isA<List<Comentario>>().having((list) => list.length, 'length', 1),
          ),
        );
      },
    );
  });
}
