import 'package:flutter/material.dart';
import '../api_service.dart';
import '../models.dart';
import '../theme.dart';

class ProfilePanel extends StatefulWidget {
  final String token;
  final String username;
  final int refreshTrigger;
  final VoidCallback onLogout;
  final void Function(SavedResult) onLoad;

  const ProfilePanel({
    super.key,
    required this.token,
    required this.username,
    required this.refreshTrigger,
    required this.onLogout,
    required this.onLoad,
  });

  @override
  State<ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<ProfilePanel> {
  final _api = const ApiService();
  List<SavedResult>? _results;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProfilePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTrigger != widget.refreshTrigger) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _api.getResults(widget.token);
      if (mounted) setState(() { _results = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _delete(SavedResult r) async {
    try {
      await _api.deleteResult(widget.token, r.id);
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: colors.elevated,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.borderLight)),
            ),
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded,
                    size: 16, color: colors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.username,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Обновить',
                  child: GestureDetector(
                    onTap: _load,
                    child: Icon(Icons.refresh_rounded,
                        size: 15, color: colors.textMuted),
                  ),
                ),
                const SizedBox(width: 10),
                Tooltip(
                  message: 'Выйти',
                  child: GestureDetector(
                    onTap: widget.onLogout,
                    child: Icon(Icons.logout_rounded,
                        size: 15, color: colors.textMuted),
                  ),
                ),
              ],
            ),
          ),

          // Subtitle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Text(
                  'СОХРАНЁННЫЕ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: colors.textMuted,
                  ),
                ),
                if (_results != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: colors.cloudCanvas,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.borderLight),
                    ),
                    child: Text(
                      '${_results!.length}',
                      style: TextStyle(
                          fontSize: 9, color: colors.textMuted),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: colors.textMuted),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: TextStyle(
                                fontSize: 11, color: colors.textMuted)),
                      )
                    : _results!.isEmpty
                        ? Center(
                            child: Text('Нет сохранённых симуляций',
                                style: TextStyle(
                                    fontSize: 12, color: colors.textMuted)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            itemCount: _results!.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, i) => _ResultCard(
                              result: _results![i],
                              onLoad: () => widget.onLoad(_results![i]),
                              onDelete: () => _delete(_results![i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final SavedResult result;
  final VoidCallback onLoad;
  final VoidCallback onDelete;

  const _ResultCard({
    required this.result,
    required this.onLoad,
    required this.onDelete,
  });

  String _geomLabel(String g) => switch (g) {
        'circle' => 'Круг',
        'square' => 'Квадрат',
        'porous' => 'Пористая',
        _ => g,
      };

  IconData _geomIcon(String g) => switch (g) {
        'circle' => Icons.circle_outlined,
        'square' => Icons.crop_square_outlined,
        'porous' => Icons.bubble_chart_outlined,
        _ => Icons.science_outlined,
      };

  String _date(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')} '
             '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return iso.substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.cloudCanvas,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.borderLight),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + delete
          Row(
            children: [
              Icon(_geomIcon(result.geometry),
                  size: 13, color: colors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  result.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: Icon(Icons.close_rounded,
                    size: 13, color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Stats row
          Row(
            children: [
              _chip('${result.dissolvedPercent.toStringAsFixed(1)}%',
                  colors.vividTeal),
              const SizedBox(width: 4),
              _chip(_geomLabel(result.geometry), colors.electricBlue),
              const SizedBox(width: 4),
              _chip('${result.gridSize}×${result.gridSize}',
                  colors.textMuted),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _date(result.createdAt),
            style: TextStyle(fontSize: 10, color: colors.textMuted),
          ),
          const SizedBox(height: 8),

          // Load button
          SizedBox(
            width: double.infinity,
            height: 28,
            child: OutlinedButton(
              onPressed: onLoad,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: BorderSide(color: colors.borderLight),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5)),
              ),
              child: Text(
                'Загрузить параметры',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
