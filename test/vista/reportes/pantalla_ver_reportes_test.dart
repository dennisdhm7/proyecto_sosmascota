import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_mascotas/vista/reportes/pantalla_ver_reportes.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => PantallaVerReportes(
            firestore: fakeFirestore,
            detalleBuilder: (data, tipo) =>
                const Scaffold(body: Center(child: Text('Detalle prueba'))),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('Muestra AppBar y TabBar', (tester) async {
    await pumpPage(tester);

    expect(find.text('Mascotas Reportadas'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Perdidas'), findsOneWidget);
    expect(find.text('Avistamientos'), findsOneWidget);
  });

  testWidgets('Muestra mensaje vacío para reportes y avistamientos', (
    tester,
  ) async {
    await pumpPage(tester);

    // Tab inicial es 'Perdidas'
    expect(find.text('No hay mascotas perdidas 🐶'), findsOneWidget);

    // Cambiar a pestaña Avistamientos
    await tester.tap(find.text('Avistamientos'));
    await tester.pumpAndSettle();

    expect(find.text('No hay avistamientos recientes 🐱'), findsOneWidget);
  });

  testWidgets('Muestra lista con un reporte y navega al detalle', (
    tester,
  ) async {
    await fakeFirestore.collection('reportes_mascotas').add({
      'nombre': 'Rex',
      'tipo': 'Perro',
      'raza': 'Labrador',
      'direccion': 'Calle Falsa',
      'detalles': 'Se perdió en el parque',
      'fechaRegistro': DateTime.now(),
      'estado': 'PERDIDO',
      'fotos': [],
    });

    await pumpPage(tester);

    // Debe aparecer el nombre y la fila
    expect(find.text('Rex'), findsOneWidget);
    expect(find.textContaining('Perro •'), findsOneWidget);
    expect(find.text('PERDIDO'), findsOneWidget);

    // Tap sobre el card (el texto) y debe navegar al detalleBuilder
    await tester.tap(find.text('Rex'));
    await tester.pumpAndSettle();

    expect(find.text('Detalle prueba'), findsOneWidget);
  });

  testWidgets('Ver más navega al detalle', (tester) async {
    await fakeFirestore.collection('reportes_mascotas').add({
      'nombre': 'Luna',
      'tipo': 'Gato',
      'raza': 'Siamés',
      'direccion': 'Centro',
      'detalles': 'Se asustó con ruido',
      'fechaRegistro': DateTime.now(),
      'estado': 'AVISTADO',
      'fotos': [],
    });

    await pumpPage(tester);

    final verMas = find.text('Ver más');
    expect(verMas, findsOneWidget);

    await tester.tap(verMas);
    await tester.pumpAndSettle();

    expect(find.text('Detalle prueba'), findsOneWidget);
  });
}
