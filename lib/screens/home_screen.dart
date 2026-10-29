import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/auth_notifier.dart';
import '../widgets/catalog_scaffold.dart';

/// Главный экран: разделы, доступные роли текущего пользователя.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user!;
    final textTheme = Theme.of(context).textTheme;
    final sections = [
      for (final s in appSections)
        if (s.$4 != null && auth.can(s.$4!)) s,
    ];
    return CatalogScaffold(
      title: 'Главная',
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Здравствуйте, ${user.fullName}!',
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text('Роль: ${user.role.label}', style: textTheme.titleMedium),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final (label, path, icon, permission) in sections)
                SizedBox(
                  width: 260,
                  child: Card.outlined(
                    child: InkWell(
                      onTap: () => context.go(path),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, size: 32),
                            const SizedBox(height: 8),
                            Text(label, style: textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(permission!.label, style: textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
