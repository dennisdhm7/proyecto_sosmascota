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

/// Clase envoltorio para aislar servicios externos y métodos estáticos.
///
/// Su principal función es abstraer las llamadas a [ServicioTFLite],
/// [NotificacionServicio] y plugins (como compresión/archivos temporales)
/// para que puedan ser fácilmente sustituidos por Mocks en las pruebas.
class ReporteServiciosExternos {
  /// Ejecuta el modelo de IA para clasificar el tipo de animal en el [archivo].
  ///
  /// Retorna un mapa con la etiqueta y el nivel de confianza.
  Future<Map<String, dynamic>> detectarAnimal(File archivo) async {
    return await ServicioTFLite.detectarAnimal(archivo);
  }

  /// Envía una notificación Push a los usuarios.
  Future<void> enviarPush({
    required String titulo,
    required String cuerpo,
  }) async {
    await NotificacionServicio.enviarPush(titulo: titulo, cuerpo: cuerpo);
  }

  /// Comprime la imagen en [archivo] a una calidad del 70% y la guarda en un
  /// directorio temporal para optimizar la subida.
  Future<File> comprimirImagen(File archivo) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        "${dir.absolute.path}/${DateTime.now().millisecondsSinceEpoch}.jpg";
    final result = await FlutterImageCompress.compressAndGetFile(
      archivo.absolute.path,
      targetPath,
      quality: 70,
    );
    // Retorna el archivo comprimido o el original si falló la compresión
    return result != null ? File(result.path) : archivo;
  }
}

/// ViewModel encargado de la gestión de estado y lógica para el formulario de reporte de mascotas.
///
/// Implementa la lógica del "Wizard" (pasos 0, 1, 2) y orquesta:
/// - La validación de las imágenes por IA.
/// - La subida de archivos a Storage.
/// - El guardado final del reporte en Firestore.
class ReporteMascotaVM extends ChangeNotifier {
  // 💉 INYECCIÓN DE DEPENDENCIAS
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ReporteServiciosExternos _servicios;

  /// Constructor que permite inyectar dependencias (Mocks) o usa las instancias reales.
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

  // Claves de formulario para validación de campos en cada paso
  final formKeyPaso1 = GlobalKey<FormState>();
  final formKeyPaso2 = GlobalKey<FormState>();
  final formKeyPaso3 = GlobalKey<FormState>();

  int get paso => _paso;
  bool get cargando => _cargando;
  List<String> get fotos => reporte.fotos;
  List<String> get videos => reporte.videos;

  /// Método de notificación seguro para evitar llamadas a setState después de dispose.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // 🔹 Control del Wizard

  /// Establece directamente el [nuevoPaso] del formulario.
  void setPaso(int nuevoPaso) {
    _paso = nuevoPaso;
    _notify();
  }

  /// Avanza al siguiente paso del formulario (máximo 2).
  void siguientePaso() {
    if (_paso < 2) {
      _paso++;
      _notify();
    }
  }

  /// Retrocede al paso anterior del formulario (mínimo 0).
  void pasoAnterior() {
    if (_paso > 0) {
      _paso--;
      _notify();
    }
  }

  /// Agrega una URL de [url] a la lista de fotos del reporte.
  void agregarFoto(String url) {
    reporte.fotos.add(url);
    _notify();
  }

  /// Agrega una URL de [url] a la lista de videos del reporte.
  void agregarVideo(String url) {
    reporte.videos.add(url);
    _notify();
  }

  // 📸 Subir foto
  /// Procesa, valida por IA y sube un archivo de imagen al Firebase Storage.
  ///
  /// Pasos:
  /// 1. Comprime la imagen (usando [_servicios]).
  /// 2. **Validación IA:** Si la confianza es menor a 0.6 o la etiqueta es "otro", lanza una [Exception].
  /// 3. Sube la imagen a `reportes_mascotas/{uid}/`.
  ///
  /// Retorna la URL de descarga de la imagen subida.
  Future<String> subirFoto(File archivo) async {
    // Usamos el wrapper para la compresión e IA
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
  /// Sube un archivo de video directamente a Firebase Storage.
  ///
  /// Retorna la URL de descarga del video subido.
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
  /// Finaliza el proceso y guarda el reporte de mascota perdida en Firestore.
  ///
  /// Pasos:
  /// 1. Establece el estado local a cargando.
  /// 2. Asigna ID, UID, fecha de registro y estado "perdido".
  /// 3. Envía una notificación Push a los usuarios.
  ///
  /// Retorna `true` si el guardado en Firestore fue exitoso.
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
