import 'package:cloud_firestore/cloud_firestore.dart';
import '../../modelo/comentario_model.dart';

class ComentariosViewModel {
  // 1. 💉 Propiedad privada para la instancia
  final FirebaseFirestore _firestore;

  // 2. ✅ Constructor con inyección de dependencias
  ComentariosViewModel({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<Comentario>> obtenerComentarios() {
    // Usamos _firestore en lugar de la instancia estática
    return _firestore
        .collection('comentarios')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => Comentario.fromMap(doc.id, doc.data()),
              ) // quitamos el cast forzado, Firestore ya tipa si se configura bien, o lo dejamos si tu modelo lo exige
              .toList();
        });
  }
}
