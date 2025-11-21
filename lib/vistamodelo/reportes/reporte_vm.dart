import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sos_mascotas/servicios/notificacion_servicio.dart';
import 'package:sos_mascotas/servicios/servicio_tflite.dart';
import '../../modelo/reporte_mascota.dart';

// ✅ CLASE WRAPPER: Envuelve lo "difícil" de testear (Estáticos y Plugins)
class ReporteServiciosExternos {
  Future<Map<String, dynamic>> detectarAnimal(File archivo) async {
    return await ServicioTFLite.detectarAnimal(archivo);
  }

  Future<void> enviarPush({
    required String titulo,
    required String cuerpo,
  }) async {
    await NotificacionServicio.enviarPush(titulo: titulo, cuerpo: cuerpo);
  }

  Future<File> comprimirImagen(File archivo) async {
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
}

class ReporteMascotaVM extends ChangeNotifier {
  // 💉 INYECCIÓN DE DEPENDENCIAS
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ReporteServiciosExternos _servicios;

  // Constructor que permite pasar Mocks o usa los reales por defecto
  ReporteMascotaVM({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ReporteServiciosExternos? servicios,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _servicios = servicios ?? ReporteServiciosExternos();

  int _paso = 0;
  ReporteMascota reporte = ReporteMascota();
  bool _cargando = false;
  bool _disposed = false;

  final formKeyPaso1 = GlobalKey<FormState>();
  final formKeyPaso2 = GlobalKey<FormState>();
  final formKeyPaso3 = GlobalKey<FormState>();

  int get paso => _paso;
  bool get cargando => _cargando;
  List<String> get fotos => reporte.fotos;
  List<String> get videos => reporte.videos;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // 🔹 Control del wizard
  void setPaso(int nuevoPaso) {
    _paso = nuevoPaso;
    _notify();
  }

  void siguientePaso() {
    if (_paso < 2) {
      _paso++;
      _notify();
    }
  }

  void pasoAnterior() {
    if (_paso > 0) {
      _paso--;
      _notify();
    }
  }

  void agregarFoto(String url) {
    reporte.fotos.add(url);
    _notify();
  }

  void agregarVideo(String url) {
    reporte.videos.add(url);
    _notify();
  }

  // 📸 Subir foto (Ahora usa _servicios para ser testeable)
  Future<String> subirFoto(File archivo) async {
    // Usamos el wrapper
    final comprimido = await _servicios.comprimirImagen(archivo);
    final resultado = await _servicios.detectarAnimal(comprimido);

    final etiqueta = resultado["etiqueta"];
    final confianza = resultado["confianza"];

    if (etiqueta == "otro" || confianza < 0.6) {
      throw Exception(
        "❌ La imagen no parece contener una mascota. Intenta con otra foto.",
      );
    }

    final uid = _auth.currentUser!.uid;

    final ref = _storage
        .ref()
        .child("reportes_mascotas")
        .child(uid)
        .child("${DateTime.now().millisecondsSinceEpoch}.jpg");

    await ref.putFile(comprimido);
    return await ref.getDownloadURL();
  }

  // 🎥 Subir video
  Future<String> subirVideo(File archivo) async {
    final uid = _auth.currentUser!.uid;

    final ref = _storage
        .ref()
        .child("reportes_mascotas")
        .child(uid)
        .child("${DateTime.now().millisecondsSinceEpoch}.mp4");

    await ref.putFile(archivo);
    return await ref.getDownloadURL();
  }

  // 💾 Guardar reporte
  Future<bool> guardarReporte() async {
    try {
      _cargando = true;
      _notify();

      final uid = _auth.currentUser!.uid;
      final docRef = _firestore.collection("reportes_mascotas").doc();

      reporte.id = docRef.id;

      await docRef.set(
        reporte.toMap()..addAll({
          "usuarioId": uid,
          "fechaRegistro": FieldValue.serverTimestamp(),
          "estado": "perdido",
        }),
      );

      // Usamos el wrapper de notificación
      await _servicios.enviarPush(
        titulo: "Nuevo reporte 🐾",
        cuerpo: "Se ha registrado una nueva mascota perdida.",
      );

      _cargando = false;
      _notify();
      return true;
    } catch (e) {
      _cargando = false;
      _notify();
      debugPrint("❌ Error al guardar reporte: $e");
      return false;
    }
  }
}
