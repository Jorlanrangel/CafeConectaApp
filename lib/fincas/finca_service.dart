import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'finca_model.dart';

class FincaService {
  static final _db = FirebaseFirestore.instance;

  // Colección: usuarios/{uid}/fincas
  static CollectionReference<Map<String, dynamic>> _col() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _db.collection('usuarios').doc(uid).collection('fincas');
  }

  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  // Guardar nueva finca
  static Future<void> guardarFinca(FincaModel finca) async {
    await _col().add(finca.toMap());
  }

  // Obtener todas las fincas del usuario en tiempo real
  static Stream<List<FincaModel>> obtenerFincas() {
    return _col()
        .orderBy('creadaEn', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => FincaModel.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }

  // Eliminar finca + sus lotes + sus cosechas
  static Future<void> eliminarFinca(String id) async {
    // 1. Eliminar todos los lotes de la finca
    final lotes = await _col().doc(id).collection('lotes').get();
    for (final lote in lotes.docs) {
      await lote.reference.delete();
    }

    // 2. Eliminar todas las cosechas asociadas a esa finca
    final cosechas =
        await _db
            .collection('usuarios')
            .doc(_uid)
            .collection('cosechas')
            .where('fincaId', isEqualTo: id)
            .get();
    for (final cosecha in cosechas.docs) {
      await cosecha.reference.delete();
    }

    // 3. Eliminar la finca
    await _col().doc(id).delete();
  }
}
