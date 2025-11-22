import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart'; // Para ChangeNotifier
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sos_mascotas/servicios/notificacion_servicio.dart';
import 'package:sos_mascotas/servicios/servicio_tflite.dart';
import '../../modelo/avistamiento.dart';

/// Estados posibles de la pantalla para comunicar a la UI qué hacer
enum EstadoCarga { inicial, cargando, exito, error }

class AvistamientoVM extends ChangeNotifier {
  // Instancia del modelo
  Avistamiento avistamiento = Avistamiento();

  // Variables de estado
  EstadoCarga _estado = EstadoCarga.inicial;
  String? _mensajeUsuario; // Para enviar mensajes (errores o éxitos) a la UI

  // Getters para la UI
  EstadoCarga get estado => _estado;
  String? get mensajeUsuario => _mensajeUsuario;
  bool get cargando => _estado == EstadoCarga.cargando;

  // Constructor
  AvistamientoVM();

  // Setters simples
  void setDireccion(String v) => avistamiento.direccion = v;
  void setDescripcion(String v) => avistamiento.descripcion = v;

  /// Método para limpiar el mensaje después de mostrarlo en el SnackBar
  void limpiarMensaje() {
    _mensajeUsuario = null;
    // No notificamos para evitar reconstrucciones innecesarias,
    // ya que esto solo es limpieza interna de lógica.
  }

  /// Actualiza la ubicación seleccionada en el mapa
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

  /// Comprimir imagen antes de subir para ahorrar datos y almacenamiento
  Future<File> _comprimirImagen(File archivo) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        "${dir.absolute.path}/${DateTime.now().millisecondsSinceEpoch}.jpg";

    final result = await FlutterImageCompress.compressAndGetFile(
      archivo.absolute.path,
      targetPath,
      quality: 70,
    );

