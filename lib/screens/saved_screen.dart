import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store.dart';
import '../widgets/recipe_grid.dart';
import '../widgets/status_view.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key, required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedProvider);
    if (saved.isEmpty) {
      return StatusView(
        icon: Icons.favorite_border_rounded,
        title: 'No saved recipes yet',
        message: 'Tap the heart on any recipe to keep it here. Saved recipes open even when you are offline.',
        actionLabel: 'Browse recipes',
        onAction: onBrowse,
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final (width, side) = contentBounds(box.maxWidth);
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, 16, side, 12),
              sliver: SliverToBoxAdapter(
                child: Semantics(
                  header: true,
                  child: Text('Saved recipes (${saved.length})', style: Theme.of(context).textTheme.headlineSmall),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, 0, side, 24),
              sliver: SliverGrid(
                gridDelegate: recipeGridDelegate(context, width, subtitle: true),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => RecipeCard(recipe: saved[i], subtitle: saved[i].origin),
                  childCount: saved.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
