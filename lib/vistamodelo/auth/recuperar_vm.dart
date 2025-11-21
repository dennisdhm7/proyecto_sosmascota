import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecuperarVM extends ChangeNotifier {
  // 💉 Dependencia Inyectable
  final FirebaseAuth _auth;

  RecuperarVM({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final correoCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  bool enviando = false;
  String? error;

  // Retornamos Future<bool> para saber en el test si tuvo éxito
  Future<bool> enviarCorreo({BuildContext? context}) async {
    // Validación segura: Si estamos en test (sin UI), saltamos la validación visual
    if (formKey.currentState != null && !formKey.currentState!.validate()) {
      return false;
    }

    enviando = true;
    error = null;
    notifyListeners();

    try {
      await _auth.sendPasswordResetEmail(email: correoCtrl.text.trim());

      // Solo ejecutamos UI si hay contexto (App real)
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Correo enviado. Revise su bandeja.')),
        );
        Navigator.pop(context);
      }

      enviando = false;
      notifyListeners();
      return true; // Éxito
    } on FirebaseAuthException catch (e) {
      error = e.message ?? 'Error enviando correo';

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error!)));
      }

      enviando = false;
      notifyListeners();
      return false; // Fallo
    }
  }

  @override
  void dispose() {
    correoCtrl.dispose();
    super.dispose();
  }
}
