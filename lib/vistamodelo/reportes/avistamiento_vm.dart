import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sos_mascotas/servicios/notificacion_servicio.dart';
import 'package:sos_mascotas/servicios/servicio_tflite.dart';
import '../../modelo/avistamiento.dart';

/// Define los posibles estados de la interfaz de usuario durante operaciones asíncronas.
enum EstadoCarga { inicial, cargando, exito, error }

/// 🧱 Wrapper para aislar servicios externos y plugins.
///
/// Su propósito principal es permitir el [Mocking] de dependencias complejas
/// (como compresión de imágenes, TFLite o Notificaciones) durante las pruebas unitarias.
class AvistamientoServices {
  /// Obtiene el directorio temporal del dispositivo.
  Future<Directory> getTempDir() async => await getTemporaryDirectory();

  /// Comprime una imagen ubicada en [path] y la guarda en [targetPath].
  ///
  /// Retorna un [File] con la imagen comprimida o `null` si falla.
  Future<File?> compress(String path, String targetPath) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      path,
      targetPath,
      quality: 70,
    );
    return result != null ? File(result.path) : null;
  }

  /// Ejecuta el modelo de IA para detectar qué animal hay en el [file].
  Future<Map<dynamic, dynamic>> detectarAnimal(File file) async {
    return await ServicioTFLite.detectarAnimal(file);
  }

  /// Calcula el porcentaje de similitud visual entre dos imágenes [f1] y [f2].
  Future<double> compararImagenes(File f1, File f2) async {
    return await ServicioTFLite.compararImagenes(f1, f2);
  }

  /// Envía una notificación Push a través del servicio de notificaciones.
  Future<void> enviarPush({
    required String titulo,
    required String cuerpo,
  }) async {
    await NotificacionServicio.enviarPush(titulo: titulo, cuerpo: cuerpo);
  }
}

/// ViewModel encargado de la lógica de negocio para registrar avistamientos.
///
/// Gestiona el estado de la UI, la subida de imágenes a Firebase Storage,
/// el guardado en Firestore y la ejecución del algoritmo de coincidencia de mascotas.
class AvistamientoVM extends ChangeNotifier {
  Avistamiento avistamiento = Avistamiento();
  EstadoCarga _estado = EstadoCarga.inicial;
  String? _mensajeUsuario;

  EstadoCarga get estado => _estado;
  String? get mensajeUsuario => _mensajeUsuario;
  bool get cargando => _estado == EstadoCarga.cargando;

  // 💉 Dependencias Inyectables
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final http.Client _httpClient;
  final AvistamientoServices _services;

