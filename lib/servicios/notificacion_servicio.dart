import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sos_mascotas/modelo/notificacion.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificacionServicio {
  static const _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
  static const _jsonKeyPath = 'assets/keys/service_account.json';
  static final _db = FirebaseFirestore.instance;

  /// ✅ Guardar notificación en Firestore
  static Future<void> guardarNotificacion(
    Notificacion notif, {
    FirebaseFirestore? db,
  }) async {
    final usedDb = db ?? _db;
    await usedDb.collection('notificaciones').add(notif.toMap());
  }

  /// ✅ Obtener notificaciones de un usuario en tiempo real
  static Stream<List<Notificacion>> obtenerNotificaciones(
    String usuarioId, {
    FirebaseFirestore? db,
  }) {
    final usedDb = db ?? _db;
    return usedDb
        .collection('notificaciones')
        .where('usuarioId', isEqualTo: usuarioId)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Notificacion.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// 🔔 Enviar notificación global (solo a otros usuarios)
  static Future<void> enviarPush({
    required String titulo,
    required String cuerpo,
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    dynamic httpClient,
    String? jsonKeyContent,
  }) async {
    try {
      final usedDb = db ?? _db;
      final usedAuth = auth ?? FirebaseAuth.instance;

      Map<String, dynamic> jsonKey;
      dynamic client;

      if (httpClient == null) {
        // 1️⃣ Leer credenciales del archivo JSON
        final contenido =
            jsonKeyContent ?? await rootBundle.loadString(_jsonKeyPath);
        jsonKey = jsonDecode(contenido);
        debugPrint("✅ Credenciales cargadas ($_jsonKeyPath)");

        // 2️⃣ Crear cliente autorizado para FCM
        final serviceAccount = ServiceAccountCredentials.fromJson(
          jsonEncode(jsonKey),
        );
        client = await clientViaServiceAccount(serviceAccount, _scopes);
      } else {
        // si nos pasan httpClient en tests, no necesitamos credenciales
        jsonKey = {};
        client = httpClient;
      }

      // 3️⃣ Configurar mensaje para el topic global
      final projectId = jsonKey['project_id'];
      final url =
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final message = {
        "message": {
          "topic": "mascotas",
          "notification": {"title": titulo, "body": cuerpo},
        },
      };

      // 4️⃣ Enviar notificación FCM global
      final response = await client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(message),
      );

      debugPrint('📨 FCM respuesta: ${response.statusCode} → ${response.body}');
      if (httpClient == null) client.close();

      // 5️⃣ Guardar las notificaciones en Firestore (de forma eficiente)
      final currentUid = usedAuth.currentUser?.uid;

      final usuariosSnap = await usedDb
          .collection('usuarios')
          .where(FieldPath.documentId, isNotEqualTo: currentUid)
          .get();

      final batch = usedDb.batch();

      // 🔹 Notificaciones para todos los demás usuarios
      for (var usuario in usuariosSnap.docs) {
        final ref = usedDb.collection('notificaciones').doc();
        batch.set(ref, {
          'usuarioId': usuario.id,
          'titulo': titulo,
          'mensaje': cuerpo,
          'fecha': FieldValue.serverTimestamp(),
          'leido': false,
        });
      }

      // 🔹 Notificación solo local para el emisor
      if (currentUid != null) {
        final ref = usedDb.collection('notificaciones').doc();
        batch.set(ref, {
          'usuarioId': currentUid,
          'titulo': 'Se generó tu reporte',
          'mensaje': 'Tu reporte fue registrado correctamente 🐾',
          'fecha': FieldValue.serverTimestamp(),
          'leido': false,
        });
      }

      await batch.commit();
      debugPrint(
        "✅ Notificaciones registradas correctamente para ${usuariosSnap.docs.length + 1} usuarios.",
      );
    } catch (e) {
      debugPrint("❌ Error en enviarPush: $e");
    }
  }

  /// 🎯 Enviar notificación push a un usuario específico (por token)
  static Future<void> enviarPushAUsuario({
    required String token,
    required String titulo,
    required String cuerpo,
    required String usuarioId,
    FirebaseFirestore? db,
    dynamic httpClient,
    String? jsonKeyContent,
  }) async {
    try {
      final usedDb = db ?? _db;

      Map<String, dynamic> jsonKey;
      dynamic client;

      if (httpClient == null) {
        final contenido =
            jsonKeyContent ?? await rootBundle.loadString(_jsonKeyPath);
        jsonKey = jsonDecode(contenido);
        final serviceAccount = ServiceAccountCredentials.fromJson(
          jsonEncode(jsonKey),
        );
        client = await clientViaServiceAccount(serviceAccount, _scopes);
      } else {
        jsonKey = {};
        client = httpClient;
      }

      final projectId = jsonKey['project_id'];
      final url =
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final message = {
        "message": {
          "token": token,
          "notification": {"title": titulo, "body": cuerpo},
        },
      };

      final response = await client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(message),
      );

      debugPrint(
        '📩 Push individual enviado → ${response.statusCode}: ${response.body}',
      );
      if (httpClient == null) client.close();

      // 💾 Guardar notificación Firestore (solo para el usuario destino)
      await usedDb.collection('notificaciones').add({
        'usuarioId': usuarioId,
        'titulo': titulo,
        'mensaje': cuerpo,
        'fecha': FieldValue.serverTimestamp(),
        'leido': false,
      });

      debugPrint("✅ Notificación individual guardada para $usuarioId");
    } catch (e) {
      debugPrint("❌ Error enviando notificación individual: $e");
    }
  }
}
