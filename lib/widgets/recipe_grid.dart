import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api.dart';
import '../store.dart';
import '../theme.dart';
import 'focus_card.dart';
import 'snack.dart';

/// Network image with a tinted placeholder while loading and an icon if it
/// fails (offline). Decorative: the recipe name is always next to it.
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover});
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.network(
    url,
    fit: fit,
    excludeFromSemantics: true,
    frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : const ColoredBox(color: tint),
    errorBuilder: (_, _, _) => const ColoredBox(
      color: tint,
      child: Center(child: Icon(Icons.restaurant_rounded, color: muted)),
    ),
  );
}

/// Heart toggle. Saving needs the full recipe (for offline use), so a card
/// that only has a summary fetches it first.
class SaveButton extends ConsumerStatefulWidget {
  const SaveButton({super.key, required this.recipe});
  final MealSummary recipe;

  @override
  ConsumerState<SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends ConsumerState<SaveButton> {
  bool _busy = false;

  Future<void> _toggle() async {
    final saved = ref.read(savedProvider.notifier);
    final id = widget.recipe.id;
    if (ref.read(savedProvider).any((m) => m.id == id)) {
      final removed = saved.remove(id);
      showSnack(
        context,
        'Removed ${widget.recipe.name} from saved',
        actionLabel: 'Undo',
        onAction: () => saved.restore(removed),
      );
      return;
    }
    if (widget.recipe case final Meal meal) return saved.save(meal);

    setState(() => _busy = true);
    try {
      // Fetched directly, not through mealProvider: nothing on screen
      // listens to it here, so an autoDispose provider could be dropped
      // mid-request.
      final meal = await ref.read(mealApiProvider).meal(id);
      if (meal != null) saved.save(meal);
    } catch (_) {
      if (mounted) showSnack(context, "Couldn't save. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaved = ref.watch(savedProvider.select((list) => list.any((m) => m.id == widget.recipe.id)));
    return IconButton(
      onPressed: _busy ? null : _toggle,
      tooltip: isSaved ? 'Remove ${widget.recipe.name} from saved' : 'Save ${widget.recipe.name}',
      isSelected: isSaved,
      style: IconButton.styleFrom(backgroundColor: Colors.white, minimumSize: const Size(48, 48)),
      icon: _busy
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isSaved ? tealText : ink),
    );
  }
}

class RecipeCard extends StatelessWidget {
  const RecipeCard({super.key, required this.recipe, this.subtitle});
  final MealSummary recipe;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FocusCard(
      color: tint,
      onTap: () => openRecipe(context, recipe),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: NetImage(recipe.thumbMedium)),
                  Positioned(top: 4, right: 4, child: SaveButton(recipe: recipe)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Text(recipe.name, style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  subtitle!,
                  style: t.bodySmall?.copyWith(color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens the recipe page. A full [Meal] (from search, Featured or Saved) is
/// handed over so the page shows it at once; a summary is fetched by id.
void openRecipe(BuildContext context, MealSummary recipe) =>
    Navigator.pushNamed(context, '/recipe/${recipe.id}', arguments: recipe is Meal ? recipe : null);

/// Content width (at most 1200, with 20 px gutters) and the side padding that
/// centres it. Home and Saved share it so their grids line up.
(double width, double side) contentBounds(double maxWidth) {
  final width = (maxWidth < 1200 ? maxWidth : 1200.0) - 40;
  return (width, (maxWidth - width) / 2);
}

/// Column count and row height follow the width and the text size, so cards
/// never clip at large text sizes.
SliverGridDelegate recipeGridDelegate(BuildContext context, double width, {bool subtitle = false}) {
  final scale = textScale(context);
  final cols = (width / (160 * scale.clamp(1.0, 1.6))).floor().clamp(1, 6);
  const gap = 12.0;
  final cardWidth = (width - gap * (cols - 1)) / cols;
  final lines = (subtitle ? 3 : 2) * 20 * scale;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: cols,
    mainAxisSpacing: gap,
    crossAxisSpacing: gap,
    mainAxisExtent: (cardWidth - 16) * 3 / 4 + lines + 28,
  );
}

/// Grey card shapes while recipes load.
class GridSkeleton extends StatelessWidget {
  const GridSkeleton({super.key, required this.width});
  final double width;

  @override
  Widget build(BuildContext context) => SliverSemantics(
    label: 'Loading recipes',
    sliver: SliverGrid(
      gridDelegate: recipeGridDelegate(context, width),
      delegate: SliverChildBuilderDelegate(
        (_, _) => DecoratedBox(
          decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(16)),
        ),
        childCount: 6,
      ),
    ),
  );
}
