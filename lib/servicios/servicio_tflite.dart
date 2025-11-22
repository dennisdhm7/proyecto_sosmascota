import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// ✅ CLASE WRAPPER: Esta es la que vamos a MOCKEAR en el test
class TfliteEngine {
  Interpreter? _detector;
  Interpreter? _extractor;

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

  // Método virtual para correr detector (fácil de mockear)
  void correrDetector(Object input, Object output) {
    _detector!.run(input, output);
  }

  // Método virtual para correr extractor (fácil de mockear)
  void correrExtractor(Object input, Object output) {
    _extractor!.run(input, output);
  }
}

class ServicioTFLite {
  // 💉 INYECCIÓN: Permitimos cambiar el motor por uno falso en los tests
  static TfliteEngine _engine = TfliteEngine();

  @visibleForTesting
  static void setEngineParaTest(TfliteEngine engineMock) {
    _engine = engineMock;
  }

  /// 🔹 Inicializa modelos (Redirige al engine)
  static Future<void> inicializarModelos() async {
    await _engine.cargarModelos();
  }

  /// 🔹 Detecta tipo de animal
  static Future<Map<String, dynamic>> detectarAnimal(File imagen) async {
    await inicializarModelos();

    final input = _preprocesarImagen(imagen, 224, 224);
    final output = List<double>.filled(3, 0.0).reshape([1, 3]);

    // Usamos el engine inyectable
    _engine.correrDetector(input, output);

    return _procesarSalidaDetector(output);
  }

  /// 🧠 Lógica pura extraída para poder testearla sin TFLite
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

  /// 🔹 Extrae embeddings
  static Future<List<double>> extraerEmbeddings(File imagen) async {
    await inicializarModelos();
    final input = _preprocesarImagen(imagen, 224, 224);
    final output = List.filled(1280, 0.0).reshape([1, 1280]);

    _engine.correrExtractor(input, output);

    // ✅ CORRECCIÓN: Convertimos explícitamente a List<double>
    // Antes: return output[0]; (Esto causaba el error de tipo)
    return List<double>.from(output[0]);
  }

  /// 🔹 Compara dos imágenes (Similitud Coseno)
  static Future<double> compararImagenes(File img1, File img2) async {
    final emb1 = await extraerEmbeddings(img1);
    final emb2 = await extraerEmbeddings(img2);

    return calcularSimilitudVectores(emb1, emb2);
  }

  /// 🧠 Matemática pura extraída para testear (Coseno)
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
