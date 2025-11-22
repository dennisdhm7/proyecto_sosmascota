import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../modelo/notificacion.dart';
import '../../servicios/notificacion_servicio.dart';

// ✅ WRAPPER: Envuelve la llamada estática para poder mockearla
class NotificacionServiciosExternos {
  Stream<List<Notificacion>> obtenerNotificaciones(String uid) {
    return NotificacionServicio.obtenerNotificaciones(uid);
  }
}

class NotificacionVM extends ChangeNotifier {
  // 💉 DEPENDENCIAS
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final NotificacionServiciosExternos _servicios;

  NotificacionVM({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    NotificacionServiciosExternos? servicios,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _servicios = servicios ?? NotificacionServiciosExternos();

  final List<Notificacion> _notificaciones = [];
  List<Notificacion> get notificaciones => List.unmodifiable(_notificaciones);

  int _noLeidas = 0;
  int get noLeidas => _noLeidas;

  StreamSubscription? _subs;

  /// 🔔 Escucha las notificaciones
  void escucharNotificaciones() {
    final uid = _auth.currentUser?.uid; // Usamos _auth inyectado
    if (uid == null) return;

    _subs?.cancel();

    // Usamos el wrapper _servicios
    _subs = _servicios.obtenerNotificaciones(uid).listen((lista) {
      _notificaciones
        ..clear()
        ..addAll(lista);

      // Calcula cuántas no están leídas
      _noLeidas = lista.where((n) => n.leido == false).length;
      notifyListeners();
    });
  }

  /// ✅ Marca todas las notificaciones como leídas
  Future<void> marcarTodasComoLeidas() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Usamos _firestore inyectado
    final batch = _firestore.batch();

    final query = await _firestore
        .collection('notificaciones')
        .where('usuarioId', isEqualTo: uid)
        .where('leido', isEqualTo: false)
        .get();

    for (var doc in query.docs) {
      batch.update(doc.reference, {'leido': true});
    }

    await batch.commit();

    _noLeidas = 0;
    notifyListeners();
  }

  /// 🚫 Detener la escucha
  void detenerEscucha() {
    _subs?.cancel();
    _subs = null;
  }

  @override
  void dispose() {
    detenerEscucha();
    super.dispose();
  }
}
