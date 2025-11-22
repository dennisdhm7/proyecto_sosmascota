import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_mascotas/modelo/notificacion.dart';

void main() {
  group('Notificacion', () {
    test('fromMap parses all fields including Timestamp', () {
      final date = DateTime.utc(2020, 1, 1, 12, 0, 0);
      final ts = Timestamp.fromDate(date);
      final data = {
        'titulo': 'Hola',
        'mensaje': 'Cuerpo',
        'usuarioId': 'user123',
        'tipo': 'info',
        'leido': true,
        'fecha': ts,
      };

      final n = Notificacion.fromMap('id1', data);

      expect(n.id, 'id1');
      expect(n.titulo, 'Hola');
      expect(n.mensaje, 'Cuerpo');
      expect(n.usuarioId, 'user123');
      expect(n.tipo, 'info');
      expect(n.leido, isTrue);
      expect(n.fecha, date);
    });

    test('fromMap handles missing fields with defaults', () {
      final n = Notificacion.fromMap('id2', {});

      expect(n.id, 'id2');
      expect(n.titulo, '');
      expect(n.mensaje, '');
      expect(n.usuarioId, '');
      expect(n.tipo, '');
      expect(n.leido, isFalse);
      expect(n.fecha, isNull);
    });

    test('toMap uses FieldValue.serverTimestamp when fecha is null', () {
      final n = Notificacion(
        id: 'id3',
        titulo: 't',
        mensaje: 'm',
        usuarioId: 'u',
        tipo: 'tipo',
        fecha: null,
        leido: false,
      );

      final map = n.toMap();

      expect(map['titulo'], 't');
      expect(map['mensaje'], 'm');
      expect(map['usuarioId'], 'u');
      expect(map['tipo'], 'tipo');
      expect(map['leido'], isFalse);
      expect(map['fecha'], isA<FieldValue>());
      expect(map['fecha'], FieldValue.serverTimestamp());
    });

    test('toMap includes provided fecha when not null', () {
      final date = DateTime(2021, 5, 6, 10, 30);
      final n = Notificacion(
        id: 'id4',
        titulo: 't2',
        mensaje: 'm2',
        usuarioId: 'u2',
        tipo: 'alert',
        fecha: date,
        leido: true,
      );

      final map = n.toMap();

      expect(map['fecha'], date);
      expect(map['titulo'], 't2');
      expect(map['mensaje'], 'm2');
      expect(map['usuarioId'], 'u2');
      expect(map['tipo'], 'alert');
      expect(map['leido'], isTrue);
    });
  });
}
