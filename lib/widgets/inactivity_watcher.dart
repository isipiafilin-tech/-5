import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Выход по неактивности. Таймер сбрасывается любым действием пользователя;
/// за [warning] до выхода показывается предупреждение.
class InactivityWatcher extends StatefulWidget {
  final Duration timeout;
  final Duration warning;
  final VoidCallback onTimeout;
  final Widget child;

  const InactivityWatcher({
    super.key,
    required this.timeout,
    required this.warning,
    required this.onTimeout,
    required this.child,
  });

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher> {
  Timer? _warnTimer;
  Timer? _timer;
  bool _warning = false;

  @override
  void initState() {
    super.initState();
    // Клавиатуру слушаем глобально: у обёртки над приложением нет фокуса,
    // и KeyboardListener не узнал бы о наборе текста в форме.
    HardwareKeyboard.instance.addHandler(_onKey);
    _restart();
  }

  bool _onKey(KeyEvent event) {
    _restart();
    return false; // событие не обработано — передаём дальше
  }

  void _restart() {
    _warnTimer?.cancel();
    _timer?.cancel();
    if (_warning) setState(() => _warning = false);
    _warnTimer = Timer(widget.timeout - widget.warning, () {
      if (mounted) setState(() => _warning = true);
    });
    _timer = Timer(widget.timeout, widget.onTimeout);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _warnTimer?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Listener(
      // Перехват без поглощения: событие идёт дальше к виджетам.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restart(),
      onPointerMove: (_) => _restart(),
      onPointerSignal: (_) => _restart(),
      child: Stack(
        children: [
          widget.child,
          if (_warning)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: scheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Нет активности: сеанс завершится через '
                          '${widget.warning.inSeconds} секунд.',
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                      TextButton(
                        onPressed: _restart,
                        child: const Text('Продолжить работу'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
