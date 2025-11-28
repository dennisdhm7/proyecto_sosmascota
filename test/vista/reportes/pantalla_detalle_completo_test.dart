import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:sos_mascotas/vista/reportes/pantalla_detalle_completo.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;

  setUp(() {
    // 1. Inicializamos las bases de datos falsas
    fakeFirestore = FakeFirebaseFirestore();
    mockUser = MockUser(uid: 'usuario_logueado', email: 'yo@test.com');
    mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
  });

  // Datos de ejemplo para un reporte
  final reporteData = {
    "id": "reporte_123",
    "usuarioId": "dueno_123", // ID diferente al usuario logueado
    "nombre": "Fido",
    "tipo": "Perro",
    "raza": "Labrador",
    "estado": "PERDIDO",
    "descripcion": "Se perdió en el parque",
    "direccion": "Av. Bolognesi 123",
    "recompensa": "100.00",
    "latitud": -18.0,
    "longitud": -70.0,
    "fechaPerdida": "20/11/2025",
    "horaPerdida": "10:00",
    "fotos": ["http://foto.com/perro.jpg"],
  };

  Future<void> cargarPantalla(
    WidgetTester tester, {
    required Map<String, dynamic> data,
    required String tipo,
  }) async {
    // Envolvemos en mockNetworkImagesFor para que Image.network no falle
    await mockNetworkImagesFor(
      () => tester.pumpWidget(
        MaterialApp(
          home: PantallaDetalleCompleto(
            data: data,
            tipo: tipo,
            firestore: fakeFirestore, // Inyectamos la DB falsa
            auth: mockAuth, // Inyectamos Auth falso
          ),
        ),
      ),
    );
  }

  group('PantallaDetalleCompleto Test', () {
    testWidgets('Renderiza información básica de un Reporte correctamente', (
      tester,
    ) async {
      await cargarPantalla(tester, data: reporteData, tipo: 'reporte');
      await tester.pumpAndSettle(); // Esperar cargas asíncronas

      // Verificar Título de AppBar
      expect(find.text("Detalle del Reporte"), findsOneWidget);

      // Verificar Nombre y Raza
      expect(find.text("Fido"), findsOneWidget);
      expect(find.text("Perro • Labrador"), findsOneWidget);

      // Verificar Recompensa (Solo aparece en reportes)
      expect(find.text("Recompensa ofrecida"), findsOneWidget);
      expect(find.text("S/. 100.00"), findsOneWidget);

      // Verificar Estado (Debe ser rojo para PERDIDO)
      final estadoFinder = find.text("PERDIDO");
      expect(estadoFinder, findsOneWidget);

      // Verificar color del contenedor de estado (buscamos el widget padre)
      final containerEstado = tester.widget<Container>(
        find.ancestor(of: estadoFinder, matching: find.byType(Container)).first,
      );
      final decoration = containerEstado.decoration as BoxDecoration;
      expect(decoration.color, Colors.red.shade600);
    });

    testWidgets(
      'Carga y muestra información del usuario publicador desde Firestore',
      (tester) async {
        // 1. Preparamos la DB falsa con el usuario dueño del reporte
        await fakeFirestore.collection('usuarios').doc('dueno_123').set({
          'nombre': 'Juan Perez',
          'correo': 'juan@gmail.com',
          'fotoPerfil': 'http://foto.com/juan.jpg',
        });

        // 2. Cargamos la pantalla
        await cargarPantalla(tester, data: reporteData, tipo: 'reporte');

        // Esperamos a que el Future _cargarUsuario termine
        await tester.pumpAndSettle();

        // 3. Verificamos que aparezca el nombre cargado
        expect(find.text("Información de contacto"), findsOneWidget);
        expect(find.text("Juan Perez"), findsOneWidget);
        expect(find.text("juan@gmail.com"), findsOneWidget);
      },
    );

    testWidgets('Muestra botón "Contactar" si el usuario NO es el dueño', (
      tester,
    ) async {
      // Usuario logueado es 'usuario_logueado', dueño es 'dueno_123'
      await fakeFirestore.collection('usuarios').doc('dueno_123').set({
        'nombre': 'Juan Perez',
      });

      await cargarPantalla(tester, data: reporteData, tipo: 'reporte');
      await tester.pumpAndSettle();

      // Verificar que existe el botón de chat
      expect(find.text("Contactar"), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });

    testWidgets('NO muestra botón "Contactar" si el usuario ES el dueño', (
      tester,
    ) async {
      // Cambiamos el usuario logueado para que coincida con el dueño del reporte
      mockUser = MockUser(uid: 'dueno_123', email: 'yo@test.com');
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

      // Insertamos data de usuario
      await fakeFirestore.collection('usuarios').doc('dueno_123').set({
        'nombre': 'Yo Mismo',
      });

      await cargarPantalla(tester, data: reporteData, tipo: 'reporte');
      await tester.pumpAndSettle();

      // El botón NO debe existir
      expect(find.text("Contactar"), findsNothing);
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
    });

    testWidgets('Muestra avistamientos relacionados si existen', (
      tester,
    ) async {
      // 1. Crear un avistamiento en la DB falsa vinculado a este reporte
      await fakeFirestore.collection('avistamientos').add({
        'reporteId': 'reporte_123',
        'descripcion': 'Lo vi corriendo',
        'direccion': 'Cerca al mercado',
        'foto': 'http://foto.com/visto.jpg',
        'latitud': -18.0,
        'longitud': -70.0,
      });

      await cargarPantalla(tester, data: reporteData, tipo: 'reporte');
      await tester.pumpAndSettle();

      // Verificar sección
      expect(find.text("Avistamientos relacionados"), findsOneWidget);

      // Verificar contenido del avistamiento cargado
      expect(find.text("Lo vi corriendo"), findsOneWidget);
      expect(find.text("Cerca al mercado"), findsOneWidget);
    });

    testWidgets('Renderiza correctamente como Avistamiento (Verde)', (
      tester,
    ) async {
      final avistamientoData = {
        "id": "avist_999",
        "usuarioId": "otro_user",
        "tipo": "Gato",
        "raza": "Mestizo",
        "estado": "AVISTADO",
        "descripcion": "Gato blanco",
        "direccion": "Plaza de armas",
        "fechaAvistamiento": "21/11/2025",
        "foto": "http://foto.com/gato.jpg",
        "latitud": -18.0,
        "longitud": -70.0,
      };

      await cargarPantalla(
        tester,
        data: avistamientoData,
        tipo: 'avistamiento',
      );
      await tester.pumpAndSettle();

      expect(find.text("Detalle del Avistamiento"), findsOneWidget);
      expect(find.text("AVISTADO"), findsOneWidget);

      // Verificar color Verde
      final estadoFinder = find.text("AVISTADO");
      final containerEstado = tester.widget<Container>(
        find.ancestor(of: estadoFinder, matching: find.byType(Container)).first,
      );
      final decoration = containerEstado.decoration as BoxDecoration;
      expect(decoration.color, Colors.green.shade600);

      // Verificar que NO hay recompensa
      expect(find.text("Recompensa ofrecida"), findsNothing);
    });
    testWidgets('Muestra placeholder (Icons.pets) cuando NO hay foto', (
      tester,
    ) async {
      // 1. Preparamos data SIN fotos
      final dataSinFoto = {
        "id": "reporte_sin_foto",
        "usuarioId": "user_1",
        "tipo": "Perro",
        "estado": "PERDIDO",
        "fotos": [], // 👈 Lista vacía para forzar el else
        "detalles": "Sin foto",
      };

      // 2. Cargamos la pantalla
      await cargarPantalla(tester, data: dataSinFoto, tipo: 'reporte');
      await tester.pumpAndSettle();

      // 3. Verificamos que se muestre el contenedor gris con el ícono de mascota
      expect(find.byIcon(Icons.pets), findsOneWidget);
      // Aseguramos que NO intente buscar una imagen de red
      expect(find.byType(Image), findsNothing);
    });
  });
}
