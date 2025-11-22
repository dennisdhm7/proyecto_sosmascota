import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sos_mascotas/vista/chat/pantalla_chats_activos.dart';

// Usamos los mocks generados para PantallaChat (son los mismos)
import 'pantalla_chat_test.mocks.dart';

// Definimos Typedefs para evitar errores
typedef CollectionReferenceMap = CollectionReference<Map<String, dynamic>>;
typedef QueryMap = Query<Map<String, dynamic>>;
typedef QuerySnapshotMap = QuerySnapshot<Map<String, dynamic>>;
typedef QueryDocumentSnapshotMap = QueryDocumentSnapshot<Map<String, dynamic>>;
typedef DocumentReferenceMap = DocumentReference<Map<String, dynamic>>;
typedef DocumentSnapshotMap = DocumentSnapshot<Map<String, dynamic>>;

void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockUser mockUser;

  // Mocks Firestore
  late MockCollectionReferenceMap mockChatsCollection;
  late MockQueryMap mockQuery;
  late MockQuerySnapshotMap mockChatsSnapshot;
  late MockQueryDocumentSnapshotMap mockChatDoc;

  late MockCollectionReferenceMap mockUsersCollection;
  late MockDocumentReferenceMap mockUserDoc;
  late MockDocumentSnapshotMap mockUserSnapshot;

  // Mocks Mensajes
  late MockDocumentReferenceMap mockChatDocRef; // Doc del chat específico
  late MockCollectionReferenceMap mockMensajesCollection;
  late MockQueryMap mockMensajesQuery;
  late MockQuerySnapshotMap mockMensajesSnapshot;
  late MockQueryDocumentSnapshotMap mockMensajeDoc;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockUser = MockUser();

    mockChatsCollection = MockCollectionReferenceMap();
    mockQuery = MockQueryMap();
    mockChatsSnapshot = MockQuerySnapshotMap();
    mockChatDoc = MockQueryDocumentSnapshotMap();

    mockUsersCollection = MockCollectionReferenceMap();
    mockUserDoc = MockDocumentReferenceMap();
    mockUserSnapshot = MockDocumentSnapshotMap();

    mockChatDocRef = MockDocumentReferenceMap();
    mockMensajesCollection = MockCollectionReferenceMap();
    mockMensajesQuery = MockQueryMap();
    mockMensajesSnapshot = MockQuerySnapshotMap();
    mockMensajeDoc = MockQueryDocumentSnapshotMap();

    // Auth
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn("user_123");

    // 1. Query Principal: Chats del usuario
    when(mockFirestore.collection("chats")).thenReturn(mockChatsCollection);
    when(
      mockChatsCollection.where("usuarios", arrayContains: "user_123"),
    ).thenReturn(mockQuery);
    when(
      mockQuery.orderBy("fechaInicio", descending: true),
    ).thenReturn(mockQuery);

    // Datos del chat
    when(mockChatDoc.id).thenReturn("chat_ABC");
    when(mockChatDoc.data()).thenReturn({
      "publicadorId": "user_456", // Otro usuario
      "usuarioId": "user_123", // Yo
      "tipo": "reporte",
      "reporteId": "rep_001",
    });
    when(mockChatsSnapshot.docs).thenReturn([mockChatDoc]);
    when(
      mockQuery.snapshots(),
    ).thenAnswer((_) => Stream.value(mockChatsSnapshot));

    // 2. FutureBuilder: Datos del otro usuario
    when(mockFirestore.collection("usuarios")).thenReturn(mockUsersCollection);
    when(mockUsersCollection.doc("user_456")).thenReturn(mockUserDoc);
    when(mockUserDoc.get()).thenAnswer((_) async => mockUserSnapshot);
    when(
      mockUserSnapshot.data(),
    ).thenReturn({"nombre": "Maria Lopez", "fotoPerfil": ""});

    // 3. StreamBuilder interno: Último mensaje
    // Aquí necesitamos navegar desde la referencia del documento del chat
    // Como el código hace: fs.collection("chats").doc(chat.id).collection("mensajes")
    // Ya mockeamos collection("chats"), ahora mockeamos .doc("chat_ABC")

    when(mockChatsCollection.doc("chat_ABC")).thenReturn(mockChatDocRef);
    when(
      mockChatDocRef.collection("mensajes"),
    ).thenReturn(mockMensajesCollection);
    when(
      mockMensajesCollection.orderBy("fechaEnvio", descending: true),
    ).thenReturn(mockMensajesQuery);
    when(mockMensajesQuery.limit(1)).thenReturn(mockMensajesQuery);

    // Datos del mensaje
    when(mockMensajeDoc.data()).thenReturn({
      "texto": "Hola, ¿está disponible?",
      "fechaEnvio": Timestamp.now(),
    });
    when(mockMensajesSnapshot.docs).thenReturn([mockMensajeDoc]);
    when(
      mockMensajesQuery.snapshots(),
    ).thenAnswer((_) => Stream.value(mockMensajesSnapshot));
  });

  Future<void> cargarPantalla(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: PantallaChatsActivos(
          firebaseAuth: mockAuth,
          firestore: mockFirestore,
        ),
      ),
    );
  }

  testWidgets('🟢 Debe mostrar lista de chats con nombre y último mensaje', (
    WidgetTester tester,
  ) async {
    await cargarPantalla(tester);
    await tester
        .pumpAndSettle(); // Esperar a que todos los Future/Stream resuelvan

    // Verificar Título
    expect(find.text("Mis Chats"), findsOneWidget);

    // Verificar Nombre del otro usuario (Maria Lopez)
    expect(find.text("Maria Lopez"), findsOneWidget);

    // Verificar Último mensaje
    expect(find.text("Hola, ¿está disponible?"), findsOneWidget);
  });
}
