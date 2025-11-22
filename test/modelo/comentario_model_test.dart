import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_mascotas/modelo/comentario_model.dart';

void main() {
  group('Comentario model', () {
    test('fromMap with all fields maps correctly', () {
      final date = DateTime.utc(2021, 7, 20, 12, 34, 56);
      final timestamp = Timestamp.fromDate(date);
      final data = {
        'texto': 'Hola',
        'autor': 'Juan',
        'uid': 'uid123',
        'fecha': timestamp,
        'mediaUrl': 'http://example.com/media.jpg',
        'mediaType': 'image',
        'likes': ['u1', 'u2'],
        'dislikes': ['u3'],
        'shares': 7,
      };

      final comentario = Comentario.fromMap('c1', data);

      expect(comentario.id, 'c1');
      expect(comentario.texto, 'Hola');
      expect(comentario.autor, 'Juan');
      expect(comentario.uid, 'uid123');
      expect(comentario.fecha, date);
      expect(comentario.mediaUrl, 'http://example.com/media.jpg');
      expect(comentario.mediaType, 'image');
      expect(comentario.likes, equals(['u1', 'u2']));
      expect(comentario.dislikes, equals(['u3']));
      expect(comentario.shares, 7);
    });

    test('fromMap uses defaults when fields are missing', () {
      final data = <String, dynamic>{}; // empty map
      final comentario = Comentario.fromMap('c2', data);

      expect(comentario.id, 'c2');
      // defaults from implementation
      expect(comentario.texto, '');
      expect(comentario.autor, 'Anónimo');
      expect(comentario.uid, '');
      expect(comentario.likes, isEmpty);
      expect(comentario.dislikes, isEmpty);
      expect(comentario.shares, 0);
      expect(comentario.mediaUrl, isNull);
      expect(comentario.mediaType, isNull);
      expect(comentario.fecha, isA<DateTime>());
    });

    test('toMap returns expected map representation', () {
      final date = DateTime(2022, 3, 14, 15, 9, 26);
      final comentario = Comentario(
        id: 'c3',
        texto: 'Test',
        autor: 'Ana',
        uid: 'uidA',
        fecha: date,
        mediaUrl: null,
        mediaType: null,
        likes: ['x'],
        dislikes: [],
        shares: 0,
      );

      final map = comentario.toMap();

      expect(map['texto'], 'Test');
      expect(map['autor'], 'Ana');
      expect(map['uid'], 'uidA');
      expect(map['fecha'], date);
      expect(map['mediaUrl'], isNull);
      expect(map['mediaType'], isNull);
      expect(map['likes'], equals(['x']));
      expect(map['dislikes'], equals([]));
      expect(map['shares'], 0);
    });
  });
}
