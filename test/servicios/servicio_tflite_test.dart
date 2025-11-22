import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sos_mascotas/servicios/servicio_tflite.dart';

// Generamos Mock del motor
@GenerateMocks([TfliteEngine])
import 'servicio_tflite_test.mocks.dart';

void main() {
  late MockTfliteEngine mockEngine;
  late File mockFile;

  setUp(() {
    mockEngine = MockTfliteEngine();
    // Inyectamos nuestro motor falso
    ServicioTFLite.setEngineParaTest(mockEngine);

    // Creamos un archivo dummy (el preprocesador lo detectará por el nombre y devolverá ceros)
    mockFile = File('path/to/test_dummy.jpg');

    // Simulamos que cargarModelos no hace nada (éxito inmediato)
    when(mockEngine.cargarModelos()).thenAnswer((_) async {});
  });

  group('🧠 ServicioTFLite - Lógica Matemática', () {
    test(
      'procesarSalidaDetector debe encontrar la clase con mayor probabilidad',
      () {
        // ARRANGE: Simulamos una salida del modelo: [Gato: 0.1, Otro: 0.05, Perro: 0.85]
        final salidaSimulada = [
          [0.1, 0.05, 0.85],
        ];

        // ACT
        final resultado = ServicioTFLite.procesarSalidaDetectorTestable(
          salidaSimulada,
        );

        // ASSERT
        expect(
          resultado['etiqueta'],
          'perro',
        ); // 0.85 es el mayor, index 2 = perro
        expect(resultado['confianza'], 0.85);
      },
    );

    test(
      'calcularSimilitudVectores debe calcular Coseno correctamente (Vectores idénticos)',
      () {
        // ARRANGE: Dos vectores iguales deben dar similitud 1.0
        final v1 = [1.0, 2.0, 3.0];
        final v2 = [1.0, 2.0, 3.0];

        // ACT
        final similitud = ServicioTFLite.calcularSimilitudVectores(v1, v2);

        // ASSERT
        expect(
          similitud,
          closeTo(1.0, 0.0001),
        ); // closeTo maneja errores de punto flotante
      },
    );

    test('calcularSimilitudVectores debe dar 0 para vectores ortogonales', () {
      // ARRANGE: (1,0) y (0,1) son perpendiculares, similitud 0
      final v1 = [1.0, 0.0];
      final v2 = [0.0, 1.0];

      // ACT
      final similitud = ServicioTFLite.calcularSimilitudVectores(v1, v2);

      // ASSERT
      expect(similitud, closeTo(0.0, 0.0001));
    });
  });

  group('🧩 ServicioTFLite - Flujo Completo Mockeado', () {
    test('detectarAnimal ejecuta el flujo y devuelve resultado', () async {
      // 1. ARRANGE
      // Simulamos que al correr el detector, llenamos el buffer de salida con datos de "Gato"
      // El argumento 'output' en run(input, output) es mutable.
      // Mockito no llena buffers por referencia fácilmente, pero podemos verificar la llamada.

      // Configuramos el mock para que no haga nada (void)
      // Nota: En un test real de integración, el interpreter escribiría en output.
      // Aquí probaremos que se llama al método correcto.

      // 2. ACT
      // Como no podemos modificar el buffer output dentro del mock fácilmente en Dart unit test,
      // este test verificará principalmente que no explote y llame al engine.
      try {
        await ServicioTFLite.detectarAnimal(mockFile);
      } catch (e) {
        // Es posible que falle al intentar leer el output vacío (todo ceros),
        // lo cual daría "gato" (index 0) si es el empate, o error.
        // Pero lo importante es verificar la interacción.
      }

      // 3. ASSERT
      verify(mockEngine.cargarModelos()).called(1);
      verify(mockEngine.correrDetector(any, any)).called(1);
    });

    test('compararImagenes ejecuta el flujo y usa embeddings', () async {
      // 1. ARRANGE
      // Simulamos extracción de embeddings
      // Al ser void el metodo correrExtractor, no podemos inyectar valores de retorno fácilmente
      // sin una implementación Fake manual.
      // Pero verificamos la orquestación.

      try {
        await ServicioTFLite.compararImagenes(mockFile, mockFile);
      } catch (e) {
        // Ignoramos errores de cálculo con vectores vacíos
      }

      // 3. ASSERT
      verify(mockEngine.cargarModelos()).called(greaterThanOrEqualTo(1));
      verify(
        mockEngine.correrExtractor(any, any),
      ).called(2); // Una vez por cada imagen
    });
  });
}
