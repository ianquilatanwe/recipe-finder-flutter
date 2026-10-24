import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets/snack.dart';
import '../widgets/status_view.dart';

class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  bool _byDish = true;

  void _removed(String message, Removed<ShoppingItem> removed) {
    final list = ref.read(shoppingProvider.notifier);
    showSnack(context, message, actionLabel: 'Undo', onAction: () => list.restore(removed));
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(shoppingProvider);
    final list = ref.read(shoppingProvider.notifier);
    final t = Theme.of(context).textTheme;
    final byRecipe = <String, List<ShoppingItem>>{};
    for (final i in items) {
      byRecipe.putIfAbsent(i.recipe, () => []).add(i);
    }
    final left = items.where((i) => !i.done).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping list'),
        actions: [
          if (items.any((i) => i.done))
            TextButton(
              onPressed: () {
                final removed = list.clearDone();
                _removed('Removed ${removed.length} checked ${removed.length == 1 ? 'item' : 'items'}', removed);
              },
              child: const Text('Clear checked'),
            ),
        ],
      ),
      body: items.isEmpty
          ? StatusView(
              icon: Icons.shopping_cart_outlined,
              title: 'Your shopping list is empty',
              message: 'Open a recipe and tap "Add all to list", or add ingredients one by one.',
              actionLabel: 'Find a recipe',
              onAction: () => Navigator.pop(context),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('By dish'), icon: Icon(Icons.restaurant_menu_rounded)),
                          ButtonSegment(
                            value: false,
                            label: Text('All items'),
                            icon: Icon(Icons.format_list_bulleted_rounded),
                          ),
                        ],
                        selected: {_byDish},
                        onSelectionChanged: (s) => setState(() => _byDish = s.first),
                        showSelectedIcon: false,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Text(
                        '$left left to buy · ${byRecipe.length} ${byRecipe.length == 1 ? 'dish' : 'dishes'}',
                        style: t.bodyMedium?.copyWith(color: muted),
                      ),
                    ),
                    if (_byDish)
                      for (final MapEntry(key: recipe, value: group) in byRecipe.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 20, 12, 4),
                          child: Semantics(
                            header: true,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: recipe, style: t.titleMedium),
                                  TextSpan(
                                    text: '  ${group.length} ${group.length == 1 ? 'ingredient' : 'ingredients'}',
                                    style: t.bodySmall?.copyWith(color: muted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        for (final item in group)
                          _ItemTile(
                            name: item.name,
                            detail: item.measure,
                            value: item.done,
                            onChanged: () => list.setDone([item], !item.done),
                            onRemove: () => _removed('Removed ${item.name}', list.removeItems([item])),
                          ),
                      ]
                    else ...[
                      const SizedBox(height: 8),
                      for (final c in combine(items))
                        _ItemTile(
                          name: c.name,
                          // Which dish each amount is for, one line per dish.
                          detail: [
                            for (final i in c.items)
                              i.measure.isEmpty ? 'for ${i.recipe}' : '${i.measure} for ${i.recipe}',
                          ].join('\n'),
                          // Some dishes checked, some not: a dash, not a tick.
                          value: c.done ? true : (c.items.any((i) => i.done) ? null : false),
                          onChanged: () => list.setDone(c.items, !c.done),
                          onRemove: () => _removed(
                            c.items.length == 1
                                ? 'Removed ${c.name}'
                                : 'Removed ${c.name} from ${c.items.length} dishes',
                            list.removeItems(c.items),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.name,
    required this.detail,
    required this.value,
    required this.onChanged,
    required this.onRemove,
  });

  final String name;
  final String detail;

  /// null = only some of the dishes are checked.
  final bool? value;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    value: value,
    tristate: value == null,
    onChanged: (_) => onChanged(),
    controlAffinity: ListTileControlAffinity.leading,
    title: Text(
      name,
      style: value == true ? const TextStyle(decoration: TextDecoration.lineThrough, color: muted) : null,
    ),
    subtitle: detail.isEmpty ? null : Text(detail),
    secondary: IconButton(onPressed: onRemove, tooltip: 'Remove $name', icon: const Icon(Icons.delete_outline_rounded)),
  );
}
