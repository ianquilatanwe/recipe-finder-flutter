import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/focus_card.dart';
import '../widgets/recipe_grid.dart';
import '../widgets/snack.dart';
import '../widgets/status_view.dart';

class RecipeScreen extends ConsumerWidget {
  const RecipeScreen({super.key, required this.id, this.meal});
  final String id;

  /// Handed over when the opener already has the whole recipe; deep links and
  /// category cards only have the id.
  final Meal? meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = meal != null ? AsyncData<Meal?>(meal) : ref.watch(recipeProvider(id));
    if (recipe.value case final meal?) {
      return Scaffold(
        body: SafeArea(top: false, child: _RecipeBody(meal: meal)),
      );
    }
    // Loading, error and not-found have no photo, so they get a plain bar with
    // a way back.
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: recipe.when(
        loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading recipe')),
        // The fetch inside recipeProvider is what failed, so that's what to redo.
        error: (e, _) => StatusView.error(e, onRetry: () => ref.invalidate(mealProvider(id))),
        data: (_) => StatusView(
          icon: Icons.search_off_rounded,
          title: 'Recipe not found',
          message: 'This recipe may have been removed.',
          actionLabel: 'Back to recipes',
          onAction: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

class _RecipeBody extends StatelessWidget {
  const _RecipeBody({required this.meal});
  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final topInset = MediaQuery.paddingOf(context).top;
    final buttons = Positioned(
      top: topInset + 8,
      left: 16,
      right: 16,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
            style: IconButton.styleFrom(backgroundColor: Colors.white, minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.close_rounded, color: ink),
          ),
          const Spacer(),
          SaveButton(recipe: meal),
        ],
      ),
    );
    final image = NetImage(meal.thumb);

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [image, buttons]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(32, topInset + 32, 32, 32),
              child: _Details(meal: meal),
            ),
          ),
        ],
      );
    }
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              AspectRatio(aspectRatio: 1.1, child: image),
              // The white sheet overlaps the photo, as in the design.
              Transform.translate(
                offset: const Offset(0, -28),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: _Details(meal: meal),
                ),
              ),
            ],
          ),
        ),
        buttons,
      ],
    );
  }
}

class _Details extends StatefulWidget {
  const _Details({required this.meal});
  final Meal meal;

  @override
  State<_Details> createState() => _DetailsState();
}

class _DetailsState extends State<_Details> {
  bool _showSteps = false;

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(meal.name, style: t.headlineSmall)),
        const SizedBox(height: 20),
        // TheMealDB has no kcal/time/nutrition, so the design's four
        // nutrition tiles show what the API does have.
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (meal.category.isNotEmpty) _Fact(Icons.restaurant_menu_rounded, meal.category),
            if (meal.area.isNotEmpty) _Fact(Icons.public_rounded, meal.area),
            _Fact(Icons.egg_alt_outlined, '${meal.ingredients.length} ingredients'),
            _Fact(Icons.format_list_numbered_rounded, '${meal.steps.length} steps'),
          ],
        ),
        const SizedBox(height: 24),
        _Toggle(showSteps: _showSteps, onChanged: (v) => setState(() => _showSteps = v)),
        const SizedBox(height: 24),
        if (_showSteps) _Steps(meal: meal) else _Ingredients(meal: meal),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 150),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 20, color: ink),
        ),
        const SizedBox(width: 10),
        Flexible(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
      ],
    ),
  );
}

/// The design's dark "Ingredients | Instructions" pill.
class _Toggle extends StatelessWidget {
  const _Toggle({required this.showSteps, required this.onChanged});
  final bool showSteps;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool value) {
      final selected = showSteps == value;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: FocusCard(
            radius: 12,
            color: selected ? deep : Colors.transparent,
            onTap: () => onChanged(value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : ink),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [tab('Ingredients', false), tab('Instructions', true)]),
    );
  }
}

class _Ingredients extends ConsumerWidget {
  const _Ingredients({required this.meal});
  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    // Only this recipe's items, as one string: ticking things off on the
    // shopping list doesn't rebuild this page.
    final onList = ref
        .watch(
          shoppingProvider.select(
            (items) => [
              for (final i in items)
                if (i.recipe == meal.name) i.name.toLowerCase(),
            ].join('\n'),
          ),
        )
        .split('\n')
        .toSet();
    final list = ref.read(shoppingProvider.notifier);
    final allAdded = meal.ingredients.every((i) => onList.contains(i.name.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wrap: at large text sizes the button drops under the heading.
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ingredients', style: t.titleLarge),
                  Text('${meal.ingredients.length} items', style: t.bodyMedium?.copyWith(color: muted)),
                ],
              ),
              TextButton(
                onPressed: allAdded
                    ? null
                    : () {
                        final added = list.addAll(meal, meal.ingredients);
                        final navigator = Navigator.of(context);
                        showSnack(
                          context,
                          'Added $added ${added == 1 ? 'ingredient' : 'ingredients'} for ${meal.name}',
                          actionLabel: 'View',
                          // The snackbar may still be up on the shopping list
                          // itself (via the cart button): replace that page
                          // rather than stacking a second copy.
                          onAction: () =>
                              navigator.pushNamedAndRemoveUntil('/shopping', (r) => r.settings.name != '/shopping'),
                        );
                      },
                child: Text(allAdded ? 'All on your list' : 'Add all to list'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final ing in meal.ingredients)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _IngredientRow(meal: meal, ingredient: ing, added: onList.contains(ing.name.toLowerCase())),
          ),
      ],
    );
  }
}

class _IngredientRow extends ConsumerWidget {
  const _IngredientRow({required this.meal, required this.ingredient, required this.added});
  final Meal meal;
  final Ingredient ingredient;
  final bool added;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final list = ref.read(shoppingProvider.notifier);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: NetImage(
              'https://www.themealdb.com/images/ingredients/${Uri.encodeComponent(ingredient.name)}-small.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ingredient.name, style: t.titleSmall),
                if (ingredient.measure.isNotEmpty)
                  Text(ingredient.measure, style: t.bodyMedium?.copyWith(color: muted)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => added ? list.remove(meal.name, ingredient.name) : list.addAll(meal, [ingredient]),
            tooltip: added ? 'Remove ${ingredient.name} from shopping list' : 'Add ${ingredient.name} to shopping list',
            isSelected: added,
            icon: Icon(added ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, color: tealText),
          ),
        ],
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.meal});
  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Instructions', style: t.titleLarge),
        const SizedBox(height: 12),
        for (final (i, step) in meal.steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: teal,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(color: deep, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(step, style: t.bodyLarge?.copyWith(height: 1.5))),
              ],
            ),
          ),
      ],
    );
  }
}
