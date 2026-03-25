import 'package:flutter/material.dart';
import '../theme.dart';

class GridPreview extends StatelessWidget {
  final int gridSize;
  final String geometry;

  const GridPreview({
    super.key,
    required this.gridSize,
    required this.geometry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Row(
              children: [
                const Text(
                  'Превью',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                Text(
                  '$gridSize × $gridSize',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          // Canvas
          Padding(
            padding: const EdgeInsets.all(8),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CustomPaint(
                  painter: _GridPreviewPainter(
                    gridSize: gridSize,
                    geometry: geometry,
                  ),
                ),
              ),
            ),
          ),
          // Footer labels
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Row(
              children: [
                _dot(AppColors.solidCell),
                const SizedBox(width: 4),
                const Text('Твёрдое',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
                const SizedBox(width: 10),
                _dot(const Color(0xFFB3E5FC)),
                const SizedBox(width: 4),
                const Text('Жидкость',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
}

class _GridPreviewPainter extends CustomPainter {
  final int gridSize;
  final String geometry;

  const _GridPreviewPainter({
    required this.gridSize,
    required this.geometry,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Background (liquid) ───────────────────────────────────────
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF0F9FF),
    );

    // ── Draw subtle grid lines ────────────────────────────────────
    // Show ~16 lines across so the grid "texture" is visible
    const lines = 16;
    final step = w / lines;
    final gridPaint = Paint()
      ..color = AppColors.borderLight.withAlpha(120)
      ..strokeWidth = 0.5;
    for (int i = 1; i < lines; i++) {
      canvas.drawLine(Offset(i * step, 0), Offset(i * step, h), gridPaint);
      canvas.drawLine(Offset(0, i * step), Offset(w, i * step), gridPaint);
    }

    // ── Solid body ────────────────────────────────────────────────
    final cx = w / 2;
    final cy = h / 2;
    final r = w / 4; // radius = N/4 (same ratio as simulation)

    final solidPaint = Paint()..color = AppColors.solidCell;
    final liquidPaint = Paint()..color = const Color(0xFFF0F9FF);

    switch (geometry) {
      case 'circle':
        canvas.drawCircle(Offset(cx, cy), r, solidPaint);

      case 'square':
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset(cx, cy), width: r * 2, height: r * 2),
          solidPaint,
        );

      case 'porous':
      default:
        // Solid square
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset(cx, cy), width: r * 2, height: r * 2),
          solidPaint,
        );
        // Five holes (same relative positions as simulation seed=42)
        final pr = r / 5;
        final holes = [
          Offset(cx - r * 0.38, cy - r * 0.35),
          Offset(cx + r * 0.30, cy - r * 0.20),
          Offset(cx - r * 0.12, cy + r * 0.40),
          Offset(cx + r * 0.42, cy + r * 0.30),
          Offset(cx + r * 0.05, cy - r * 0.05),
        ];
        for (final h in holes) {
          canvas.drawCircle(h, pr, liquidPaint);
        }
    }

    // ── Dimension annotations ─────────────────────────────────────
    _drawDimArrow(canvas, size, r);
  }

  void _drawDimArrow(Canvas canvas, Size size, double r) {
    final arrowPaint = Paint()
      ..color = AppColors.textMuted.withAlpha(160)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Horizontal extent arrow (shows solid width = N/2)
    final y = cy + r + 10;
    final x0 = cx - r;
    final x1 = cx + r;

    if (y + 6 < size.height) {
      canvas.drawLine(Offset(x0, y), Offset(x1, y), arrowPaint);
      // Tick marks
      canvas.drawLine(Offset(x0, y - 4), Offset(x0, y + 4), arrowPaint);
      canvas.drawLine(Offset(x1, y - 4), Offset(x1, y + 4), arrowPaint);

      // Label: "N/2"
      final span = TextSpan(
        text: '${(gridSize ~/ 2)}',
        style: TextStyle(
          fontSize: 8,
          color: AppColors.textMuted.withAlpha(200),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(
        canvas,
        Offset(cx - tp.width / 2, y + 2),
      );
    }
  }

  @override
  bool shouldRepaint(_GridPreviewPainter old) =>
      old.gridSize != gridSize || old.geometry != geometry;
}
