import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:sos_mascotas/vista/reportes/pantalla_detalle_reporte.dart';

void main() {
  group('PantallaDetalleReporte Tests', () {
    const String testUrl = 'https://ejemplo.com/perro.jpg';
    const String testTitulo = 'Detalle de Imagen';

    testWidgets('Debe renderizar el título y la estructura básica', (
      tester,
    ) async {
      // mockNetworkImagesFor intercepta las llamadas HTTP de Image.network
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          const MaterialApp(
            home: PantallaDetalleReporte(
              imagenUrl: testUrl,
              titulo: testTitulo,
            ),
          ),
        ),
      );

      // 1. Verificar que aparece el título en el AppBar
      expect(find.text(testTitulo), findsOneWidget);

      // 2. Verificar que hay un Scaffold con fondo negro
      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsOneWidget);
      final scaffold = tester.widget<Scaffold>(scaffoldFinder);
      expect(scaffold.backgroundColor, Colors.black);
    });

    testWidgets('Debe contener un InteractiveViewer para el zoom', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          const MaterialApp(
            home: PantallaDetalleReporte(
              imagenUrl: testUrl,
              titulo: testTitulo,
            ),
          ),
        ),
      );

      // Verificar que la imagen está dentro de un InteractiveViewer
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('Debe usar el Hero tag correcto para la animación', (
      tester,
    ) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          const MaterialApp(
            home: PantallaDetalleReporte(
              imagenUrl: testUrl,
              titulo: testTitulo,
            ),
          ),
        ),
      );

      // Buscar el widget Hero
      final heroFinder = find.byType(Hero);
      expect(heroFinder, findsOneWidget);

      // Verificar que el 'tag' del Hero coincida con la URL (como está en tu código)
      final heroWidget = tester.widget<Hero>(heroFinder);
      expect(heroWidget.tag, testUrl);
    });

    testWidgets('Muestra la imagen correctamente', (tester) async {
      await mockNetworkImagesFor(
        () => tester.pumpWidget(
          const MaterialApp(
            home: PantallaDetalleReporte(
              imagenUrl: testUrl,
              titulo: testTitulo,
            ),
          ),
        ),
      );

      // Verificar que el widget Image existe
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      // Verificar que la imagen usa BoxFit.contain
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.fit, BoxFit.contain);
    });
  });
}
