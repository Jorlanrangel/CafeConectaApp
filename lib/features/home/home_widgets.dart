import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';

// ─── Tarjeta de resumen rediseñada ───────────────────────────────────────────

class SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color iconColor;
  final Color iconBg;
  final String? badge;
  final Color? badgeColor;

  const SummaryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.iconColor,
    required this.iconBg,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icono con fondo
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 10),
          // Valor principal
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: iconColor,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // Título
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textLight,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Badge
          if (badge != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: (badgeColor ?? AppColors.primary).withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  fontSize: 9,
                  color: badgeColor ?? AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Item de actividad reciente ───────────────────────────────────────────────

class ActivityItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String time;

  const ActivityItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: AppColors.textLight,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Gráfica de línea mejorada ────────────────────────────────────────────────

class HomeLineChart extends StatefulWidget {
  final String title;
  final List<FlSpot> spots;
  final Color color;
  final List<String> labels;
  final String unit;
  final LinearGradient gradient;

  const HomeLineChart({
    super.key,
    required this.title,
    required this.spots,
    required this.color,
    required this.labels,
    required this.unit,
    required this.gradient,
  });

  @override
  State<HomeLineChart> createState() => _HomeLineChartState();
}

class _HomeLineChartState extends State<HomeLineChart> {
  int? _touchedIndex;

  double get _maxY {
    final max = widget.spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    return max * 1.3;
  }

  double get _minY {
    final min = widget.spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    return (min * 0.7).clamp(0, double.infinity);
  }

  String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final maxVal = widget.spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  ShaderMask(
                    shaderCallback:
                        (bounds) => widget.gradient.createShader(bounds),
                    child: Text(
                      '${_fmt(maxVal)} ${widget.unit}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Text(
                    'Valor máximo del período',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textLight.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.color.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      color: widget.color,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '↑ Tendencia',
                      style: TextStyle(
                        color: widget.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Gráfica
          SizedBox(
            height: 155,
            child: LineChart(
              LineChartData(
                minY: _minY,
                maxY: _maxY,
                clipData: const FlClipData.all(),
                lineTouchData: LineTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      _touchedIndex =
                          response?.lineBarSpots?.isNotEmpty == true
                              ? response!.lineBarSpots![0].spotIndex
                              : null;
                    });
                  },
                  getTouchedSpotIndicator:
                      (barData, spotIndexes) =>
                          spotIndexes
                              .map(
                                (i) => TouchedSpotIndicatorData(
                                  FlLine(
                                    color: widget.color.withOpacity(0.25),
                                    strokeWidth: 1.5,
                                    dashArray: [5, 5],
                                  ),
                                  FlDotData(
                                    getDotPainter:
                                        (_, __, ___, ____) =>
                                            FlDotCirclePainter(
                                              radius: 7,
                                              color: widget.color,
                                              strokeWidth: 3,
                                              strokeColor: Colors.white,
                                            ),
                                  ),
                                ),
                              )
                              .toList(),
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => widget.color,
                    tooltipRoundedRadius: 12,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    getTooltipItems:
                        (spots) =>
                            spots
                                .map(
                                  (s) => LineTooltipItem(
                                    '${_fmt(s.y)} ${widget.unit}',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                                .toList(),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (_maxY - _minY) / 4,
                  getDrawingHorizontalLine:
                      (v) => FlLine(
                        color: Colors.grey.withOpacity(0.08),
                        strokeWidth: 1,
                      ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: (_maxY - _minY) / 4,
                      getTitlesWidget:
                          (value, meta) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              _fmt(value),
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.textLight,
                              ),
                            ),
                          ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= widget.labels.length) {
                          return const SizedBox();
                        }
                        final isTouched = _touchedIndex == idx;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            widget.labels[idx],
                            style: TextStyle(
                              fontSize: isTouched ? 11 : 10,
                              color:
                                  isTouched
                                      ? widget.color
                                      : AppColors.textLight,
                              fontWeight:
                                  isTouched
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: widget.spots,
                    isCurved: true,
                    curveSmoothness: 0.4,
                    gradient: widget.gradient,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        final isTouched = _touchedIndex == index;
                        return FlDotCirclePainter(
                          radius: isTouched ? 0 : 3.5,
                          color: widget.color,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          widget.color.withOpacity(0.20),
                          widget.color.withOpacity(0.00),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tarjeta ChatIA ───────────────────────────────────────────────────────────

class ChatIACard extends StatelessWidget {
  final VoidCallback onTap;
  const ChatIACard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ChatIA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pregúntale a nuestra IA todo sobre tu cultivo de café',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Abrir chat',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.chat_bubble_outline,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tarjeta Precio del Café (precio real FNC) ────────────────────────────────

class PriceCard extends StatelessWidget {
  final String price;
  final String variation;
  final bool isUp;
  final bool isLoading;
  final VoidCallback onRefresh;

  const PriceCard({
    super.key,
    required this.price,
    required this.variation,
    required this.isUp,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isUp
                  ? [const Color(0xFF1B5E20), const Color(0xFF388E3C)]
                  : [const Color(0xFFB71C1C), const Color(0xFFC62828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isUp ? AppColors.primary : AppColors.secondary).withOpacity(
              0.35,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icono
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.coffee_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          // Información de precio
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Precio FNC · Hoy',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(width: 6),
                    // Botón de actualizar
                    GestureDetector(
                      onTap: onRefresh,
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white54,
                        size: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                isLoading
                    ? const SizedBox(
                      width: 120,
                      height: 28,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white24,
                        color: Colors.white,
                      ),
                    )
                    : Text(
                      price,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                const Text(
                  'por kg · Toca para ver PDF oficial',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          // Variación
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUp
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      variation,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Icon(
                Icons.open_in_new_rounded,
                color: Colors.white54,
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
