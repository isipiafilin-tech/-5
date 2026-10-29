import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/lookup_notifier.dart';

/// Карточка записи: загрузка, «не найдено», список полей, переход к изменению.
class DetailView<T> extends StatefulWidget {
  final String title;
  final Future<T?> Function() load;
  final String notFoundText;
  final List<(String, Widget)> Function(T item) fields;
  final String Function(T item) headline;

  /// Адрес формы изменения; null — у роли нет права менять запись.
  final String? editPath;

  /// Дополнительные действия под полями карточки.
  final List<Widget> Function(T item)? actions;

  const DetailView({
    super.key,
    required this.title,
    required this.load,
    required this.notFoundText,
    required this.fields,
    required this.headline,
    this.editPath,
    this.actions,
  });

  @override
  State<DetailView<T>> createState() => _DetailViewState<T>();
}

class _DetailViewState<T> extends State<DetailView<T>> {
  late final Future<T?> _future = widget.load();

  @override
  void initState() {
    super.initState();
    // Подписи связей (авторы, жанры) берутся из кэша справочников.
    context.read<LookupNotifier>().ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.editPath != null)
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.go(widget.editPath!),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<T?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Не удалось загрузить: ${snapshot.error}'),
            );
          }
          final item = snapshot.data;
          if (item == null) return Center(child: Text(widget.notFoundText));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(widget.headline(item), style: textTheme.headlineSmall),
              const SizedBox(height: 12),
              for (final (label, value) in widget.fields(item))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 180,
                        child: Text(label, style: textTheme.bodySmall),
                      ),
                      Expanded(child: value),
                    ],
                  ),
                ),
              if (widget.actions != null) ...[
                const SizedBox(height: 16),
                Wrap(spacing: 12, children: widget.actions!(item)),
              ],
            ],
          );
        },
      ),
    );
  }
}
