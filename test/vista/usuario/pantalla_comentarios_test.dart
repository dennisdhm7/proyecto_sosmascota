import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_mascotas/vista/usuario/pantalla_comentarios.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseStorage fakeStorage;
  late MockFirebaseAuth fakeAuth;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    fakeStorage = MockFirebaseStorage();

    fakeAuth = MockFirebaseAuth(
      mockUser: MockUser(
        uid: "user123",
        email: "test@test.com",
        displayName: "Tester",
      ),
      signedIn: true,
    );

    // Crear usuario
    await fakeFirestore.collection("usuarios").doc("user123").set({
      "nombre": "Christian",
      "apellido": "Hinojosa",
      "guardados": [],
    });

    // Insertar 1 comentario inicial
    await fakeFirestore.collection("comentarios").add({
      "texto": "Primer comentario",
      "autor": "Christian Hinojosa",
      "uid": "user123",
      "fecha": DateTime.now(),
      "mediaUrl": null,
      "mediaType": null,
      "likes": [],
      "dislikes": [],
      "shares": 0,
    });
  });

  Widget buildTestApp() {
    return MaterialApp(
      home: PantallaComentarios(
        firestore: fakeFirestore,
        storage: fakeStorage,
        auth: fakeAuth,
        repliesBuilder: (id, author) =>
            Scaffold(appBar: AppBar(title: const Text('Respuestas'))),
      ),
    );
  }

  // ---------------------------------------------------------
  // 1. Renderiza pantalla sin errores
  // ---------------------------------------------------------
  testWidgets("Renderiza pantalla de comentarios", (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text("Comentarios"), findsOneWidget);
  });

  // ---------------------------------------------------------
  // 2. Muestra lista de comentarios
  // ---------------------------------------------------------
  testWidgets("Carga y muestra comentarios desde Firestore", (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text("Primer comentario"), findsOneWidget);
  });

  // ---------------------------------------------------------
  // 3. Dar Like a un comentario
  // ---------------------------------------------------------
  testWidgets("Usuario puede dar Like a comentario", (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: find.text('Primer comentario'),
      matching: find.byType(Card),
    );
    final likeBtn = find.descendant(
      of: card,
      matching: find.byIcon(Icons.favorite_border),
    );
    expect(likeBtn, findsOneWidget);

    await tester.tap(likeBtn);
    await tester.pump(const Duration(milliseconds: 300));

    // El botón debe cambiar a "liked"
    final likedBtn = find.descendant(
      of: card,
      matching: find.byIcon(Icons.favorite),
    );
    expect(likedBtn, findsOneWidget);
  });

  // ---------------------------------------------------------
  // 4. Guardar comentario
  // ---------------------------------------------------------
  testWidgets("Guardar comentario en favoritos", (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: find.text('Primer comentario'),
      matching: find.byType(Card),
    );
    final bookmarkBtn = find.descendant(
      of: card,
      matching: find.byIcon(Icons.bookmark_border),
    );
    expect(bookmarkBtn, findsOneWidget);

    await tester.tap(bookmarkBtn);
    await tester.pump();

    // Icono debe cambiar
    final bookmarked = find.descendant(
      of: card,
      matching: find.byIcon(Icons.bookmark),
    );
    expect(bookmarked, findsOneWidget);
  });

  // ---------------------------------------------------------
  // 5. Enviar comentario nuevo
  // ---------------------------------------------------------
  testWidgets("Enviar comentario nuevo", (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final input = find.byType(TextField);
    expect(input, findsOneWidget);

    await tester.enterText(input, "Nuevo comentario");
    await tester.pump();

    final sendBtn = find.byIcon(Icons.send);
    await tester.tap(sendBtn);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text("Nuevo comentario"), findsOneWidget);
  });

  // ---------------------------------------------------------
  // 6. Eliminar comentario propio
  // ---------------------------------------------------------
  testWidgets("Eliminar comentario propio", (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: find.text('Primer comentario'),
      matching: find.byType(Card),
    );
    final menu = find.descendant(
      of: card,
      matching: find.byIcon(Icons.more_vert),
    );
    expect(menu, findsOneWidget);

    await tester.tap(menu);
    await tester.pumpAndSettle();

    await tester.tap(find.text("Eliminar"));
    await tester.pumpAndSettle();

    expect(find.text("Comentario eliminado"), findsOneWidget);
  });

  // ---------------------------------------------------------
  // 7. Abrir pantalla de respuestas
  // ---------------------------------------------------------
  testWidgets("Navegar a pantalla de respuestas", (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: find.text('Primer comentario'),
      matching: find.byType(Card),
    );
    final commentBtn = find.descendant(
      of: card,
      matching: find.byIcon(Icons.comment),
    );

    expect(commentBtn, findsOneWidget);

    await tester.tap(commentBtn);
    await tester.pumpAndSettle();

    // La RepliesPage tiene un AppBar con el título “Respuestas”
    expect(find.text("Respuestas"), findsOneWidget);
  });
}
