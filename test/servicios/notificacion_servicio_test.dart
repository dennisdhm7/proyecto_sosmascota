import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import 'package:sos_mascotas/modelo/notificacion.dart';
import 'package:sos_mascotas/servicios/notificacion_servicio.dart';

void main() {
  group('NotificacionServicio - unit tests', () {
    test('guardarNotificacion saves a notification to Firestore', () async {
      final firestore = FakeFirebaseFirestore();

      final notif = Notificacion(
        id: 'n1',
        titulo: 'T',
        mensaje: 'M',
        usuarioId: 'u1',
        tipo: 'info',
        fecha: DateTime.now().toUtc(),
        leido: false,
      );

      await NotificacionServicio.guardarNotificacion(notif, db: firestore);

      final snap = await firestore.collection('notificaciones').get();
      expect(snap.docs.length, 1);
      final data = snap.docs.first.data();
      expect(data['titulo'], 'T');
      expect(data['mensaje'], 'M');
      expect(data['usuarioId'], 'u1');
    });

    test(
      'enviarPush writes notifications for other users and the sender',
      () async {
        final firestore = FakeFirebaseFirestore();
        // crear usuarios: u1 (otro), sender (actual)
        await firestore.collection('usuarios').doc('u1').set({'nombre': 'U1'});
        await firestore.collection('usuarios').doc('sender').set({
          'nombre': 'Sender',
        });

        final mockUser = MockUser(uid: 'sender', email: 's@x.com');
        final auth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

        // cliente HTTP simulado
        final mockHttp = MockClient((request) async {
          return http.Response(jsonEncode({'result': 'ok'}), 200);
        });

        await NotificacionServicio.enviarPush(
          titulo: 'Hola',
          cuerpo: 'Cuerpo',
          db: firestore,
          auth: auth,
          httpClient: mockHttp,
          jsonKeyContent: jsonEncode({'project_id': 'proj-test'}),
        );

        final snaps = await firestore.collection('notificaciones').get();
        // debe crear una notificación para 'u1' y otra para 'sender'
        expect(snaps.docs.length, 2);
        final usuarios = snaps.docs.map((d) => d.data()['usuarioId']).toList();
        expect(usuarios, containsAll(['u1', 'sender']));
      },
    );

    test(
      'enviarPushAUsuario sends push and saves single notification',
      () async {
        final firestore = FakeFirebaseFirestore();

        final mockHttp = MockClient((request) async {
          return http.Response('ok', 200);
        });

        await NotificacionServicio.enviarPushAUsuario(
          token: 'tok',
          titulo: 'T',
          cuerpo: 'C',
          usuarioId: 'target',
          db: firestore,
          httpClient: mockHttp,
          jsonKeyContent: jsonEncode({'project_id': 'proj-test'}),
        );

        final snaps = await firestore.collection('notificaciones').get();
        expect(snaps.docs.length, 1);
        expect(snaps.docs.first.data()['usuarioId'], 'target');
      },
    );
  });
}
