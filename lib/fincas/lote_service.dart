import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lote_model.dart';

class LoteService {
  static final _db = FirebaseFirestore.instance;

  // Colección: usuarios/{uid}/fincas/{fincaId}/lotes
  static CollectionReference<Map<String, dynamic>> _col(String fincaId) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _db
        .collection('usuarios')
        .doc(uid)
        .collection('fincas')
        .doc(fincaId)
        .collection('lotes');
  }

  // Guardar nuevo lote
  static Future<void> guardarLote(LoteModel lote) async {
    await _col(lote.fincaId).add(lote.toMap());
  }

  // Obtener lotes de una finca en tiempo real
  static Stream<List<LoteModel>> obtenerLotes(String fincaId) {
    return _col(fincaId)
        .orderBy('creadoEn', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LoteModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Eliminar lote
  static Future<void> eliminarLote(String fincaId, String loteId) async {
    await _col(fincaId).doc(loteId).delete();
  }
}