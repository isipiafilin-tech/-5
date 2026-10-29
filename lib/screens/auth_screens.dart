import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../state/auth_notifier.dart';
import '../validation/validators.dart';

/// Карточка формы по центру экрана.
class _AuthCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _AuthCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _decoration(String label) =>
    InputDecoration(labelText: label, border: const OutlineInputBorder());

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // После входа маршрутизатор сам вернёт пользователя по адресу from.
      await context.read<AuthNotifier>().login(
        _username.text.trim(),
        _password.text,
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason = context.watch<AuthNotifier>().logoutReason;
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final scheme = Theme.of(context).colorScheme;
    return _AuthCard(
      title: 'Вход',
      children: [
        if (reason != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            color: scheme.tertiaryContainer,
            child: Row(
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 8),
                Expanded(child: Text(reason)),
              ],
            ),
          ),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _username,
                decoration: _decoration('Логин'),
                validator: requiredField('Введите логин'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                decoration: _decoration('Пароль'),
                obscureText: true,
                validator: requiredField('Введите пароль'),
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Войти'),
        ),
        TextButton(
          onPressed: () => context.go(
            from == null
                ? '/register'
                : '/register?from=${Uri.encodeComponent(from)}',
          ),
          child: const Text('Регистрация'),
        ),
      ],
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  Map<String, String> _serverErrors = {};
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_username, _fullName, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _serverErrors = {};
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthNotifier>().register(
        username: _username.text.trim(),
        password: _password.text,
        email: _email.text.trim(),
        fullName: _fullName.text.trim(),
      );
    } on ValidationException catch (e) {
      setState(() => _serverErrors = e.errors);
      _formKey.currentState!.validate();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? Function(String?) _with(String key, Validator validator) =>
      (value) => _serverErrors[key] ?? validator(value);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final password = _password.text;
    return _AuthCard(
      title: 'Регистрация',
      children: [
        Form(
          key: _formKey,
          // Проверка по мере ввода, а не только по нажатию кнопки.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _username,
                decoration: _decoration('Логин'),
                validator: _with(
                  'username',
                  all([requiredField(), length(3, 30)]),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullName,
                decoration: _decoration('ФИО'),
                validator: _with(
                  'fullName',
                  all([requiredField(), length(2, 100)]),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                decoration: _decoration('Электронная почта'),
                validator: _with('email', all([requiredField(), email()])),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                decoration: _decoration('Пароль'),
                obscureText: true,
                validator: _with(
                  'password',
                  all([requiredField(), strongPassword()]),
                ),
              ),
              const SizedBox(height: 8),
              for (final (label, ok) in passwordRules)
                Row(
                  children: [
                    Icon(
                      ok(password) ? Icons.check_circle : Icons.cancel_outlined,
                      size: 18,
                      color: ok(password) ? Colors.green : scheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(label),
                  ],
                ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Зарегистрироваться'),
        ),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Уже есть учётная запись — войти'),
        ),
      ],
    );
  }
}

/// Экран отказа: адрес существует, но текущей роли недоступен.
class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthNotifier>().user?.role.label ?? '—';
    final from = GoRouterState.of(context).uri.queryParameters['from'] ?? '';
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 64, color: scheme.error),
              const SizedBox(height: 12),
              Text(
                'Доступ запрещён',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Роли «$role» недоступен адрес $from',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('На главную'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
