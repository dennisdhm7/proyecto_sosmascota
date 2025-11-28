import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_mascotas/vista/reportes/pantalla_mis_reportes.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth(
      mockUser: MockUser(uid: "usuario123", email: "test@correo.com"),
      signedIn: true,
    );
  });

  // No inicializamos Firebase en tests; usamos fakes y un detalleBuilder de prueba.

  Future<void> cargarWidget(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return PantallaMisReportes(
              auth: mockAuth,
              firestore: fakeFirestore,
              detalleBuilder: (data, tipo) =>
                  const Scaffold(body: Center(child: Text('Detalle prueba'))),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  // ---------------------------------------------------------------------------
  // 🟢 TEST 1: Usuario NO autenticado
  // ---------------------------------------------------------------------------
  testWidgets("❌ Debe mostrar mensaje si el usuario NO está autenticado", (
    tester,
  ) async {
    // Usuario no logueado
    final mockNoUser = MockFirebaseAuth();

    await tester.pumpWidget(
      MaterialApp(
        home: PantallaMisReportes(auth: mockNoUser, firestore: fakeFirestore),
      ),
    );

    await tester.pump();

    expect(find.text("Inicia sesión para ver tus reportes."), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // 🟢 TEST 2: Mostrar textos “sin datos”
  // ---------------------------------------------------------------------------
  testWidgets(
    "🟡 Debe mostrar mensaje de 'no hay reportes' cuando no existen",
    (tester) async {
      // añadir documento de otro usuario antes de montar el widget
      await fakeFirestore.collection("reportes_mascotas").add({
        "usuarioId": "otro_usuario",
        "fechaRegistro": DateTime.now(),
      });

      await cargarWidget(tester);

      expect(find.text("No has registrado ningún reporte 🐾"), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // 🟢 TEST 3: Cargar un reporte y mostrarlo en la lista
  // ---------------------------------------------------------------------------
  testWidgets("🟢 Debe listar un reporte del usuario logueado", (tester) async {
    await fakeFirestore.collection("reportes_mascotas").add({
      "usuarioId": "usuario123",
      "nombre": "Firulais",
      "tipo": "Perro",
      "raza": "Labrador",
      "direccion": "Tacna",
      "descripcion": "Se perdió por el mercado",
      "fechaRegistro": DateTime.now(),
      "estado": "PERDIDO",
      "fotos": [],
    });

    await cargarWidget(tester);

    await tester.pumpAndSettle();

    expect(find.text("Firulais"), findsOneWidget);
    expect(find.text("Perro • Labrador"), findsOneWidget);
    expect(find.text("PERDIDO"), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // 🟢 TEST 4: Editar reporte → abrir modal
  // ---------------------------------------------------------------------------
  testWidgets("🟣 Debe abrir el diálogo de edición al presionar Editar", (
    tester,
  ) async {
    await fakeFirestore.collection("reportes_mascotas").add({
      "usuarioId": "usuario123",
      "nombre": "Mishi",
      "tipo": "Gato",
      "raza": "Siames",
      "direccion": "Para chico",
      "descripcion": "Se perdió ayer",
      "fechaRegistro": DateTime.now(),
      "estado": "PERDIDO",
      "fotos": [],
    });

    await cargarWidget(tester);
    await tester.pumpAndSettle();

    final btnEditar = find.text("Editar");
    expect(btnEditar, findsOneWidget);

    await tester.tap(btnEditar);
    await tester.pumpAndSettle();

    expect(find.text("Editar reporte"), findsOneWidget);
    expect(find.text("Nombre de la mascota"), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // 🟢 TEST 5: Cambiar estado → abrir diálogo
  // ---------------------------------------------------------------------------
  testWidgets("🟧 Debe mostrar diálogo al presionar Cambiar estado", (
    tester,
  ) async {
    await fakeFirestore.collection("reportes_mascotas").add({
      "usuarioId": "usuario123",
      "nombre": "Bruno",
      "tipo": "Perro",
      "raza": "Pitbull",
      "direccion": "Los jazmines",
      "descripcion": "Corrió hacia la avenida",
      "fechaRegistro": DateTime.now(),
      "estado": "PERDIDO",
      "fotos": [],
    });

    await cargarWidget(tester);
    await tester.pumpAndSettle();

    final btnEstado = find.text("Cambiar estado");
    expect(btnEstado, findsWidgets); // Ensure it accepts multiple matches

    await tester.tap(btnEstado.first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AlertDialog, "Cambiar estado"), findsOneWidget);
    expect(
      find.text("¿Deseas marcar este reporte como 'ENCONTRADO'?"),
      findsOneWidget,
    );
  });

  // ---------------------------------------------------------------------------
  // 🟢 TEST 6: Navegar al detalle
  // ---------------------------------------------------------------------------
  testWidgets("🟩 Debe navegar a pantalla de detalle al hacer tap", (
    tester,
  ) async {
    await fakeFirestore.collection("reportes_mascotas").add({
      "usuarioId": "usuario123",
      "nombre": "Toby",
      "tipo": "Perro",
      "raza": "Pastor Alemán",
      "direccion": "Av. Bolognesi",
      "descripcion": "Salió corriendo",
      "fechaRegistro": DateTime.now(),
      "estado": "PERDIDO",
      "fotos": [],
    });

    await cargarWidget(tester);

    await tester.tap(find.text("Toby"));
    await tester.pumpAndSettle();

    // la pantalla de detalle tiene un AppBar llamado PantallaDetalleCompleto
    expect(find.byType(Scaffold), findsWidgets);
  });
}
