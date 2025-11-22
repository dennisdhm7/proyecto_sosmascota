import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sos_mascotas/vista/chat/pantalla_chat.dart';

import 'pantalla_chat_test.mocks.dart';

typedef CollectionReferenceMap = CollectionReference<Map<String, dynamic>>;
typedef DocumentReferenceMap = DocumentReference<Map<String, dynamic>>;
typedef QueryMap = Query<Map<String, dynamic>>;
typedef QuerySnapshotMap = QuerySnapshot<Map<String, dynamic>>;
typedef QueryDocumentSnapshotMap = QueryDocumentSnapshot<Map<String, dynamic>>;
typedef DocumentSnapshotMap = DocumentSnapshot<Map<String, dynamic>>;

@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  User,
  CollectionReferenceMap,
  DocumentReferenceMap,
  DocumentSnapshotMap,
  QueryMap,
  QuerySnapshotMap,
  QueryDocumentSnapshotMap,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockUser mockUser;

  late MockCollectionReferenceMap mockCollection;
  late MockDocumentReferenceMap mockDoc;
  late MockDocumentSnapshotMap mockDocSnapshot;

  late MockCollectionReferenceMap mockSubCollection;
  late MockQueryMap mockQuery;
  late MockQuerySnapshotMap mockQuerySnapshot;
  late MockQueryDocumentSnapshotMap mockMessageDoc;

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockUser = MockUser();

    mockCollection = MockCollectionReferenceMap();
    mockDoc = MockDocumentReferenceMap();
    mockDocSnapshot = MockDocumentSnapshotMap();
    mockSubCollection = MockCollectionReferenceMap();
    mockQuery = MockQueryMap();
    mockQuerySnapshot = MockQuerySnapshotMap();
    mockMessageDoc = MockQueryDocumentSnapshotMap();

    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn("user_123");

    when(mockFirestore.collection(any)).thenReturn(mockCollection);
    when(mockCollection.doc(any)).thenReturn(mockDoc);
    when(mockDoc.get()).thenAnswer((_) async => mockDocSnapshot);
    when(mockDocSnapshot.exists).thenReturn(true);
    when(mockDocSnapshot.data()).thenReturn({"nombre": "Firulais Perdido"});

    when(mockDoc.collection("mensajes")).thenReturn(mockSubCollection);
    when(
      mockSubCollection.orderBy("fechaEnvio", descending: true),
    ).thenReturn(mockQuery);

    when(mockMessageDoc.data()).thenReturn({
      "texto": "Hola, lo vi en el parque",
      "emisorId": "otro_user",
      "leido": false,
    });
    when(mockQuerySnapshot.docs).thenReturn([mockMessageDoc]);
    when(
      mockQuery.snapshots(),
    ).thenAnswer((_) => Stream.value(mockQuerySnapshot));
  });

  Future<void> cargarPantalla(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: PantallaChat(
          chatId: "chat_123",
          reporteId: "reporte_abc",
          tipo: "reporte",
          publicadorId: "pub_456",
          usuarioId: "user_123",
          firebaseAuth: mockAuth,
          firebaseFirestore: mockFirestore,
        ),
      ),
    );
  }

  testWidgets('🟢 Debe mostrar título del reporte y lista de mensajes', (
    WidgetTester tester,
  ) async {
    await cargarPantalla(tester);
    await tester.pumpAndSettle();

    expect(find.text("Firulais Perdido"), findsOneWidget);
    expect(find.text("Hola, lo vi en el parque"), findsOneWidget);
  });

  testWidgets('🔵 Al enviar mensaje, se agrega a Firestore', (
    WidgetTester tester,
  ) async {
    when(mockSubCollection.add(any)).thenAnswer((_) async => mockDoc);

    await cargarPantalla(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), "Voy para allá");
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send_rounded));

    // ✅ CORRECCIÓN AQUÍ:
    // Esperamos 300ms para que el timer de 200ms del código fuente termine
    await tester.pump(const Duration(milliseconds: 300));

    verify(
      mockSubCollection.add(
        argThat(
          predicate((Map<String, dynamic> data) {
            return data['texto'] == 'Voy para allá' &&
                data['emisorId'] == 'user_123';
          }),
        ),
      ),
    ).called(1);
  });
}
