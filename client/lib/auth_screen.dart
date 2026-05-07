import 'package:flutter/material.dart';
import 'api_service.dart';
import 'models.dart';
import 'theme.dart';

class AuthScreen extends StatefulWidget {
  final void Function(AuthResponse auth) onSuccess;

  const AuthScreen({super.key, required this.onSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _api = const ApiService();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey  = GlobalKey<FormState>();

  bool _isLogin  = true;
  bool _loading  = false;
  bool _obscure  = true;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final auth = _isLogin
          ? await _api.login(_userCtrl.text.trim(), _passCtrl.text)
          : await _api.register(_userCtrl.text.trim(), _passCtrl.text);
      widget.onSuccess(auth);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.cloudCanvas,
      body: Center(
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.science_outlined,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                'Симулятор растворения',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
              ),
              const SizedBox(height: 32),

              // Card
              Container(
                decoration: BoxDecoration(
                  color: colors.elevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.borderLight),
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tabs
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.cloudCanvas,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.borderLight),
                        ),
                        child: Row(
                          children: [
                            _tab('Вход', _isLogin, () => setState(() {
                              _isLogin = true; _error = null;
                            }), colors),
                            _tab('Регистрация', !_isLogin, () => setState(() {
                              _isLogin = false; _error = null;
                            }), colors),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Username
                      TextFormField(
                        controller: _userCtrl,
                        decoration: const InputDecoration(labelText: 'Логин'),
                        autofocus: true,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Введите логин';
                          if (!_isLogin && v.trim().length < 3) return 'Минимум 3 символа';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Password
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 18,
                              color: colors.textMuted,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Введите пароль';
                          if (!_isLogin && v.length < 4) return 'Минимум 4 символа';
                          return null;
                        },
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFFB91C1C)),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(_isLogin ? 'Войти' : 'Создать аккаунт'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap, AppColorsExtension colors) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: active ? colors.elevated : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            boxShadow: active
                ? [const BoxShadow(color: Color(0x10000000), blurRadius: 4)]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: active ? colors.textPrimary : colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
