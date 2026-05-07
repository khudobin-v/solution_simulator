import 'package:flutter/material.dart';
import '../theme.dart';

class SettingsPanel extends StatelessWidget {
  final ThemeMode currentMode;
  final Color currentAccent;
  final void Function(ThemeMode) onThemeModeChanged;
  final void Function(Color) onAccentChanged;

  const SettingsPanel({
    super.key,
    required this.currentMode,
    required this.currentAccent,
    required this.onThemeModeChanged,
    required this.onAccentChanged,
  });

  static const _accentSwatches = [
    Color(0xFF171717),
    Color(0xFF0070F3),
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFFDC2626),
    Color(0xFFD97706),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: colors.textPrimary),
              const SizedBox(width: 8),
              Text(
                'Настройки',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Theme mode
          Text(
            'ТЕМА',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: colors.cloudCanvas,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.borderLight),
            ),
            child: Row(
              children: [
                _modeButton(context, ThemeMode.light,  'Светлая',  colors),
                _modeButton(context, ThemeMode.dark,   'Тёмная',   colors),
                _modeButton(context, ThemeMode.system, 'Системная', colors),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Accent color
          Text(
            'АКЦЕНТ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: _accentSwatches.map((c) => _swatchButton(context, c, colors)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _modeButton(
    BuildContext context,
    ThemeMode mode,
    String label,
    AppColorsExtension colors,
  ) {
    final selected = currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => onThemeModeChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected ? colors.elevated : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: selected
                ? [const BoxShadow(color: Color(0x12000000), blurRadius: 4)]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? colors.textPrimary : colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _swatchButton(
    BuildContext context,
    Color color,
    AppColorsExtension colors,
  ) {
    final selected = currentAccent.value == color.value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onAccentChanged(color),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? colors.textPrimary : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: selected
                ? [BoxShadow(color: color.withAlpha(80), blurRadius: 6, spreadRadius: 1)]
                : null,
          ),
          child: selected
              ? Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: color.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}
