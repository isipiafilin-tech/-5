import 'package:flutter/material.dart';

import '../core/api_exceptions.dart';

/// Выполняет операцию и показывает результат сообщением; ошибку сервера
/// (403, 409, сбой сети) — понятным текстом, а не падением экрана.
Future<void> runWithMessage(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (success != null) {
      messenger.showSnackBar(SnackBar(content: Text(success)));
    }
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}
