import 'dart:math';
import 'package:flutter/material.dart';
import 'theme.dart';

class GridPainter extends CustomPainter {
  final List<List<int>> grid;
  final List<List<double>> conc;
  final double maxConc;
  final ({int row, int col})? hoveredCell;
  final bool isDark;

  const GridPainter(
    this.grid,
    this.conc,
    this.maxConc, {
    this.hoveredCell,
    this.isDark = false,
  });

  static Color _solutionColor(double t, bool isDark) {
    final v = sqrt(t.clamp(0.0, 1.0));
    final bgColor = isDark ? const Color(0xFF0D1827) : const Color(0xFFFFFFFF);
    if (v < 0.5) {
      return Color.lerp(bgColor, AppColors.skyBlue, v * 2)!;
    } else {
      return Color.lerp(AppColors.skyBlue, AppColors.vividTeal, (v - 0.5) * 2)!;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rows = grid.length;
    if (rows == 0) return;
    final cols = grid[0].length;
    final cellW = size.width / cols;
    final cellH = size.height / rows;
    final effectiveMax = maxConc < 1e-9 ? 1.0 : maxConc;

    // Cell colors based on theme
    final solidColor = isDark ? const Color(0xFFE5E5E5) : AppColors.solidCell;
    final semiColor  = isDark ? const Color(0xFF737373) : AppColors.semiCell;

    final solidPaint = Paint()..color = solidColor;
    final semiPaint  = Paint()..color = semiColor;
    final concPaint  = Paint();

    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        final state = grid[i][j];
        final rect = Rect.fromLTWH(j * cellW, i * cellH, cellW, cellH);
        if (state == 0) {
          canvas.drawRect(rect, solidPaint);
        } else if (state == 1) {
          canvas.drawRect(rect, semiPaint);
        } else {
          final hasConc = conc.isNotEmpty && i < conc.length && j < conc[i].length;
          final t = hasConc ? conc[i][j] / effectiveMax : 0.0;
          concPaint.color = _solutionColor(t, isDark);
          canvas.drawRect(rect, concPaint);
        }
      }
    }

    // ── Hovered cell highlight ──────────────────────────────────────────────
    if (hoveredCell != null) {
      final r = hoveredCell!.row;
      final c = hoveredCell!.col;
      if (r >= 0 && r < rows && c >= 0 && c < cols) {
        final rect = Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH);

        // Semi-transparent white fill to lighten the cell
        canvas.drawRect(
          rect,
          Paint()..color = const Color(0x40FFFFFF),
        );

        // Bold white outline
        canvas.drawRect(
          rect,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = (cellW * 0.18).clamp(1.5, 4.0),
        );

        // Electric-blue inner glow outline
        final inset = (cellW * 0.18).clamp(1.5, 4.0) * 0.5;
        canvas.drawRect(
          rect.deflate(inset),
          Paint()
            ..color = AppColors.electricBlue
            ..style = PaintingStyle.stroke
            ..strokeWidth = (cellW * 0.10).clamp(1.0, 2.5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(GridPainter old) =>
      old.hoveredCell != hoveredCell ||
      old.grid != grid ||
      old.conc != conc ||
      old.maxConc != maxConc ||
      old.isDark != isDark;
}
