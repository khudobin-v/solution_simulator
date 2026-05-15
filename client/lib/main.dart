import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'dart:math' show Random;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'auth_screen.dart';
import 'gif_export.dart';
import 'pdf_report.dart';
import 'models.dart';
import 'grid_painter.dart';
import 'theme.dart';
import 'widgets/param_card.dart';
import 'widgets/stat_chip.dart';
import 'widgets/chart_panel.dart';
import 'widgets/animated_stat.dart';
import 'widgets/profile_panel.dart';
import 'widgets/settings_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token    = prefs.getString('token');
  final username = prefs.getString('username');
  runApp(DissolutionApp(initialToken: token, initialUsername: username));
}

class DissolutionApp extends StatefulWidget {
  final String? initialToken;
  final String? initialUsername;

  const DissolutionApp({super.key, this.initialToken, this.initialUsername});

  @override
  State<DissolutionApp> createState() => _DissolutionAppState();
}

class _DissolutionAppState extends State<DissolutionApp> {
  String? _token;
  String? _username;

  ThemeMode _themeMode = ThemeMode.system;
  Color _accent = const Color(0xFF171717);

  @override
  void initState() {
    super.initState();
    _token    = widget.initialToken;
    _username = widget.initialUsername;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('theme_mode') ?? 'system';
    final accentInt = prefs.getInt('accent_color') ?? 0xFF171717;
    setState(() {
      _themeMode = switch (modeStr) {
        'light'  => ThemeMode.light,
        'dark'   => ThemeMode.dark,
        _        => ThemeMode.system,
      };
      _accent = Color(accentInt);
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = switch (_themeMode) {
      ThemeMode.light  => 'light',
      ThemeMode.dark   => 'dark',
      _                => 'system',
    };
    await prefs.setString('theme_mode', modeStr);
    await prefs.setInt('accent_color', _accent.value);
  }

  Future<void> _onAuth(AuthResponse auth) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', auth.accessToken);
    await prefs.setString('username', auth.username);
    setState(() { _token = auth.accessToken; _username = auth.username; });
  }

  Future<void> _onLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('username');
    setState(() { _token = null; _username = null; });
  }

  void _changeThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _saveSettings();
  }

  void _changeAccent(Color color) {
    setState(() => _accent = color);
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Симулятор растворения',
      theme: buildTheme(accent: _accent),
      darkTheme: buildDarkTheme(accent: _accent),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: (_token == null || _username == null)
          ? AuthScreen(onSuccess: _onAuth)
          : SimulationScreen(
              token: _token!,
              username: _username!,
              onLogout: _onLogout,
              themeMode: _themeMode,
              accent: _accent,
              onThemeModeChanged: _changeThemeMode,
              onAccentChanged: _changeAccent,
            ),
    );
  }
}

class SimulationScreen extends StatefulWidget {
  final String token;
  final String username;
  final VoidCallback onLogout;
  final ThemeMode themeMode;
  final Color accent;
  final void Function(ThemeMode) onThemeModeChanged;
  final void Function(Color) onAccentChanged;

  const SimulationScreen({
    super.key,
    required this.token,
    required this.username,
    required this.onLogout,
    required this.themeMode,
    required this.accent,
    required this.onThemeModeChanged,
    required this.onAccentChanged,
  });

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  final _api = const ApiService();

  String _geometry = 'circle';
  double _temperature = 310.0;
  double _baseRate = 0.08;
  double _diffusionRate = 0.15;
  int _gridSize = 80;
  int _steps = 250;
  bool _autoSteps = false; // run until full dissolution
  int _seed = 42;
  int _poreCount = 5;

  bool _loading = false;
  bool _exportingGif = false;
  bool _exportingPdf = false;
  bool _saving = false;
  int _profileRefreshKey = 0;
  String? _error;
  SimulationResult? _result;
  double _globalMaxConc = 1.0; // max conc across ALL frames — consistent colour scale
  int _frameIdx = 0;
  bool _showChart = false;

  // Hover state for cell tooltip
  ({int row, int col})? _hoveredCell;
  Offset? _hoverPos;
  Size _gridCanvasSize = Size.zero;
  final _gridKey = GlobalKey();

  // Pan / zoom
  final _transformController = TransformationController();
  // Gesture tracking (not in setState — no rebuild needed)
  Offset? _gestureFocal;
  double _gestureScale = 1.0;

  // Playback
  bool _isPlaying = false;
  double _playFps = 8.0;
  Timer? _playTimer;

  // Elapsed / ETA during loading
  DateTime? _simStartTime;
  Timer? _elapsedTimer;
  double _elapsedMs = 0;
  // Performance of the LAST run — used to estimate next
  int _lastRunOps = 0;    // gridSize² × steps
  int _lastRunMs  = 0;    // milliseconds it took

  double? get _estimatedSeconds {
    if (_lastRunOps == 0 || _lastRunMs == 0) return null;
    final ops = _gridSize * _gridSize * _steps;
    return ops / _lastRunOps * (_lastRunMs / 1000.0);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _elapsedTimer?.cancel();
    _transformController.dispose();
    super.dispose();
  }

