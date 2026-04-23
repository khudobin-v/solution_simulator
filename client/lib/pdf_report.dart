import 'dart:math' show sqrt;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'models.dart';

// ── Public entry point ────────────────────────────────────────────────────────

Future<Uint8List> generateReport({
  required SimulationRequest params,
  required SimulationResult result,
  required double globalMaxConc,
}) async {
  final font     = await PdfGoogleFonts.robotoRegular();
  final fontBold = await PdfGoogleFonts.robotoBold();
  final fontMono = await PdfGoogleFonts.robotoMonoRegular();

  final theme = pw.ThemeData.withFont(base: font, bold: fontBold);

  final dissolved = (1 - result.series.last.relativeMass) * 100;

  final initialPng = _frameToPng(result.frames.first, globalMaxConc);
  final finalPng   = _frameToPng(result.frames.last,  globalMaxConc);

  final pdf = pw.Document(theme: theme);

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 48),
      build: (ctx) => [
        _header(params, fontBold),
        pw.SizedBox(height: 20),
        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
        pw.SizedBox(height: 18),

        // ── Parameters + Results side by side ────────────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _paramsBlock(params, fontBold, fontMono)),
            pw.SizedBox(width: 32),
            pw.Expanded(child: _resultsBlock(result, dissolved, fontBold, fontMono)),
          ],
        ),

        pw.SizedBox(height: 24),
        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
        pw.SizedBox(height: 18),

        // ── Charts ───────────────────────────────────────────────────────────
        _chartSection(result, fontBold),

        pw.SizedBox(height: 24),
        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
        pw.SizedBox(height: 18),

        // ── Frame snapshots ──────────────────────────────────────────────────
        _framesSection(initialPng, finalPng, fontBold),
      ],
    ),
  );

  return pdf.save();
}

// ── Header ────────────────────────────────────────────────────────────────────

pw.Widget _header(SimulationRequest p, pw.Font bold) {
  final now = DateTime.now();
  final date =
      '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}'
      '  ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Отчёт о симуляции растворения',
        style: pw.TextStyle(font: bold, fontSize: 20),
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        date,
        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
      ),
    ],
  );
}

// ── Parameters block ──────────────────────────────────────────────────────────

pw.Widget _paramsBlock(SimulationRequest p, pw.Font bold, pw.Font mono) {
  final rows = <(String, String)>[
    ('Геометрия', _geomLabel(p.geometry)),
    ('Размер сетки', '${p.gridSize} × ${p.gridSize}'),
    ('Температура', '${p.temperature.toStringAsFixed(0)} K'),
    ('Базовая скорость', p.baseRate.toStringAsFixed(3)),
    ('Диффузия', p.diffusionRate.toStringAsFixed(3)),
    if (p.geometry == 'porous') ...[
      ('Сид', '${p.seed}'),
      ('Кол-во пор', '${p.poreCount}'),
    ],
  ];
  return _block('Параметры', rows, bold, mono);
}

// ── Results block ─────────────────────────────────────────────────────────────

pw.Widget _resultsBlock(
    SimulationResult r, double dissolved, pw.Font bold, pw.Font mono) {
  final rows = <(String, String)>[
    ('Нач. объём', '${r.initialSolidCells} яч.'),
    ('Фин. объём', '${r.finalSolidCells} яч.'),
    ('Растворено', '${dissolved.toStringAsFixed(1)} %'),
    ('Шаг растворения',
        r.dissolutionStep >= r.series.last.step
            ? '> ${r.series.last.step}'
            : '${r.dissolutionStep}'),
    ('Всего шагов', '${r.series.last.step}'),
    ('Кадров сохранено', '${r.frames.length}'),
  ];
  return _block('Результаты', rows, bold, mono);
}

pw.Widget _block(
    String title, List<(String, String)> rows, pw.Font bold, pw.Font mono) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title,
          style: pw.TextStyle(font: bold, fontSize: 12, color: PdfColors.grey800)),
      pw.SizedBox(height: 8),
      pw.Table(
        columnWidths: {
          0: const pw.FlexColumnWidth(1.4),
          1: const pw.FlexColumnWidth(1),
        },
        children: rows.map((r) {
          return pw.TableRow(children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Text(r.$1,
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Text(r.$2,
                  style: pw.TextStyle(font: mono, fontSize: 10)),
            ),
          ]);
        }).toList(),
      ),
    ],
  );
}

// ── Charts ────────────────────────────────────────────────────────────────────

