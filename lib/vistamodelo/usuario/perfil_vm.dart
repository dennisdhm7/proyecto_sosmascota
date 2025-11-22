import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PerfilVM extends ChangeNotifier {
  final nombreCtrl = TextEditingController();
  final correoCtrl = TextEditingController();
  final telefonoCtrl = TextEditingController();
  final ubicacionCtrl = TextEditingController();

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final ImagePicker imagePicker;

  String? fotoUrl;
  bool cargando = true;

  bool notificacionesPush = true;
  bool alertasEmail = false;

  PerfilVM({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImagePicker? imagePicker,
  }) : auth = auth ?? FirebaseAuth.instance,
       firestore = firestore ?? FirebaseFirestore.instance,
       storage = storage ?? FirebaseStorage.instance,
       imagePicker = imagePicker ?? ImagePicker() {
    cargarPerfil();
  }

  Future<void> cargarPerfil() async {
    try {
      final uid = auth.currentUser!.uid;
      final doc = await firestore.collection("usuarios").doc(uid).get();

      if (doc.exists) {
        final d = doc.data()!;
        nombreCtrl.text = d["nombre"] ?? "";
        correoCtrl.text = d["correo"] ?? "";
        telefonoCtrl.text = d["telefono"] ?? "";
        ubicacionCtrl.text = d["ubicacion"] ?? "";
        fotoUrl = d["fotoPerfil"];
      }
    } finally {
      cargando = false;
      notifyListeners();
    }
  }

  Future<void> guardar() async {
    final uid = auth.currentUser!.uid;
    await firestore.collection("usuarios").doc(uid).update({
      "telefono": telefonoCtrl.text.trim(),
      "ubicacion": ubicacionCtrl.text.trim(),
      "fotoPerfil": fotoUrl ?? "",
    });

    notifyListeners();
  }

  Future<void> cambiarFoto() async {
    final picked = await imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = storage.ref().child("usuarios/$uid/perfil.jpg");

    await ref.putFile(File(picked.path));
    final url = await ref.getDownloadURL();

    fotoUrl = url;
    await firestore.collection("usuarios").doc(uid).update({"fotoPerfil": url});

    notifyListeners();
  }

  Future<void> enviarResetPassword() async {
    final correo = correoCtrl.text.trim();
    if (correo.isNotEmpty) {
      await auth.sendPasswordResetEmail(email: correo);
    }
  }

  Future<void> eliminarCuenta() async {
    final uid = auth.currentUser!.uid;
    await firestore.collection("usuarios").doc(uid).delete();
    await auth.currentUser!.delete();
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    correoCtrl.dispose();
    telefonoCtrl.dispose();
    ubicacionCtrl.dispose();
    super.dispose();
  }
}
