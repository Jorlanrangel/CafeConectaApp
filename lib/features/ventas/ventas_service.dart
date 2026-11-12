import 'package:cafeconecta_aplication/features/ventas/ventas_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VentaService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static CollectionReference<Map<String, dynamic>> _col() =>
      _db.collection('usuarios').doc(_uid).collection('ventas');

  static Future<void> guardarVenta(VentaModel v) async {
    await _col().add(v.toMap());
  }

  static Stream<List<VentaModel>> obtenerVentasPorFinca(String fincaId) {
    return _col()
        .where('fincaId', isEqualTo: fincaId)
        .snapshots()
        .map((snap) {
      final lista = snap.docs
          .map((d) => VentaModel.fromMap(d.data(), d.id))
          .toList();
      lista.sort((a, b) => b.fecha.compareTo(a.fecha));
      return lista;
    });
  }

  static Future<void> eliminarVenta(String id) async {
    await _col().doc(id).delete();
  }
}