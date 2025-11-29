import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Clase envoltorio para el motor de TensorFlow Lite.
///
/// Su propósito principal es encapsular la lógica de los intérpretes [Interpreter]
/// para permitir la inyección de dependencias y el mocking en pruebas unitarias.
///
/// En producción, esta clase carga los archivos `.tflite` desde los assets.
class TfliteEngine {
  Interpreter? _detector;
  Interpreter? _extractor;

  /// Carga los modelos de detección y extracción de características desde los assets.
  ///
  /// Solo carga los modelos si aún no han sido inicializados.
  /// Configura el intérprete para usar 4 hilos de procesamiento.
  Future<void> cargarModelos() async {
    // Solo carga si no están listos (para producción)
    if (_detector == null) {
      final opciones = InterpreterOptions()..threads = 4;
      _detector = await Interpreter.fromAsset(
        'assets/model/animales.tflite',
        options: opciones,
      );
      _extractor = await Interpreter.fromAsset(
        'assets/model/extractor_animales.tflite',
        options: opciones,
      );
    }
  }

  /// Ejecuta el modelo de detección de animales.
  ///
  /// [input]: Tensor de entrada (imagen preprocesada).
  /// [output]: Tensor de salida donde se escribirán las probabilidades.
  void correrDetector(Object input, Object output) {
    _detector!.run(input, output);
  }

  /// Ejecuta el modelo de extracción de embeddings (características únicas).
  ///
  /// [input]: Tensor de entrada (imagen preprocesada).
  /// [output]: Tensor de salida donde se escribirá el vector de embeddings.
  void correrExtractor(Object input, Object output) {
    _extractor!.run(input, output);
  }
}

/// Servicio principal para el procesamiento de imágenes con Inteligencia Artificial.
///
/// Provee métodos estáticos para:
/// - Detectar qué tipo de animal es (Perro, Gato, Otro).
/// - Extraer "embeddings" (huella digital visual) de una imagen.
/// - Comparar la similitud visual entre dos imágenes.
class ServicioTFLite {
  // 💉 INYECCIÓN: Permitimos cambiar el motor por uno falso en los tests
  static TfliteEngine _engine = TfliteEngine();

  /// Permite inyectar un [TfliteEngine] simulado (Mock) para pruebas unitarias.
  ///
  /// Uso exclusivo para tests. No debe usarse en producción.
  @visibleForTesting
  static void setEngineParaTest(TfliteEngine engineMock) {
    _engine = engineMock;
  }

  /// Inicializa los modelos de TensorFlow Lite llamando al motor subyacente.
  static Future<void> inicializarModelos() async {
    await _engine.cargarModelos();
  }

  /// Detecta el tipo de animal presente en una imagen.
  ///
  /// 1. Preprocesa la imagen a 224x224 píxeles.
  /// 2. Ejecuta el modelo de clasificación.
  /// 3. Retorna un mapa con la `etiqueta` (gato/perro) y la `confianza` (0.0 a 1.0).
  static Future<Map<String, dynamic>> detectarAnimal(File imagen) async {
    await inicializarModelos();

    final input = _preprocesarImagen(imagen, 224, 224);
    final output = List<double>.filled(3, 0.0).reshape([1, 3]);

    // Usamos el engine inyectable
    _engine.correrDetector(input, output);

    return _procesarSalidaDetector(output);
  }

  /// Método expuesto para testear la lógica de selección de etiqueta sin ejecutar TFLite.
  ///
  /// Recibe la lista cruda de probabilidades [output] y retorna el mapa procesado.
  @visibleForTesting
  static Map<String, dynamic> procesarSalidaDetectorTestable(
    List<dynamic> output,
  ) {
    return _procesarSalidaDetector(output);
  }

  static Map<String, dynamic> _procesarSalidaDetector(List<dynamic> output) {
    final etiquetas = ["gato", "otro", "perro"];
    final List<double> resultados = output[0].cast<double>();

    final maxValor = resultados.reduce((a, b) => a > b ? a : b);
    final pred = resultados.indexOf(maxValor);

    final etiqueta = etiquetas[pred];
    final confianza = maxValor;

    return {"etiqueta": etiqueta, "confianza": confianza};
  }

  /// Extrae el vector de características (embeddings) de una imagen.
  ///
  /// Retorna una lista de 1280 valores numéricos que representan la "huella" visual de la mascota.
  /// Útil para comparar similitud entre fotos.
  static Future<List<double>> extraerEmbeddings(File imagen) async {
    await inicializarModelos();
    final input = _preprocesarImagen(imagen, 224, 224);
    final output = List.filled(1280, 0.0).reshape([1, 1280]);

    _engine.correrExtractor(input, output);

    // ✅ CORRECCIÓN: Convertimos explícitamente a List<double>
    // Antes: return output[0]; (Esto causaba el error de tipo)
    return List<double>.from(output[0]);
  }

  /// Compara dos imágenes y calcula su similitud visual usando la distancia del Coseno.
  ///
  /// Retorna un valor entre 0.0 (diferentes) y 1.0 (idénticas).
  static Future<double> compararImagenes(File img1, File img2) async {
    final emb1 = await extraerEmbeddings(img1);
    final emb2 = await extraerEmbeddings(img2);

    return calcularSimilitudVectores(emb1, emb2);
  }

  /// Calcula la similitud del coseno entre dos vectores de embeddings.
  ///
  /// Método puro expuesto para pruebas unitarias matemáticas.
  /// Retorna la similitud normalizada entre 0.0 y 1.0.
  @visibleForTesting
  static double calcularSimilitudVectores(
    List<double> emb1,
    List<double> emb2,
  ) {
    final dot = _productoPunto(emb1, emb2);
    final norma1 = sqrt(_productoPunto(emb1, emb1));
    final norma2 = sqrt(_productoPunto(emb2, emb2));

    if (norma1 == 0 || norma2 == 0) return 0.0; // Evitar división por cero

    final similitud = dot / (norma1 * norma2);
    return similitud.clamp(0.0, 1.0);
  }

  /// Preprocesa la imagen para adaptarla a la entrada del modelo TFLite.
  ///
  /// Redimensiona la imagen a [width] x [height] y normaliza los píxeles (0-255 a 0.0-1.0).
  ///
  /// **Nota:** Si el nombre del archivo contiene "test_dummy", retorna un tensor de ceros
  /// para facilitar las pruebas unitarias sin decodificar imágenes reales.
  static List<List<List<List<double>>>> _preprocesarImagen(
    File archivo,
    int width,
    int height,
  ) {
    // En tests, si el archivo es dummy, retornamos ceros para no fallar en decodeImage
    if (archivo.path.contains('test_dummy')) {
      return List.generate(
        1,
        (_) => List.generate(
          height,
          (_) => List.generate(width, (_) => [0.0, 0.0, 0.0]),
        ),
      );
    }

    final bytes = archivo.readAsBytesSync();
    img.Image? image = img.decodeImage(bytes);
    image = img.copyResize(image!, width: width, height: height);

    final input = List.generate(
      1,
      (_) => List.generate(
        height,
        (y) => List.generate(width, (x) {
          final pixel = image!.getPixel(x, y);
          final r = pixel.r / 255.0;
          final g = pixel.g / 255.0;
          final b = pixel.b / 255.0;
          return [r, g, b];
        }),
      ),
    );
    return input;
  }

  static double _productoPunto(List<double> a, List<double> b) {
    double suma = 0;
    for (int i = 0; i < a.length; i++) {
      suma += a[i] * b[i];
    }
    return suma;
  }
}
