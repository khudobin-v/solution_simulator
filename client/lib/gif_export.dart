import 'dart:math' show sqrt;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

typedef GifParams = ({
  List<List<List<int>>> grids,
  List<List<List<double>>> concs,
  double globalMaxConc,
  int delayMs,
  int scale,
});

/// Top-level function — runs inside compute() isolate.
Uint8List generateGif(GifParams p) {
  final N = p.grids[0].length;
  final W = N * p.scale;

  img.Image? animation;

  for (int fi = 0; fi < p.grids.length; fi++) {
    final grid = p.grids[fi];
    final conc = p.concs[fi];
    final frame = img.Image(width: W, height: W)
      ..frameDuration = p.delayMs;

    for (int r = 0; r < N; r++) {
      for (int c = 0; c < N; c++) {
        final concVal = (conc.isNotEmpty && r < conc.length && c < conc[r].length)
            ? conc[r][c]
            : 0.0;
        final (red, green, blue) = _cellRgb(grid[r][c], concVal, p.globalMaxConc);
        for (int dy = 0; dy < p.scale; dy++) {
          for (int dx = 0; dx < p.scale; dx++) {
            frame.setPixelRgb(c * p.scale + dx, r * p.scale + dy, red, green, blue);
          }
        }
      }
    }

    if (animation == null) {
      animation = frame;
    } else {
      animation.addFrame(frame);
    }
  }

  return Uint8List.fromList(img.encodeGif(animation!));
}

(int, int, int) _cellRgb(int state, double conc, double globalMaxConc) {
  // solid #171717
  if (state == 0) return (23, 23, 23);
  // semi (dissolving) #7D7D7D
  if (state == 1) return (125, 125, 125);
  // liquid: white → skyBlue (#52AEFF) → vividTeal (#45DEC5), sqrt-scaled
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
