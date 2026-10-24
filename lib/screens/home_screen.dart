import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/about_button.dart';
import '../widgets/focus_card.dart';
import '../widgets/recipe_grid.dart';
import '../widgets/status_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _category;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => setState(() => _query = text.trim()));
  }

  void _clearSearch() {
    _search.clear();
    _debounce?.cancel();
    setState(() => _query = '');
  }

  FutureProvider<List<MealSummary>> _listProvider(String category) =>
      _query.isNotEmpty ? searchProvider(_query) : mealsByCategoryProvider(category);

  Future<void> _refresh(FutureProvider<List<MealSummary>> list) async {
    // Errors show in the sections themselves; the spinner only needs to stop.
    await Future.wait<Object?>([
      ref.refresh(featuredProvider.future),
      ref.refresh(categoriesProvider.future),
      ref.refresh(list.future),
    ]).catchError((_) => <Object?>[]);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    // Categories failing means nothing on this screen can load.
    if (categories.hasError && !categories.hasValue) {
      return StatusView.error(categories.error!, onRetry: () => ref.invalidate(categoriesProvider));
    }
    if (categories.value case []) {
      return StatusView(
        icon: Icons.restaurant_rounded,
        title: 'No recipes right now',
        message: 'TheMealDB sent an empty menu. Try again in a moment.',
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(categoriesProvider),
      );
    }
    // Breakfast's recipes start loading at once, alongside the category list
    // (the API puts Breakfast first; if it ever lacks it, the first wins).
    final category = _category ?? categories.value?.first ?? breakfast;
    final list = _listProvider(category);
    final t = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () => _refresh(list),
      child: LayoutBuilder(
        builder: (context, box) {
          final (width, side) = contentBounds(box.maxWidth);
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 16, side, 0),
                sliver: SliverList.list(
                  children: [
                    const _Header(),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _search,
                      onChanged: _onSearch,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (v) => setState(() => _query = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search recipes',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: _clearSearch,
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    if (_query.isEmpty) ...[
                      const SizedBox(height: 24),
                      Text('Featured', style: t.titleLarge),
                      const SizedBox(height: 12),
                      const _Featured(),
                      const SizedBox(height: 24),
                      Text('Category', style: t.titleLarge),
                      const SizedBox(height: 12),
                      _CategoryChips(
                        names: categories.value,
                        selected: category,
                        onSelected: (c) => setState(() => _category = c),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Semantics(
                      header: true,
                      liveRegion: _query.isNotEmpty,
                      child: Text(_query.isEmpty ? '$category recipes' : 'Results for "$_query"', style: t.titleLarge),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 0, side, 24),
                sliver: _RecipeResults(provider: list, width: width, query: _query, onClear: _clearSearch),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 12
        ? 'Good morning'
        : h < 18
        ? 'Good afternoon'
        : 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final count = ref.watch(shoppingProvider.select((l) => l.where((i) => !i.done).length));
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.wb_sunny_outlined, size: 18, color: ink),
                  const SizedBox(width: 6),
                  Flexible(child: Text(_greeting, style: t.bodyMedium)),
                ],
              ),
              const SizedBox(height: 4),
              Text('What will you cook today?', style: t.headlineSmall),
            ],
          ),
        ),
        const AboutButton(),
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/shopping'),
          tooltip: count == 0 ? 'Shopping list' : 'Shopping list, $count items',
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            child: const Icon(Icons.shopping_cart_outlined, color: ink),
          ),
        ),
      ],
    );
  }
}

class _Featured extends ConsumerWidget {
  const _Featured();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final height = 120 + 56 * textScale(context);
    return SizedBox(
      height: height,
      child: ref
          .watch(featuredProvider)
          .when(
            skipLoadingOnRefresh: true,
            loading: () => Semantics(
              label: 'Loading featured recipes',
              child: DecoratedBox(
                decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(16)),
              ),
            ),
            // Featured is a bonus: a small inline retry instead of a full error screen.
            error: (e, _) => Material(
              color: tint,
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => ref.invalidate(featuredProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(e is OfflineException ? "Offline. Retry featured" : 'Retry featured'),
                ),
              ),
            ),
            data: (meals) => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: meals.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _FeaturedCard(meal: meals[i]),
            ),
          ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.meal});
  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: 300,
      child: FocusCard(
        color: teal,
        onTap: () => openRecipe(context, meal),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      meal.name,
                      style: t.titleMedium?.copyWith(color: deep),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      meal.origin,
                      style: t.bodySmall?.copyWith(color: deep),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox.square(dimension: 120, child: ClipOval(child: NetImage(meal.thumbMedium))),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.names, required this.selected, required this.onSelected});

  /// Null while loading.
  final List<String>? names;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final names = this.names;
    return SizedBox(
      height: 48 * textScale(context),
      child: names == null
          ? Semantics(label: 'Loading categories', child: const SizedBox.expand())
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: names.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ChoiceChip(
                label: Text(names[i]),
                selected: names[i] == selected,
                onSelected: (_) => onSelected(names[i]),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
            ),
    );
  }
}

class _RecipeResults extends ConsumerWidget {
  const _RecipeResults({required this.provider, required this.width, required this.query, required this.onClear});
  final FutureProvider<List<MealSummary>> provider;
  final double width;
  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(provider)
      .when(
        skipLoadingOnRefresh: true,
        loading: () => GridSkeleton(width: width),
        error: (e, _) => SliverToBoxAdapter(child: StatusView.error(e, onRetry: () => ref.invalidate(provider))),
        data: (meals) => meals.isEmpty
            ? SliverToBoxAdapter(
                child: StatusView(
                  icon: Icons.search_off_rounded,
                  title: 'No recipes found',
                  message: query.isEmpty
                      ? 'This category has no recipes yet.'
                      : 'Nothing matches "$query". Try another dish or ingredient.',
                  actionLabel: query.isEmpty ? null : 'Clear search',
                  onAction: onClear,
                ),
              )
            : SliverGrid(
                gridDelegate: recipeGridDelegate(context, width),
                delegate: SliverChildBuilderDelegate((_, i) => RecipeCard(recipe: meals[i]), childCount: meals.length),
              ),
      );
}