pw.Widget _chartSection(SimulationResult result, pw.Font bold) {
  final relMass = result.series.map((s) => s.relativeMass).toList();
  final meanConc = result.series.map((s) => s.meanConcentration).toList();
  final maxConc  = meanConc.fold(0.0, (a, b) => a > b ? a : b);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Графики',
          style: pw.TextStyle(font: bold, fontSize: 12, color: PdfColors.grey800)),
      pw.SizedBox(height: 12),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _labeledChart(
              'Относительная масса',
              relMass,
              result.series.last.step,
              PdfColors.blueGrey800,
              bold,
            ),
          ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: _labeledChart(
              'Средняя концентрация',
              maxConc > 0
                  ? meanConc.map((v) => v / maxConc).toList()
                  : meanConc,
              result.series.last.step,
              PdfColors.teal700,
              bold,
            ),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _labeledChart(
    String label, List<double> values, int maxStep, PdfColor color, pw.Font bold) {
  const h = 130.0;
  const pad = 12.0;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label,
          style: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.grey700)),
      pw.SizedBox(height: 4),
      pw.Container(
        height: h,
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        ),
        child: pw.CustomPaint(
          size: PdfPoint.zero,
          painter: (canvas, size) {
            final w = size.x;
            final chartH = size.y;
            if (values.length < 2) return;

            // Grid lines
            canvas
              ..setStrokeColor(PdfColors.grey300)
              ..setLineWidth(0.3);
            for (final t in [0.25, 0.5, 0.75]) {
              final y = pad + t * (chartH - 2 * pad);
              canvas
                ..moveTo(pad, y)
                ..lineTo(w - pad, y)
                ..strokePath();
            }

            // Axes
            canvas
              ..setStrokeColor(PdfColors.grey500)
              ..setLineWidth(0.5)
              ..moveTo(pad, pad)
              ..lineTo(pad, chartH - pad)
              ..lineTo(w - pad, chartH - pad)
              ..strokePath();

            // Data line
            canvas
              ..setStrokeColor(color)
              ..setLineWidth(1.2);
            final plotW = w - 2 * pad;
            final plotH = chartH - 2 * pad;
            for (int i = 0; i < values.length; i++) {
              final x = pad + (i / (values.length - 1)) * plotW;
              // PDF y: 0 is bottom, so invert
              final y = pad + (1 - values[i].clamp(0.0, 1.0)) * plotH;
              if (i == 0) {
                canvas.moveTo(x, y);
              } else {
                canvas.lineTo(x, y);
              }
            }
            canvas.strokePath();
          },
        ),
      ),
      pw.SizedBox(height: 3),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('0', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text('шаг $maxStep',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    ],
  );
}

// ── Frame images ──────────────────────────────────────────────────────────────

pw.Widget _framesSection(
    Uint8List initialPng, Uint8List finalPng, pw.Font bold) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Состояние системы',
          style: pw.TextStyle(font: bold, fontSize: 12, color: PdfColors.grey800)),
      pw.SizedBox(height: 12),
      pw.Row(
        children: [
          pw.Expanded(child: _frameCard('Начальное состояние', initialPng, bold)),
          pw.SizedBox(width: 20),
          pw.Expanded(child: _frameCard('Финальное состояние', finalPng, bold)),
        ],
      ),
    ],
  );
}

pw.Widget _frameCard(String label, Uint8List png, pw.Font bold) {
  return pw.Column(
    children: [
      pw.Text(label,
          style: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.grey700)),
      pw.SizedBox(height: 6),
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        ),
        child: pw.Image(pw.MemoryImage(png)),
      ),
    ],
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _geomLabel(String g) => switch (g) {
      'circle' => 'Круг',
      'square' => 'Квадрат',
      'porous' => 'Пористая',
      _ => g,
    };

Uint8List _frameToPng(FrameData frame, double globalMaxConc) {
  final N = frame.grid.length;
  final scale = (240 / N).ceil().clamp(1, 8);
  final W = N * scale;
  final image = img.Image(width: W, height: W);

  for (int r = 0; r < N; r++) {
    for (int c = 0; c < N; c++) {
      final concVal =
          (frame.conc.isNotEmpty && r < frame.conc.length && c < frame.conc[r].length)
              ? frame.conc[r][c]
              : 0.0;
      final (red, green, blue) = _cellRgb(frame.grid[r][c], concVal, globalMaxConc);
      for (int dy = 0; dy < scale; dy++) {
        for (int dx = 0; dx < scale; dx++) {
          image.setPixelRgb(c * scale + dx, r * scale + dy, red, green, blue);
        }
      }
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

(int, int, int) _cellRgb(int state, double conc, double globalMaxConc) {
  if (state == 0) return (23, 23, 23);
  if (state == 1) return (125, 125, 125);
  final effectiveMax = globalMaxConc < 1e-9 ? 1.0 : globalMaxConc;
  final t = (conc / effectiveMax).clamp(0.0, 1.0);
  final v = sqrt(t);
  final int r, g, b;
  if (v < 0.5) {
    final f = v * 2;
    r = (255 + (82 - 255) * f).round();
    g = (255 + (174 - 255) * f).round();
    b = 255;
  } else {
    final f = (v - 0.5) * 2;
    r = (82 + (69 - 82) * f).round();
    g = (174 + (222 - 174) * f).round();
    b = (255 + (197 - 255) * f).round();
  }
  return (r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
}