  /// Constructor que permite Inyección de Dependencias.
  ///
  /// Si no se proveen dependencias (producción), utiliza las instancias por defecto
  /// de Firebase y servicios reales.
  AvistamientoVM({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    http.Client? httpClient,
    AvistamientoServices? services,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _httpClient = httpClient ?? http.Client(),
       _services = services ?? AvistamientoServices();

  void setDireccion(String v) => avistamiento.direccion = v;
  void setDescripcion(String v) => avistamiento.descripcion = v;

  void limpiarMensaje() {
    _mensajeUsuario = null;
  }

  /// Actualiza los datos de geolocalización en el modelo local.
  void actualizarUbicacion({
    required String direccion,
    required String distrito,
    required double latitud,
    required double longitud,
  }) {
    avistamiento.direccion = direccion;
    avistamiento.distrito = distrito;
    avistamiento.latitud = latitud;
    avistamiento.longitud = longitud;
    notifyListeners();
  }

  // ----------------------------------------------------------------------
  // 📸 Lógica de Imágenes
  // ----------------------------------------------------------------------

  /// Comprime la imagen seleccionada para optimizar el almacenamiento.
  Future<File> _comprimirImagen(File archivo) async {
    final dir = await _services.getTempDir();
    final targetPath =
        "${dir.absolute.path}/${DateTime.now().millisecondsSinceEpoch}.jpg";

    final result = await _services.compress(archivo.absolute.path, targetPath);
    return result ?? archivo;
  }

  /// Procesa, valida y sube la foto del avistamiento.
  ///
  /// Pasos:
  /// 1. Comprime la imagen.
  /// 2. **Validación IA:** Verifica si la imagen contiene una mascota con confianza > 60%.
  /// 3. Si es válida, la sube a Firebase Storage.
  ///
  /// Retorna la URL de descarga o `null` si la validación falla.
  Future<String?> subirFoto(File archivo) async {
    try {
      _estado = EstadoCarga.cargando;
      notifyListeners();

      final comprimido = await _comprimirImagen(archivo);

      // 1. Analizar con IA (Wrapper)
      final resultado = await _services.detectarAnimal(comprimido);
      final tipo = resultado["etiqueta"];
      final confianzaVal = resultado["confianza"];
      final confianzaStr = (confianzaVal * 100).toStringAsFixed(2);

      if (tipo == "otro" || confianzaVal < 0.6) {
        _estado = EstadoCarga.error;
        _mensajeUsuario =
            "⚠️ No se detectó una mascota clara ($confianzaStr%). Intente otra foto.";
        notifyListeners();
        return null;
      }

      _mensajeUsuario = "🐾 Se detectó un $tipo ($confianzaStr%)";
      notifyListeners();

      // 2. Subir a Firebase Storage
      final uid = _auth.currentUser!.uid;
      final ref = _storage
          .ref()
          .child("avistamientos")
          .child(uid)
          .child("${DateTime.now().millisecondsSinceEpoch}.jpg");

      await ref.putFile(comprimido);
      final url = await ref.getDownloadURL();

      _estado = EstadoCarga.inicial;
      notifyListeners();
      return url;
    } catch (e) {
      _estado = EstadoCarga.error;
      _mensajeUsuario = e.toString().replaceAll("Exception: ", "");
      notifyListeners();
      return null;
    }
  }

  // ----------------------------------------------------------------------
  // 💾 Lógica de Guardado
  // ----------------------------------------------------------------------

  /// Guarda el avistamiento en Firestore y ejecuta el algoritmo de coincidencia.
  ///
  /// 1. Valida campos locales (foto, ubicación, descripción).
  /// 2. Guarda el documento en la colección `avistamientos`.
  /// 3. Busca coincidencias automáticas con reportes de mascotas perdidas.
  /// 4. Envía notificación Push global.
  ///
  /// Retorna `true` si el proceso fue exitoso.
  Future<bool> guardarAvistamiento() async {
    final errorValidacion = _validarCamposLocal();
    if (errorValidacion != null) {
      _mensajeUsuario = errorValidacion;
      _estado = EstadoCarga.error;
      notifyListeners();
      return false;
    }

    try {
      _estado = EstadoCarga.cargando;
      notifyListeners();

      final uid = _auth.currentUser!.uid;
      final docRef = _firestore.collection("avistamientos").doc();

      avistamiento.id = docRef.id;
      avistamiento.usuarioId = uid;
      avistamiento.direccion = avistamiento.direccion.trim();
      avistamiento.distrito = avistamiento.distrito.trim();

      await docRef.set(
        avistamiento.toMap()
          ..addAll({"fechaRegistro": FieldValue.serverTimestamp()}),
      );

      // 2. Lógica de Negocio: Buscar coincidencia
      await _buscarCoincidenciaConReportes(avistamiento);

      // 3. Notificación (Wrapper)
      await _services.enviarPush(
        titulo: "Nuevo avistamiento 👀",
        cuerpo: "Se ha registrado un nuevo avistamiento de mascota.",
      );

      _mensajeUsuario = "✅ Avistamiento guardado correctamente.";
      _estado = EstadoCarga.exito;
      notifyListeners();
      return true;
    } catch (e) {
      _mensajeUsuario = "❌ Error al guardar: $e";
      _estado = EstadoCarga.error;
      notifyListeners();
      return false;
    }
  }

  String? _validarCamposLocal() {
    final desc = avistamiento.descripcion.trim();
    final foto = avistamiento.foto.trim();

    if (foto.isEmpty) return 'Debes subir una foto antes de guardar.';
    if (!_esUbicacionValida(avistamiento.latitud, avistamiento.longitud)) {
      return 'Debe seleccionar una ubicación válida en el mapa.';
    }
    if (desc.isEmpty) return 'La descripción no puede estar vacía.';
    return null;
  }

  bool _esUbicacionValida(double? lat, double? lon) =>
      lat != null && lon != null && (lat != 0 || lon != 0);

  /// Algoritmo de búsqueda de coincidencias.
  ///
  /// Compara el avistamiento actual [av] contra todos los reportes "perdidos" en la BD.
  /// Criterios de coincidencia:
  /// 1. **Distancia:** Menor a 9 km (usando fórmula de Haversine).
  /// 2. **Similitud Visual:** Mayor o igual al 50% (usando comparación de embeddings).
  ///
  /// Si hay coincidencia, actualiza el avistamiento y notifica al dueño del reporte.
  Future<void> _buscarCoincidenciaConReportes(Avistamiento av) async {
    try {
      final reportes = await _firestore
          .collection("reportes_mascotas")
          .where("estado", isEqualTo: "perdido")
          .get();

      for (var doc in reportes.docs) {
        final data = doc.data();
        final fotos = List<String>.from(data["fotos"] ?? []);
        if (fotos.isEmpty) continue;

        final distancia = _calcularDistancia(
          av.latitud ?? 0,
          av.longitud ?? 0,
          (data["latitud"] ?? 0).toDouble(),
          (data["longitud"] ?? 0).toDouble(),
        );

        if (distancia > 9.0) continue;

        final similitud = await _compararImagenes(av.foto, fotos.first);

        if (similitud >= 0.5) {
          await _firestore.collection("avistamientos").doc(av.id).update({
            "reporteId": doc.id,
          });

          final usuarioId = data["usuarioId"];
          await _notificarCoincidencia(usuarioId, av.id);
          break;
        }
      }
    } catch (e) {
      debugPrint("⚠️ Error silencioso: $e");
    }
  }

  /// Calcula la distancia en Kilómetros entre dos coordenadas usando la fórmula de Haversine.
  ///
  /// [lat1], [lon1]: Coordenadas del punto A.
  /// [lat2], [lon2]: Coordenadas del punto B.
  double _calcularDistancia(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371; // Radio de la Tierra en km
    final dLat = _gradosARadianes(lat2 - lat1);
    final dLon = _gradosARadianes(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_gradosARadianes(lat1)) *
            cos(_gradosARadianes(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _gradosARadianes(double grados) => grados * pi / 180.0;

  /// Descarga las imágenes de las URLs [url1] y [url2] y las compara usando el servicio de IA.
  Future<double> _compararImagenes(String url1, String url2) async {
    try {
      if (url1 == url2) return 1.0;
      final file1 = await _descargarImagen(url1);
      final file2 = await _descargarImagen(url2);
      return await _services.compararImagenes(file1, file2); // Usamos wrapper
    } catch (e) {
      return 0.0;
    }
  }

  /// Descarga una imagen desde una URL y la guarda temporalmente.
  Future<File> _descargarImagen(String url) async {
    final response = await _httpClient.get(
      Uri.parse(url),
    ); // Usamos cliente inyectado
    final dir = await _services.getTempDir();
    final file = File(
      "${dir.path}/${DateTime.now().millisecondsSinceEpoch}_temp.jpg",
    );
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  /// Notifica al usuario [usuarioId] sobre una posible coincidencia con su reporte.
  Future<void> _notificarCoincidencia(
    String usuarioId,
    String avistamientoId,
  ) async {
    try {
      await _services.enviarPush(
        titulo: "Posible coincidencia 🐾",
        cuerpo: "Tu mascota perdida podría haber sido vista recientemente.",
      );
    } catch (e) {
      debugPrint("Error notificacion: $e");
    }
  }
}
