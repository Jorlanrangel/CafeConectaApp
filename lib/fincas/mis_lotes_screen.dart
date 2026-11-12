import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'lote_model.dart';
import 'lote_service.dart';
import 'registrar_lote_screen.dart';

class MisLotesScreen extends StatelessWidget {
  final String fincaId;
  final String fincaNombre;

  const MisLotesScreen({
    super.key,
    required this.fincaId,
    required this.fincaNombre,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mis Lotes',
              style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 17),
            ),
            Text(
              fincaNombre,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _AddButton(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RegistrarLoteScreen(
                    fincaId: fincaId,
                    fincaNombre: fincaNombre,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<LoteModel>>(
        stream: LoteService.obtenerLotes(fincaId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: AppColors.primary));
          }
          if (snap.hasError) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 52, color: AppColors.secondary),
                  SizedBox(height: 12),
                  Text('Error al cargar los lotes',
                      style: TextStyle(
                          color: AppColors.text, fontSize: 15)),
                ],
              ),
            );
          }
          final lotes = snap.data ?? [];
          if (lotes.isEmpty) {
            return _buildEmpty(context);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lotes.length,
            itemBuilder: (context, i) => _LoteCard(
              lote: lotes[i],
              fincaNombre: fincaNombre,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.grass_outlined,
                  size: 52, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text('Aún no tienes lotes registrados',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Registra los lotes de $fincaNombre para gestionar tu cultivo',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RegistrarLoteScreen(
                    fincaId: fincaId,
                    fincaNombre: fincaNombre,
                  ),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Registrar primer lote'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(220, 50)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tarjeta de lote ──────────────────────────────────────────────────────────

class _LoteCard extends StatelessWidget {
  final LoteModel lote;
  final String fincaNombre;

  const _LoteCard({required this.lote, required this.fincaNombre});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2E7D32),
                  const Color(0xFF43A047),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.grass_outlined,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lote.nombre,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text(
                        'Variedad: ${lote.variedad}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Menú eliminar
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: Colors.white70),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) async {
                    if (val == 'eliminar') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          title: const Text('¿Eliminar lote?'),
                          content: Text(
                              '¿Estás seguro de eliminar "${lote.nombre}"? Esta acción no se puede deshacer.'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Cancelar')),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondary),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await LoteService.eliminarLote(
                            lote.fincaId, lote.id!);
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'eliminar',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            color: AppColors.secondary, size: 18),
                        SizedBox(width: 8),
                        Text('Eliminar',
                            style:
                                TextStyle(color: AppColors.secondary)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Info chips
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Row(
              children: [
                _InfoChip(
                    icon: Icons.terrain_outlined,
                    label: 'Altura',
                    value: '${lote.altura.toInt()} msnm'),
                const SizedBox(width: 10),
                _InfoChip(
                    icon: Icons.eco_outlined,
                    label: 'Variedad',
                    value: lote.variedad),
                const SizedBox(width: 10),
                _InfoChip(
                    icon: Icons.calendar_today_outlined,
                    label: 'Registrado',
                    value:
                        '${lote.creadoEn.day}/${lote.creadoEn.month}/${lote.creadoEn.year}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoChip(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 13, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ─── Botón agregar flotante ───────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text('Agregar',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}