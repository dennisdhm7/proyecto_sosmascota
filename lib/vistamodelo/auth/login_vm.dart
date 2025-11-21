import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../modelo/usuario.dart';

class LoginVM extends ChangeNotifier {
  // 1. 💉 DEPENDENCIAS PRIVADAS (Inyección de dependencias)
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  // 2. ✅ CONSTRUCTOR ACTUALIZADO (Soluciona tu error rojo)
  // Si le pasamos mocks (test), usa mocks. Si no (app real), usa las instancias reales.
  LoginVM({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _messaging = messaging ?? FirebaseMessaging.instance;

  final formKey = GlobalKey<FormState>();
  final correoCtrl = TextEditingController();
  final claveCtrl = TextEditingController();

  bool cargando = false;
  String? error;

  Future<void> guardarTokenFCM(String uid) async {
    try {
      // Usamos _messaging en vez de FirebaseMessaging.instance
      final token = await _messaging.getToken();
      if (token != null) {
        // Usamos _firestore en vez de FirebaseFirestore.instance
        await _firestore.collection('usuarios').doc(uid).update({
          'token': token,
        });
        debugPrint("✅ Token FCM guardado para usuario: $uid");
      }
    } catch (e) {
      debugPrint("❌ Error al guardar token FCM: $e");
    }
  }

  // Este método es útil para tests unitarios puros que no usan UI
  Future<bool> login() async {
    if (formKey.currentState != null && !formKey.currentState!.validate())
      return false;
    cargando = true;
    error = null;
    notifyListeners();

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: correoCtrl.text.trim(),
        password: claveCtrl.text.trim(),
      );

      await cred.user?.reload();
      if (cred.user != null && !cred.user!.emailVerified) {
        error = "Debe verificar su correo antes de continuar.";
        cargando = false;
        notifyListeners();
        return false;
      }

      cargando = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      error = (e.code == 'user-not-found')
          ? 'Usuario no existe'
          : (e.code == 'wrong-password')
          ? 'Contraseña incorrecta'
          : (e.message ?? 'Error al iniciar sesión');
      cargando = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> loginYDeterminarRuta() async {
    // Validación segura para tests (evita crash si formKey no está atada)
    if (formKey.currentState != null && !formKey.currentState!.validate())
      return null;

    cargando = true;
    error = null;
    notifyListeners();

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: correoCtrl.text.trim(),
        password: claveCtrl.text.trim(),
      );

      await cred.user?.reload();
      if (cred.user != null && !cred.user!.emailVerified) {
        error = "Debe verificar su correo antes de continuar.";
        cargando = false;
        notifyListeners();
        return null;
      }

      final uid = cred.user!.uid;

      // ✅ Guardar el token FCM usando la dependencia inyectada
      await guardarTokenFCM(uid);

      // Cargar los datos del usuario
      final doc = await _firestore.collection("usuarios").doc(uid).get();

      final usuario = Usuario.fromMap(doc.data() ?? {}, doc.id);

      cargando = false;
      notifyListeners();

      // 👇 decidimos la ruta según su perfil
      if (usuario.fotoPerfil == null || usuario.fotoPerfil!.isEmpty) {
        return "/perfil";
      } else {
        return "/inicio";
      }
    } on FirebaseAuthException catch (e) {
      error = e.message ?? "Error desconocido";
      cargando = false;
      notifyListeners();
      return null;
    } catch (e) {
      error = e.toString();
      cargando = false;
      notifyListeners();
      return null;
    }
  }
}
