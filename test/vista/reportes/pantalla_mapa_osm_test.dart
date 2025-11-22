import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:sos_mascotas/vista/reportes/pantalla_mapa_osm.dart';

// Generar Mocks
@GenerateMocks([http.Client])
import 'pantalla_mapa_osm_test.mocks.dart';

void main() {
  late MockClient mockClient;

  setUp(() {
    mockClient = MockClient();
  });

  Future<void> cargarPantalla(
    WidgetTester tester, {
    bool esAvistamiento = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await mockNetworkImagesFor(
      () => tester.pumpWidget(
        MaterialApp(
          home: PantallaMapaOSM(
            esAvistamiento: esAvistamiento,
            httpClient: mockClient,
          ),
        ),
      ),
    );
  }

  group('PantallaMapaOSM Tests', () {
    testWidgets('Renderiza correctamente el título según el modo', (
      tester,
    ) async {
      await cargarPantalla(tester, esAvistamiento: false);
      expect(find.text("Seleccionar lugar de pérdida"), findsOneWidget);

      await cargarPantalla(tester, esAvistamiento: true);
      expect(
        find.text("Seleccionar ubicación del avistamiento"),
        findsOneWidget,
      );
    });

    testWidgets(
      'Al hacer tap en el mapa, busca dirección y muestra el distrito',
      (tester) async {
        final respuestaFalsa = {
          "display_name": "Calle Los Lirios, Pocollay, Tacna, Perú",
          "lat": "-18.0",
          "lon": "-70.2",
        };

        // ✅ CORRECCIÓN ROBUSTA: Usamos 'argThat' para aceptar CUALQUIER mapa de headers.
        // Esto evita el error de "Invalid argument" y errores de texto.
        when(
          mockClient.get(
            any,
            headers: argThat(isA<Map<String, String>>(), named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response(jsonEncode(respuestaFalsa), 200),
        );

        await cargarPantalla(tester);
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FlutterMap));

        // Esperamos suficiente tiempo para la "red"
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        expect(
          find.text("Calle Los Lirios, Pocollay, Tacna, Perú"),
          findsOneWidget,
        );
        expect(find.text("Distrito: Pocollay"), findsOneWidget);
        expect(find.text("Confirmar ubicación seleccionada"), findsOneWidget);
      },
    );

    testWidgets('Muestra error si la petición falla (Error 500)', (
      tester,
    ) async {
      // Configurar Mock para Error 500
      when(
        mockClient.get(
          any,
          headers: argThat(isA<Map<String, String>>(), named: 'headers'),
        ),
      ).thenAnswer((_) async => http.Response("Internal Server Error", 500));

      await cargarPantalla(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FlutterMap));

      // ✅ AUMENTO DE TIEMPO: Damos más tiempo para asegurar que el Future complete
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Ahora sí debería aparecer el texto del 'else'
      expect(find.text("No se pudo obtener la dirección"), findsOneWidget);
    });

    testWidgets('Botón confirmar retorna los datos esperados', (tester) async {
      final respuestaFalsa = {"display_name": "Av. Bolognesi, Tacna"};

      when(
        mockClient.get(
          any,
          headers: argThat(isA<Map<String, String>>(), named: 'headers'),
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode(respuestaFalsa), 200));

      await cargarPantalla(tester);
      await tester.pumpAndSettle();

      // Seleccionar
      await tester.tap(find.byType(FlutterMap));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Confirmar
      final btnConfirmar = find.text("Confirmar ubicación seleccionada");
      await tester.ensureVisible(btnConfirmar);
      await tester.tap(btnConfirmar);
      await tester.pumpAndSettle();

      expect(find.byType(PantallaMapaOSM), findsNothing);
    });
  });
}
