import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// A small test helper that mirrors the real FirestoreServicio methods
/// but allows injecting a FakeFirebaseFirestore for unit testing.
class TestFirestoreServicio {
  final FirebaseFirestore _db;
  TestFirestoreServicio(this._db);

  Future<void> guardarUsuario(String uid, Map<String, dynamic> data) async {
    await _db
        .collection("usuarios")
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  Future<void> actualizarEstadoVerificado(String uid, bool verificado) async {
    final docRef = _db.collection("usuarios").doc(uid);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw StateError('Document not found: usuarios/$uid');
    }
    await docRef.update({"estadoVerificado": verificado});
  }
}

void main() {
  group('FirestoreServicio (using FakeFirebaseFirestore)', () {
    late FakeFirebaseFirestore fakeDb;
    late TestFirestoreServicio servicio;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
      servicio = TestFirestoreServicio(fakeDb);
    });

    test('guardarUsuario creates or merges data into usuarios/:uid', () async {
      final uid = 'uid123';
      final data = {'nombre': 'Fido', 'edad': 4};

      await servicio.guardarUsuario(uid, data);

      final doc = await fakeDb.collection('usuarios').doc(uid).get();
      expect(doc.exists, isTrue);
      expect(doc.data(), containsPair('nombre', 'Fido'));
      expect(doc.data(), containsPair('edad', 4));
    });

    test('guardarUsuario with merge preserves existing fields', () async {
      final uid = 'uidMerge';
      await fakeDb.collection('usuarios').doc(uid).set({'a': 1, 'b': 2});
      await servicio.guardarUsuario(uid, {'b': 20, 'c': 3});

      final doc = await fakeDb.collection('usuarios').doc(uid).get();
      expect(doc.data(), containsPair('a', 1)); // preserved
      expect(doc.data(), containsPair('b', 20)); // updated
      expect(doc.data(), containsPair('c', 3)); // added
    });

    test(
      'actualizarEstadoVerificado updates only the estadoVerificado field',
      () async {
        final uid = 'uidUpdate';
        await fakeDb.collection('usuarios').doc(uid).set({
          'nombre': 'Luna',
          'estadoVerificado': false,
        });

        await servicio.actualizarEstadoVerificado(uid, true);

        final doc = await fakeDb.collection('usuarios').doc(uid).get();
        expect(doc.data(), containsPair('nombre', 'Luna'));
        expect(doc.data(), containsPair('estadoVerificado', true));
      },
    );

    test('actualizarEstadoVerificado on non-existing doc throws', () async {
      final uid = 'nonexistent';
      // FakeFirebaseFirestore's update will throw a StateError for missing doc
      expect(
        () async => await servicio.actualizarEstadoVerificado(uid, true),
        throwsA(isA<StateError>()),
      );
    });
  });
}
