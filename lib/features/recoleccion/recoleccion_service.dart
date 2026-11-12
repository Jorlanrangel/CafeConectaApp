import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trabajador_model.dart';
import 'cosecha_model.dart';

class RecoleccionService {
  static final _db = FirebaseFirestore.instance;

  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  // ── Trabajadores ─────────────────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> _trabajadoresCol() =>
      _db.collection('usuarios').doc(_uid).collection('trabajadores');

  static Future<void> guardarTrabajador(TrabajadorModel t) async {
    await _trabajadoresCol().add(t.toMap());
  }

  // Obtener todos los trabajadores
  static Stream<List<TrabajadorModel>> obtenerTrabajadores() {
    return _trabajadoresCol()
        .orderBy('nombre')
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => TrabajadorModel.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }

  // Obtener trabajadores por finca
  static Stream<List<TrabajadorModel>> obtenerTrabajadoresPorFinca(
    String fincaId,
  ) {
    return _trabajadoresCol()
        .where('fincaId', isEqualTo: fincaId)
        .orderBy('nombre')
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => TrabajadorModel.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }

  // Eliminar trabajador y sus cosechas
  static Future<void> eliminarTrabajador(String id) async {
    await _trabajadoresCol().doc(id).delete();

    final cosechas =
        await _cosechasCol().where('trabajadorId', isEqualTo: id).get();
    for (final doc in cosechas.docs) {
      await doc.reference.delete();
    }
  }

  // ── Cosechas ─────────────────────────────────────────────────────────────

  // Obtener cosechas de una finca específica
  static Stream<List<CosechaModel>> obtenerCosechasPorFinca(String fincaId) {
    return _cosechasCol().where('fincaId', isEqualTo: fincaId).snapshots().map((
      snap,
    ) {
      final lista =
          snap.docs
              .map((doc) => CosechaModel.fromMap(doc.data(), doc.id))
              .toList();
      // Ordenar en memoria mientras se crea el índice
      lista.sort((a, b) => b.fecha.compareTo(a.fecha));
      return lista;
    });
  }

  static CollectionReference<Map<String, dynamic>> _cosechasCol() =>
      _db.collection('usuarios').doc(_uid).collection('cosechas');

  static Future<void> guardarCosecha(CosechaModel c) async {
    await _cosechasCol().add(c.toMap());
  }

  static Stream<List<CosechaModel>> obtenerCosechas() {
    return _cosechasCol()
        .orderBy('fecha', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => CosechaModel.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }

  static Future<void> eliminarCosecha(String id) async {
    await _cosechasCol().doc(id).delete();
  }
}