    return result != null ? File(result.path) : archivo;
  }

  /// Subir foto con validación de ML (TFLite) y Firebase Storage
  /// Retorna la URL si tiene éxito, null si falla.
  Future<String?> subirFoto(File archivo) async {
    try {
      _estado = EstadoCarga.cargando;
      notifyListeners();

      final comprimido = await _comprimirImagen(archivo);

      // 1. Analizar con IA
      final resultado = await ServicioTFLite.detectarAnimal(comprimido);
      final tipo = resultado["etiqueta"];
      final confianzaVal = resultado["confianza"];
      final confianzaStr = (confianzaVal * 100).toStringAsFixed(2);

      // Validación de IA: Si no es mascota o confianza baja
      if (tipo == "otro" || confianzaVal < 0.6) {
        _estado = EstadoCarga.error;
        _mensajeUsuario =
            "⚠️ No se detectó una mascota clara ($confianzaStr%). Intente otra foto.";
        notifyListeners();
        return null;
      }

      // Notificar detección exitosa (sin cambiar estado a 'exito' para no cerrar pantalla)
      _mensajeUsuario = "🐾 Se detectó un $tipo ($confianzaStr%)";
      notifyListeners();
      // Importante: Limpiamos el mensaje brevemente después en la UI, o aquí si fuera necesario,
      // pero dejaremos que la UI lo consuma.

      // 2. Subir a Firebase Storage
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseStorage.instance
          .ref()
          .child("avistamientos")
          .child(uid)
          .child("${DateTime.now().millisecondsSinceEpoch}.jpg");

      await ref.putFile(comprimido);
      final url = await ref.getDownloadURL();

      _estado = EstadoCarga.inicial; // Regresamos a estado reposo
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
  // 💾 Lógica de Guardado y Firestore
  // ----------------------------------------------------------------------

  /// Guardar el avistamiento en Firestore
  Future<bool> guardarAvistamiento() async {
    // 1. Validar campos localmente
    final errorValidacion = _validarCamposLocal();
    if (errorValidacion != null) {
      _mensajeUsuario = errorValidacion;
      _estado = EstadoCarga.error; // Esto hará que la UI muestre snackbar rojo
      notifyListeners();
      return false;
    }

    try {
      _estado = EstadoCarga.cargando;
      notifyListeners();

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final docRef = FirebaseFirestore.instance
          .collection("avistamientos")
          .doc();

      avistamiento.id = docRef.id;
      avistamiento.usuarioId = uid;
      avistamiento.direccion = avistamiento.direccion.trim();
      avistamiento.distrito = avistamiento.distrito.trim();

      // Guardar
      await docRef.set(
        avistamiento.toMap()
          ..addAll({"fechaRegistro": FieldValue.serverTimestamp()}),
      );

      // 2. Lógica de Negocio: Buscar coincidencia
      await _buscarCoincidenciaConReportes(avistamiento);

      // 3. Notificación Global
      await NotificacionServicio.enviarPush(
        titulo: "Nuevo avistamiento 👀",
        cuerpo: "Se ha registrado un nuevo avistamiento de mascota.",
      );

      _mensajeUsuario = "✅ Avistamiento guardado correctamente.";
      _estado =
          EstadoCarga.exito; // Esto indicará a la UI que cierre la pantalla
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

  // ----------------------------------------------------------------------
  // 🔍 Algoritmos de Coincidencia (Geolocalización + Embeddings)
  // ----------------------------------------------------------------------

  Future<void> _buscarCoincidenciaConReportes(Avistamiento av) async {
    try {
      final reportes = await FirebaseFirestore.instance
          .collection("reportes_mascotas")
          .where("estado", isEqualTo: "perdido")
          .get();

      for (var doc in reportes.docs) {
        final data = doc.data();
        final fotos = List<String>.from(data["fotos"] ?? []);
        if (fotos.isEmpty) continue;

        // Filtro 1: Distancia (Geocerca de 9km)
        final distancia = _calcularDistancia(
          av.latitud ?? 0,
          av.longitud ?? 0,
          (data["latitud"] ?? 0).toDouble(),
          (data["longitud"] ?? 0).toDouble(),
        );

        if (distancia > 9.0) continue;

        // Filtro 2: Comparación Visual (Embeddings)
        final similitud = await _compararImagenes(av.foto, fotos.first);

        if (similitud >= 0.5) {
          // Vincular en Firestore
          await FirebaseFirestore.instance
              .collection("avistamientos")
              .doc(av.id)
              .update({"reporteId": doc.id});

          // Notificar al dueño
          final usuarioId = data["usuarioId"];
          await _notificarCoincidencia(usuarioId, av.id);

          // Encontramos uno, rompemos el ciclo (opcional, depende de reglas de negocio)
          break;
        }
      }
    } catch (e) {
      debugPrint("⚠️ Error silencioso en búsqueda de coincidencias: $e");
    }
  }

  /// Fórmula de Haversine para distancia en KM
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

  /// Comparar imágenes localmente usando embeddings TFLite
  Future<double> _compararImagenes(String url1, String url2) async {
    try {
      if (url1 == url2) return 1.0;
      final file1 = await _descargarImagen(url1);
      final file2 = await _descargarImagen(url2);
      return await ServicioTFLite.compararImagenes(file1, file2);
    } catch (e) {
      debugPrint("⚠️ Error comparando imágenes: $e");
      return 0.0;
    }
  }

  /// Descargar imagen desde URL temporalmente para procesarla
  Future<File> _descargarImagen(String url) async {
    final response = await http.get(Uri.parse(url));
    final dir = await getTemporaryDirectory();
    final file = File(
      "${dir.path}/${DateTime.now().millisecondsSinceEpoch}_temp.jpg",
    );
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  /// Notificar al dueño del reporte si hay coincidencia
  Future<void> _notificarCoincidencia(
    String usuarioId,
    String avistamientoId,
  ) async {
    try {
      // Aquí idealmente usarías una Cloud Function o enviarías al token específico del usuario
      // Por simplicidad usamos el servicio general, asumiendo que maneja IDs
      await NotificacionServicio.enviarPush(
        titulo: "Posible coincidencia 🐾",
        cuerpo: "Tu mascota perdida podría haber sido vista recientemente.",
        // data: {"tipo": "coincidencia", "id": avistamientoId} // Opcional si tu servicio lo soporta
      );
    } catch (e) {
      debugPrint("Error enviando notificación de coincidencia: $e");
    }
  }
}
