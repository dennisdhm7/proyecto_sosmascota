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

enum EstadoCarga { inicial, cargando, exito, error }

/// 🧱 Wrapper para aislar servicios externos y plugins
/// Esto permite mockearlos en los tests fácilmente.
class AvistamientoServices {
  Future<Directory> getTempDir() async => await getTemporaryDirectory();

  Future<File?> compress(String path, String targetPath) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      path,
      targetPath,
      quality: 70,
    );
    return result != null ? File(result.path) : null;
  }

  Future<Map<dynamic, dynamic>> detectarAnimal(File file) async {
    return await ServicioTFLite.detectarAnimal(file);
  }

  Future<double> compararImagenes(File f1, File f2) async {
    return await ServicioTFLite.compararImagenes(f1, f2);
  }

  Future<void> enviarPush({
    required String titulo,
    required String cuerpo,
  }) async {
    await NotificacionServicio.enviarPush(titulo: titulo, cuerpo: cuerpo);
  }
}

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

  // Constructor con Inyección
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

  Future<File> _comprimirImagen(File archivo) async {
    // Usamos el wrapper inyectado
    final dir = await _services.getTempDir();
    final targetPath =
        "${dir.absolute.path}/${DateTime.now().millisecondsSinceEpoch}.jpg";

    final result = await _services.compress(archivo.absolute.path, targetPath);
    return result ?? archivo;
  }

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

  double _calcularDistancia(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371;
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