  void _startPlayback() {
    _playTimer?.cancel();
    setState(() => _isPlaying = true);
    _playTimer = Timer.periodic(
      Duration(milliseconds: (1000 / _playFps).round()),
      (_) {
        if (_result == null) { _stopPlayback(); return; }
        final last = _result!.frames.length - 1;
        if (_frameIdx >= last) {
          _stopPlayback();
          return;
        }
        setState(() => _frameIdx++);
      },
    );
  }

  void _stopPlayback() {
    _playTimer?.cancel();
    _playTimer = null;
    if (mounted) setState(() => _isPlaying = false);
  }

  void _togglePlayback() =>
      _isPlaying ? _stopPlayback() : _startPlayback();

  void _seekTo(int idx) {
    _stopPlayback();
    setState(() => _frameIdx = idx.clamp(0, (_result?.frames.length ?? 1) - 1));
  }

  static const _minScale = 0.5;
  static const _maxScale = 40.0;

  /// Zoom by [factor] around [viewportPoint] (defaults to viewport centre).
  void _applyZoom(double factor, {Offset? viewportPoint}) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final vp = viewportPoint ?? box.size.center(Offset.zero);
    final scene = _transformController.toScene(vp);
    final current = _transformController.value.getMaxScaleOnAxis();
    final clamped = (current * factor).clamp(_minScale, _maxScale);
    final realFactor = clamped / current;
    if ((realFactor - 1.0).abs() < 1e-6) return;
    final m = _transformController.value.clone();
    m.translateByDouble(scene.dx, scene.dy, 0, 1);
    m.scaleByDouble(realFactor, realFactor, 1, 1);
    m.translateByDouble(-scene.dx, -scene.dy, 0, 1);
    _transformController.value = m;
  }

  void _pan(Offset delta) {
    final m = _transformController.value.clone();
    m.translateByDouble(delta.dx, delta.dy, 0, 1);
    _transformController.value = m;
  }

  void _resetZoom() => _transformController.value = Matrix4.identity();

  String _geometryLabel(String g) => switch (g) {
        'circle' => 'Круг',
        'square' => 'Квадрат',
        'porous' => 'Пористая',
        _ => g,
      };

  Future<void> _exportGif() async {
    final result = _result;
    if (result == null) return;
    setState(() => _exportingGif = true);
    try {
      final scale = (400 / result.frames[0].grid.length).ceil().clamp(1, 8);
      final gifBytes = await compute(generateGif, (
        grids: result.frames.map((f) => f.grid).toList(),
        concs: result.frames.map((f) => f.conc).toList(),
        globalMaxConc: _globalMaxConc,
        delayMs: (1000 / _playFps).round(),
        scale: scale,
      ));
      final ts = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить GIF',
        fileName: 'dissolution_$ts.gif',
        type: FileType.custom,
        allowedExtensions: ['gif'],
      );
      if (path == null) return; // cancelled
      await File(path).writeAsBytes(gifBytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GIF сохранён: $path'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка экспорта: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingGif = false);
    }
  }

  Future<void> _exportPdf() async {
    final result = _result;
    if (result == null) return;
    setState(() => _exportingPdf = true);
    try {
      final pdfBytes = await generateReport(
        params: SimulationRequest(
          gridSize: _gridSize,
          steps: _steps,
          geometry: _geometry,
          temperature: _temperature,
          baseRate: _baseRate,
          diffusionRate: _diffusionRate,
          seed: _seed,
          poreCount: _poreCount,
        ),
        result: result,
        globalMaxConc: _globalMaxConc,
      );
      final ts = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить отчёт PDF',
        fileName: 'dissolution_report_$ts.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (path == null) return;
      await File(path).writeAsBytes(pdfBytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF сохранён: $path'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка экспорта PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<void> _saveResult() async {
    final result = _result;
    if (result == null) return;
    final nameCtrl = TextEditingController(
      text: '${_geometryLabel(_geometry)} ${_gridSize}×${_gridSize}',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Сохранить симуляцию'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Название'),
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сохранить')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      final dissolved =
          (1 - result.series.last.relativeMass) * 100;
      await _api.saveResult(
        widget.token,
        SaveResultRequest(
          name: name,
          geometry: _geometry,
          gridSize: _gridSize,
          steps: _steps,
          temperature: _temperature,
          baseRate: _baseRate,
          diffusionRate: _diffusionRate,
          seed: _seed,
          poreCount: _poreCount,
          initialSolidCells: result.initialSolidCells,
          finalSolidCells: result.finalSolidCells,
          dissolutionStep: result.dissolutionStep,
          dissolvedPercent: dissolved,
        ),
      );
      if (mounted) {
        setState(() => _profileRefreshKey++);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Симуляция сохранена в профиль')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _run() async {
    // Start elapsed timer (100ms for smooth progress)
    _simStartTime = DateTime.now();
    _elapsedMs = 0;
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {
          _elapsedMs =
              DateTime.now().difference(_simStartTime!).inMilliseconds.toDouble();
        });
      }
    });

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _frameIdx = 0;
    });
    try {
      final req = SimulationRequest(
        gridSize: _gridSize,
        steps: _autoSteps ? 2000 : _steps,
        geometry: _geometry,
        temperature: _temperature,
        baseRate: _baseRate,
        diffusionRate: _diffusionRate,
        seed: _seed,
        poreCount: _poreCount,
        runToCompletion: _autoSteps,
      );
      final result = await _api.runSimulation(req);
      // Record performance for next estimate
      _lastRunOps = _gridSize * _gridSize * _steps;
      _lastRunMs  =
          DateTime.now().difference(_simStartTime!).inMilliseconds;
      if (mounted) {
        // Global max concentration across ALL frames for consistent colour scale
        double gmax = 1e-9;
        for (final f in result.frames) {
          for (final row in f.conc) {
            for (final v in row) {
              if (v > gmax) gmax = v;
            }
          }
        }

        setState(() {
          _result = result;
          _globalMaxConc = gmax;
          _showChart = false;
          _frameIdx = 0;
          _isPlaying = false;
          _playTimer?.cancel();
          _playTimer = null;
          _transformController.value = Matrix4.identity();
          if (_autoSteps) {
            _steps = result.dissolutionStep.clamp(1, 2000);
          }
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _error =
            'Симуляция не успела завершиться. Уменьшите размер сетки или количество шагов.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isDark {
    final brightness = switch (widget.themeMode) {
      ThemeMode.dark   => Brightness.dark,
      ThemeMode.light  => Brightness.light,
      _                => MediaQuery.platformBrightnessOf(context),
    };
    return brightness == Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.cloudCanvas,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebar(),
          const VerticalDivider(width: 1),
          Expanded(child: _buildMain()),
        ],
      ),
    );
  }

  void _openProfile() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 380,
          height: 520,
          child: ProfilePanel(
            token: widget.token,
            username: widget.username,
            refreshTrigger: _profileRefreshKey,
            onLogout: () {
              Navigator.of(context).pop();
              widget.onLogout();
            },
            onLoad: (r) {
              Navigator.of(context).pop();
              _loadFromSaved(r);
            },
          ),
        ),
      ),
    );
  }

  void _loadFromSaved(SavedResult r) {
    setState(() {
      _geometry      = r.geometry;
      _gridSize      = r.gridSize;
      _steps         = r.steps;
      _temperature   = r.temperature;
      _baseRate      = r.baseRate;
      _diffusionRate = r.diffusionRate;
      _seed          = r.seed;
      _poreCount     = r.poreCount;
      _result        = null;
    });
  }

  Widget _buildSidebar() {
    final colors = context.appColors;
    return Container(
      width: 280,
      color: colors.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebarHeader(),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Геометрия',
                      tooltip: 'Форма твёрдого препарата в начале симуляции'),
                  const SizedBox(height: 8),
                  _geometrySelector(),
                  if (_geometry == 'porous') ...[
                    const SizedBox(height: 16),
                    _sectionLabel('Сид структуры',
                        tooltip:
                            'Начальное значение генератора случайных чисел.\nРазные сиды — разное расположение и размер пор'),
                    const SizedBox(height: 4),
                    ParamCard(
                      label: 'Сид: $_seed',
                      child: Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _seed.toDouble(),
                              min: 0,
                              max: 999,
                              divisions: 999,
                              onChanged: (v) =>
                                  setState(() => _seed = v.round()),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(
                                () => _seed = Random().nextInt(1000)),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.shuffle_rounded,
                                size: 16,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sectionLabel('Количество пор',
                        tooltip:
                            'Количество каналов-пустот внутри пористой структуры.\nБольше пор — быстрее растворение за счёт большей площади контакта'),
                    const SizedBox(height: 4),
                    ParamCard(
                      label: '$_poreCount',
                      child: Slider(
                        value: _poreCount.toDouble(),
                        min: 1,
                        max: 20,
                        divisions: 19,
                        onChanged: (v) =>
                            setState(() => _poreCount = v.round()),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _sectionLabel('Температура',
                      tooltip:
                          'Температура раствора в кельвинах.\nВлияет на скорость растворения по уравнению Аррениуса:\nk = k₀ · exp(α · (T − T₀))'),
                  const SizedBox(height: 4),
                  ParamCard(
                    label: 'T = ${_temperature.toStringAsFixed(0)} K',
                    child: Slider(
                      value: _temperature,
                      min: 270,
                      max: 370,
                      divisions: 100,
                      onChanged: (v) => setState(() => _temperature = v),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('Размер сетки',
                      tooltip:
                          'Количество ячеек по каждой стороне (N×N).\nБольшая сетка — выше точность, но дольше расчёт'),
                  const SizedBox(height: 4),
                  ParamCard(
                    label: '$_gridSize × $_gridSize',
                    child: Slider(
                      value: _gridSize.toDouble(),
                      min: 20,
                      max: 150,
                      divisions: 13,
                      onChanged: (v) =>
                          setState(() => _gridSize = v.round()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Steps header with Auto toggle
                  Row(
                    children: [
                      Expanded(
                        child: _sectionLabel('Шаги',
                            tooltip:
                                'Количество итераций симуляции.\nРежим «Авто» останавливается при полном растворении'),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _autoSteps = !_autoSteps),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _autoSteps
                                ? colors.accent
                                : colors.elevated,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: _autoSteps
                                  ? colors.accent
                                  : colors.borderLight,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 10,
                                color: _autoSteps
                                    ? Colors.white
                                    : colors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Авто',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _autoSteps
                                      ? Colors.white
                                      : colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ParamCard(
                    label: _autoSteps
                        ? 'Авто (до растворения)'
                        : '$_steps',
                    child: Opacity(
                      opacity: _autoSteps ? 0.35 : 1.0,
                      child: AbsorbPointer(
                        absorbing: _autoSteps,
                        child: Slider(
                          value: _steps.toDouble(),
                          min: 1,
                          max: 2000,
                          divisions: 39,
                          onChanged: (v) =>
                              setState(() => _steps = v.round()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('Базовая скорость',
                      tooltip:
                          'Константа скорости растворения k₀ при базовой температуре T₀.\nОпределяет вероятность перехода ячейки в жидкое состояние за один шаг'),
                  const SizedBox(height: 4),
                  ParamCard(
                    label: _baseRate.toStringAsFixed(3),
                    child: Slider(
                      value: _baseRate,
                      min: 0.01,
                      max: 0.30,
                      divisions: 29,
                      onChanged: (v) =>
                          setState(() => _baseRate = v),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('Диффузия',
                      tooltip:
                          'Коэффициент диффузии D растворённого вещества.\nОпределяет скорость выравнивания концентрации между соседними ячейками'),
                  const SizedBox(height: 4),
                  ParamCard(
                    label: _diffusionRate.toStringAsFixed(2),
                    child: Slider(
                      value: _diffusionRate,
                      min: 0.01,
                      max: 0.50,
                      divisions: 49,
                      onChanged: (v) =>
                          setState(() => _diffusionRate = v),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _run,
                      child: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Запустить'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _errorBanner(_error!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    final colors = context.appColors;
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colors.textPrimary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.science_outlined,
                color: colors.cloudCanvas, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            'Симулятор\nрастворения',
            style:
                Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
          ),
          const Spacer(),
          // Settings gear button
          Tooltip(
            message: 'Настройки',
            child: GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => Dialog(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: SettingsPanel(
                    currentMode: widget.themeMode,
                    currentAccent: widget.accent,
                    onThemeModeChanged: widget.onThemeModeChanged,
                    onAccentChanged: widget.onAccentChanged,
                  ),
                ),
              ),
              child: Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: colors.cloudCanvas,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: colors.borderLight),
                ),
                child: Icon(
                  Icons.settings_outlined,
                  size: 14,
                  color: colors.textMuted,
                ),
              ),
            ),
          ),
          Tooltip(
            message: widget.username,
            child: GestureDetector(
              onTap: _openProfile,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colors.cloudCanvas,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: colors.borderLight),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 15,
                  color: colors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _sectionLabel(String text, {String? tooltip}) {
    final colors = context.appColors;
    final label = Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: colors.textMuted,
      ),
    );
    if (tooltip == null) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        label,
        const SizedBox(width: 4),
        Tooltip(
          message: tooltip,
          preferBelow: false,
          waitDuration: const Duration(milliseconds: 300),
          child: Icon(
            Icons.info_outline_rounded,
            size: 11,
            color: colors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _geometrySelector() {
    final colors = context.appColors;
    const options = [
      ('circle', 'Круг', Icons.circle_outlined),
      ('square', 'Квадрат', Icons.crop_square_outlined),
      ('porous', 'Пористая', Icons.bubble_chart_outlined),
    ];
    return Row(
      children: options.map((opt) {
        final (val, label, icon) = opt;
        final selected = _geometry == val;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: val != 'porous' ? 6 : 0,
            ),
            child: GestureDetector(
              onTap: () => setState(() => _geometry = val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? colors.accent
                      : colors.elevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selected
                        ? colors.accent
                        : colors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(icon,
                        size: 18,
                        color: selected
                            ? Colors.white
                            : colors.textMuted),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _errorBanner(String msg) {
    final isDark = _isDark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D1515) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0xFF6B2020) : const Color(0xFFFCA5A5),
        ),
      ),
      child: Text(
        msg,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFFFF8080) : const Color(0xFFB91C1C),
        ),
      ),
    );
  }

  /// Compute the initial solid/liquid grid client-side (mirrors Python logic).
  List<List<int>> _computePreviewGrid() {
    final N = _gridSize;
    final grid = List.generate(N, (_) => List.filled(N, 2)); // all liquid
    final cx = N ~/ 2;
    final cy = N ~/ 2;
    final r = N ~/ 4;

    void setSolid(int i, int j) {
      if (i >= 0 && i < N && j >= 0 && j < N) grid[i][j] = 0;
    }
    void setLiquid(int i, int j) {
      if (i >= 0 && i < N && j >= 0 && j < N) grid[i][j] = 2;
    }

    switch (_geometry) {
      case 'circle':
        for (int i = 0; i < N; i++) {
          for (int j = 0; j < N; j++) {
            if ((i - cx) * (i - cx) + (j - cy) * (j - cy) <= r * r) {
              setSolid(i, j);
            }
          }
        }
      case 'square':
        for (int i = cx - r; i < cx + r; i++) {
          for (int j = cy - r; j < cy + r; j++) {
            setSolid(i, j);
          }
        }
      case 'porous':
      default:
        for (int i = cx - r; i < cx + r; i++) {
          for (int j = cy - r; j < cy + r; j++) {
            setSolid(i, j);
          }
        }
        final prMin = (r / 7).ceil().clamp(1, r);
        final prMax = (r / 3).ceil().clamp(prMin + 1, r);
        final margin = (r / 4).ceil().clamp(1, r - 1);
        final rng = Random(_seed);
        final span = 2 * (r - margin);
        if (span > 0) {
          for (int p = 0; p < _poreCount; p++) {
            final hi = cx - r + margin + rng.nextInt(span);
            final hj = cy - r + margin + rng.nextInt(span);
            final poreR = prMin + rng.nextInt(prMax - prMin + 1);
            for (int i = hi - poreR; i <= hi + poreR; i++) {
              for (int j = hj - poreR; j <= hj + poreR; j++) {
                if ((i - hi) * (i - hi) + (j - hj) * (j - hj) <=
                    poreR * poreR) {
                  setLiquid(i, j);
                }
              }
            }
          }
        }
    }
    return grid;
  }

  Widget _buildMain() {
    if (_result == null && !_loading) {
      return _buildPreviewView();
    }
    if (_loading) {
      return _buildLoadingView();
    }

    final result = _result!;
    final frame = result.frames[_frameIdx];
    final stepData = result.series[frame.step];

    return Column(
      children: [
        _buildTopBar(result),
        const Divider(height: 1),
        Expanded(
          child: _showChart
              ? ChartPanel(series: result.series)
              : _buildGridView(result, frame, stepData),
        ),
      ],
    );
  }

  Widget _buildTopBar(SimulationResult result) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Text(
            'Результаты эксперимента',
            style:
                Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
          ),
          const SizedBox(width: 16),
          StatChip(
            label: 'Растворено',
            value:
                '${((1 - result.series.last.relativeMass) * 100).toStringAsFixed(1)}%',
            color: colors.vividTeal,
          ),
          const SizedBox(width: 8),
          StatChip(
            label: 'Шаг завершения',
            value: result.dissolutionStep == _steps
                ? '> $_steps'
                : '${result.dissolutionStep}',
            color: colors.electricBlue,
          ),
          const SizedBox(width: 8),
          StatChip(
            label: 'Начальный объём',
            value: '${result.initialSolidCells} яч.',
            color: colors.textMuted,
          ),
          const Spacer(),
          // Save to profile
          Tooltip(
            message: 'Сохранить в профиль',
            child: GestureDetector(
              onTap: _saving ? null : _saveResult,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.elevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.borderLight),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_saving)
                      SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: colors.textMuted),
                      )
                    else
                      Icon(Icons.bookmark_add_outlined,
                          size: 16, color: colors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      _saving ? 'Сохранение…' : 'Сохранить',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // GIF export button
          Tooltip(
            message: 'Сохранить анимацию как GIF',
            child: GestureDetector(
              onTap: _exportingGif ? null : _exportGif,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _exportingGif
                      ? colors.cloudCanvas
                      : colors.elevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.borderLight),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_exportingGif)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: colors.textMuted,
                        ),
                      )
                    else
                      Icon(Icons.gif_box_outlined,
                          size: 16, color: colors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      _exportingGif ? 'Генерация…' : 'GIF',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // PDF export button
          Tooltip(
            message: 'Сохранить подробный отчёт в PDF',
            child: GestureDetector(
              onTap: _exportingPdf ? null : _exportPdf,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _exportingPdf
                      ? colors.cloudCanvas
                      : colors.elevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.borderLight),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_exportingPdf)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: colors.textMuted,
                        ),
                      )
                    else
                      Icon(Icons.picture_as_pdf_outlined,
                          size: 16, color: colors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      _exportingPdf ? 'Генерация…' : 'PDF',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _viewToggle(),
        ],
      ),
    );
  }

  Widget _viewToggle() {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.cloudCanvas,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleBtn(Icons.grid_on_rounded, !_showChart, () {
            setState(() => _showChart = false);
          }),
          _toggleBtn(Icons.show_chart_rounded, _showChart, () {
            setState(() => _showChart = true);
          }),
        ],
      ),
    );
  }

  Widget _toggleBtn(
      IconData icon, bool active, VoidCallback onTap) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? colors.accent
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icon,
            size: 16,
            color: active ? Colors.white : colors.textMuted),
      ),
    );
  }

  Widget _buildGridView(
      SimulationResult result, FrameData frame, StepData stepData) {
    final maxFrame = result.frames.length - 1;
    final isDark = _isDark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: MouseRegion(
                      key: _gridKey,
                      opaque: true,
                      cursor: SystemMouseCursors.precise,
                      onHover: (e) {
                        final box = _gridKey.currentContext
                            ?.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final sz = box.size;
                        final rows = frame.grid.length;
                        final cols = rows > 0 ? frame.grid[0].length : 1;

                        // Convert viewport position → scene (grid) position
                        final scene =
                            _transformController.toScene(e.localPosition);
                        if (scene.dx < 0 ||
                            scene.dy < 0 ||
                            scene.dx >= sz.width ||
                            scene.dy >= sz.height) {
                          if (_hoveredCell != null) {
                            setState(() {
                              _hoveredCell = null;
                              _hoverPos = null;
                            });
                          }
                          return;
                        }
                        final c = (scene.dx / (sz.width / cols))
                            .floor()
                            .clamp(0, cols - 1);
                        final r = (scene.dy / (sz.height / rows))
                            .floor()
                            .clamp(0, rows - 1);
                        setState(() {
                          _hoveredCell = (row: r, col: c);
                          _hoverPos = e.localPosition;
                          _gridCanvasSize = sz;
                        });
                      },
                      onExit: (_) => setState(() {
                        _hoveredCell = null;
                        _hoverPos = null;
                      }),
                      child: Stack(
                        children: [
                          // Grid with manual pan/zoom
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: Listener(
                                behavior: HitTestBehavior.opaque,
                                onPointerSignal: (event) {
                                  if (event is PointerScrollEvent) {
                                    if (event.kind == PointerDeviceKind.trackpad) {
                                      _pan(Offset(
                                        -event.scrollDelta.dx,
                                        -event.scrollDelta.dy,
                                      ));
                                    } else {
                                      final factor = event.scrollDelta.dy > 0
                                          ? 1 / 1.12
                                          : 1.12;
                                      _applyZoom(factor,
                                          viewportPoint: event.localPosition);
                                    }
                                  }
                                },
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onScaleStart: (d) {
                                    _gestureFocal = d.localFocalPoint;
                                    _gestureScale = 1.0;
                                  },
                                  onScaleUpdate: (d) {
                                    if (_gestureFocal != null) {
                                      _pan(d.localFocalPoint - _gestureFocal!);
                                    }
                                    _gestureFocal = d.localFocalPoint;
                                    final factor = _gestureScale > 0
                                        ? d.scale / _gestureScale
                                        : 1.0;
                                    if ((factor - 1.0).abs() > 0.001) {
                                      _applyZoom(factor,
                                          viewportPoint: d.localFocalPoint);
                                    }
                                    _gestureScale = d.scale;
                                  },
                                  onScaleEnd: (_) {
                                    _gestureFocal = null;
                                    _gestureScale = 1.0;
                                  },
                                  child: ValueListenableBuilder<Matrix4>(
                                    valueListenable: _transformController,
                                    builder: (_, matrix, child) => Transform(
                                      transform: matrix,
                                      child: child,
                                    ),
                                    child: CustomPaint(
                                      painter: GridPainter(
                                        frame.grid,
                                        frame.conc,
                                        _globalMaxConc,
                                        hoveredCell: _hoveredCell,
                                        isDark: isDark,
                                      ),
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Border
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: context.appColors.borderLight),
                                ),
                              ),
                            ),
                          ),
                          // Zoom controls
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: IgnorePointer(
                              ignoring: false,
                              child: _buildZoomControls(),
                            ),
                          ),
                          // Tooltip
                          if (_hoveredCell != null && _hoverPos != null)
                            _buildCellTooltip(
                              _hoveredCell!,
                              _hoverPos!,
                              frame,
                              _gridCanvasSize,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 1,
                  child: _buildStatsPanel(result, stepData),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildScrubber(result, maxFrame),
        ],
      ),
    );
  }

  Widget _buildStatsPanel(
      SimulationResult result, StepData stepData) {
    final colors = context.appColors;
    final numStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: colors.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final headStyle = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: colors.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: -0.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Step heading ──────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('Шаг ',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary)),
            AnimatedStat(
              value: stepData.step.toDouble(),
              formatter: (v) => v.round().toString(),
              style: headStyle,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'из $_steps шагов',
          style: TextStyle(
              fontSize: 12, color: colors.textMuted),
        ),

        const SizedBox(height: 20),

        // ── Solid cells ───────────────────────────────────────────
        _animStatRow(
          'Твёрдых ячеек',
          value: stepData.solidCells.toDouble(),
          formatter: (v) => v.round().toString(),
          style: numStyle,
        ),
        const SizedBox(height: 12),

        // ── Relative mass ─────────────────────────────────────────
        _animStatRow(
          'Относит. масса',
          value: stepData.relativeMass * 100,
          formatter: (v) => '${v.toStringAsFixed(1)}%',
          style: numStyle,
        ),
        const SizedBox(height: 12),

        // ── Mean concentration ────────────────────────────────────
        _animStatRow(
          'Ср. концентрация',
          value: stepData.meanConcentration,
          formatter: (v) => v.toStringAsFixed(4),
          style: numStyle,
        ),

        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 16),
        _legendItem(colors.solidCell, 'Твёрдое'),
        const SizedBox(height: 8),
        _legendItem(colors.semiCell, 'Растворяется'),
        const SizedBox(height: 8),
        _legendGradient(),
      ],
    );
  }

  Widget _animStatRow(
    String label, {
    required double value,
    required String Function(double) formatter,
    required TextStyle style,
  }) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: colors.textMuted)),
        const SizedBox(height: 2),
        AnimatedStat(
          value: value,
          formatter: formatter,
          style: style,
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label,
      {bool border = false}) {
    final colors = context.appColors;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: border
                ? Border.all(color: colors.borderLight)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary)),
      ],
    );
  }

  Widget _buildZoomControls() {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.elevated.withAlpha(230),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.borderLight),
        boxShadow: const [
          BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _zoomBtn(Icons.add, () => _applyZoom(1.5)),
          Container(height: 1, color: colors.borderLight),
          _zoomBtn(Icons.remove, () => _applyZoom(1 / 1.5)),
          Container(height: 1, color: colors.borderLight),
          _zoomBtn(Icons.fit_screen_rounded, _resetZoom),
        ],
      ),
    );
  }

  Widget _zoomBtn(IconData icon, VoidCallback onTap) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        child: Icon(icon, size: 14, color: colors.textSecondary),
      ),
    );
  }

  Widget _buildCellTooltip(
    ({int row, int col}) cell,
    Offset pos,
    FrameData frame,
    Size canvasSize,
  ) {
    final colors = context.appColors;
    final state = frame.grid[cell.row][cell.col];
    final hasConc = frame.conc.isNotEmpty &&
        cell.row < frame.conc.length &&
        cell.col < frame.conc[cell.row].length;
    final conc = hasConc ? frame.conc[cell.row][cell.col] : 0.0;
    final pct = _globalMaxConc > 1e-9
        ? (conc / _globalMaxConc * 100).toStringAsFixed(1)
        : '0.0';

    final stateLabel = switch (state) {
      0 => 'Твёрдое',
      1 => 'Растворяется',
      _ => 'Жидкость',
    };
    final stateColor = switch (state) {
      0 => colors.solidCell,
      1 => colors.semiCell,
      _ => colors.electricBlue,
    };

    const tw = 144.0;
    const th = 72.0;
    double dx = pos.dx + 14;
    double dy = pos.dy - th - 10;
    if (dx + tw > canvasSize.width) dx = pos.dx - tw - 14;
    if (dy < 0) dy = pos.dy + 14;

    return Positioned(
      left: dx,
      top: dy,
      child: IgnorePointer(
        child: Container(
          width: tw,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: colors.elevated,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.borderLight),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: stateColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    stateLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Конц  ${conc.toStringAsFixed(4)}',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'Отн   $pct %',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendGradient() {
    final colors = context.appColors;
    const stops = [0.0, 0.25, 0.50, 0.75, 1.0];
    const labels = ['0', '25', '50', '75', '100'];
    const barH = 10.0;
    const barW = 160.0;

    final bgColor = _isDark ? const Color(0xFF0D1827) : const Color(0xFFFFFFFF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'РАСТВОР',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        // Gradient bar
        Container(
          width: barW,
          height: barH,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: LinearGradient(
              colors: [
                bgColor,
                colors.skyBlue,
                colors.vividTeal,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(color: colors.borderLight),
          ),
        ),
        // Tick marks
        SizedBox(
          width: barW,
          height: 6,
          child: Stack(
            children: stops.map((s) {
              return Positioned(
                left: s * (barW - 1),
                top: 0,
                child: Container(
                  width: 1,
                  height: 4,
                  color: colors.borderLight,
                ),
              );
            }).toList(),
          ),
        ),
        // Labels
        SizedBox(
          width: barW,
          height: 14,
          child: Stack(
            children: List.generate(stops.length, (i) {
              final x = stops[i] * barW;
              return Positioned(
                left: (x - 10).clamp(0, barW - 20),
                top: 0,
                child: SizedBox(
                  width: 20,
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      color: colors.textMuted,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        // Unit label
        Text(
          '% от макс. концентрации',
          style: TextStyle(fontSize: 9, color: colors.textMuted),
        ),
      ],
    );
  }

  Widget _buildScrubber(SimulationResult result, int maxFrame) {
    final colors = context.appColors;
    final currentStep = result.frames[_frameIdx].step;
    final totalSteps = result.series.last.step;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: colors.elevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Transport controls ──────────────────────────────────
          Row(
            children: [
              // First frame
              _playerBtn(Icons.skip_previous_rounded,
                  () => _seekTo(0)),
              // Step back
              _playerBtn(Icons.chevron_left_rounded,
                  () => _seekTo(_frameIdx - 1)),
              const SizedBox(width: 2),
              // Play / Pause
              GestureDetector(
                onTap: _togglePlayback,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Icon(
                    _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              // Step forward
              _playerBtn(Icons.chevron_right_rounded,
                  () => _seekTo(_frameIdx + 1)),
              // Last frame
              _playerBtn(Icons.skip_next_rounded,
                  () => _seekTo(maxFrame)),

              const SizedBox(width: 12),

              // Step counter
              Text(
                'Шаг $currentStep',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                ' / $totalSteps',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textMuted,
                ),
              ),
              Text(
                '  (кадр ${_frameIdx + 1}/${maxFrame + 1})',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textMuted,
                ),
              ),

              const Spacer(),

              // Speed selector
              Text('Скорость',
                  style: TextStyle(
                      fontSize: 11, color: colors.textMuted)),
              const SizedBox(width: 6),
              ...[4.0, 8.0, 16.0, 30.0].map((fps) {
                final label = fps < 10
                    ? '${fps.toInt()}fps'
                    : '${fps.toInt()}fps';
                final active = _playFps == fps;
                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _playFps = fps);
                      if (_isPlaying) {
                        _stopPlayback();
                        _startPlayback();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: active
                            ? colors.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: active
                              ? colors.accent
                              : colors.borderLight,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: active
                              ? Colors.white
                              : colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),

          const SizedBox(height: 6),

          // ── Timeline scrubber ───────────────────────────────────
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 12),
            ),
            child: Slider(
              value: _frameIdx.toDouble(),
              min: 0,
              max: maxFrame.toDouble(),
              divisions: maxFrame > 0 ? maxFrame : 1,
              onChanged: (v) => _seekTo(v.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerBtn(IconData icon, VoidCallback onTap) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: colors.textSecondary),
      ),
    );
  }

  Widget _buildLoadingView() {
    final colors = context.appColors;
    final est = _estimatedSeconds;
    final elapsedSec = _elapsedMs / 1000.0;
    final progress = est != null
        ? (elapsedSec / est).clamp(0.0, 0.95)
        : null;
    final remaining = est != null
        ? (est - elapsedSec).ceil().clamp(0, 9999)
        : null;

    return Center(
      child: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Идёт симуляция',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$_gridSize × $_gridSize  ·  ${_geometryLabel(_geometry)}  ·  $_steps шагов',
              style: TextStyle(fontSize: 13, color: colors.textMuted),
            ),

            const SizedBox(height: 24),

            // Smooth progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: progress != null
                  ? TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: progress),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      builder: (_, value, __) => LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        backgroundColor: colors.borderLight,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            colors.accent),
                      ),
                    )
                  : LinearProgressIndicator(
                      minHeight: 6,
                      backgroundColor: colors.borderLight,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          colors.accent),
                    ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Text(
                  'Прошло: ${elapsedSec.toStringAsFixed(1)} с',
                  style: TextStyle(
                      fontSize: 12, color: colors.textMuted),
                ),
                const Spacer(),
                if (est != null) ...[
                  Text(
                    progress! >= 0.95
                        ? 'Завершение…'
                        : '~${remaining}с осталось',
                    style: TextStyle(
                        fontSize: 12, color: colors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ] else
                  Text(
                    'Оценка…',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewView() {
    final colors = context.appColors;
    final previewGrid = _computePreviewGrid();
    final emptyConc = <List<double>>[];
    final isDark = _isDark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // ── Preview grid ────────────────────────────────────────
          Expanded(
            flex: 3,
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: CustomPaint(
                        painter: GridPainter(
                          previewGrid, emptyConc, 1.0,
                          isDark: isDark,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: colors.borderLight),
                        ),
                      ),
                    ),
                  ),
                  // "Preview" badge top-left
                  Positioned(
                    top: 10,
                    left: 10,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.elevated.withAlpha(220),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                              color: colors.borderLight),
                        ),
                        child: Text(
                          'Начальное состояние',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          // ── Right panel ─────────────────────────────────────────
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Готово к запуску',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_gridSize × $_gridSize ячеек',
                  style: TextStyle(
                      fontSize: 12, color: colors.textMuted),
                ),
                const SizedBox(height: 20),
                _placeholderStat('Твёрдых ячеек'),
                const SizedBox(height: 12),
                _placeholderStat('Относит. масса'),
                const SizedBox(height: 12),
                _placeholderStat('Ср. концентрация'),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                _legendItem(colors.solidCell, 'Твёрдое'),
                const SizedBox(height: 8),
                _legendItem(colors.semiCell, 'Растворяется'),
                const SizedBox(height: 8),
                _legendGradient(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderStat(String label) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: colors.textMuted)),
        const SizedBox(height: 2),
        Text('—',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colors.textMuted)),
      ],
    );
  }

}
