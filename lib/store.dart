import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Loaded once in main() and injected with an override.
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

/// Items taken out of a list, with the positions they had, for Undo.
typedef Removed<T> = List<(int, T)>;

(List<T>, Removed<T>) _split<T>(List<T> list, bool Function(T) remove) {
  final kept = <T>[];
  final removed = <(int, T)>[];
  for (final (i, item) in list.indexed) {
    remove(item) ? removed.add((i, item)) : kept.add(item);
  }
  return (kept, removed);
}

/// Puts removed items back where they were, skipping any already back.
List<T> _restore<T>(List<T> list, Removed<T> removed, Object Function(T) key) {
  final present = {for (final i in list) key(i)};
  final out = [...list];
  for (final (i, item) in removed) {
    if (present.add(key(item))) out.insert(i.clamp(0, out.length), item);
  }
  return out;
}

/// Saved recipes are stored whole, so they open with no connection.
class SavedRecipes extends Notifier<List<Meal>> {
  static const _key = 'saved_recipes';

  @override
  List<Meal> build() {
    final raw = ref.watch(prefsProvider).getString(_key);
    if (raw == null) return [];
    return [for (final m in jsonDecode(raw) as List) Meal.fromJson(m as Map<String, dynamic>)];
  }

  void save(Meal meal) {
    if (!state.any((m) => m.id == meal.id)) _set([meal, ...state]);
  }

  /// Returns what was removed so the caller can offer Undo.
  Removed<Meal> remove(String id) {
    final (kept, removed) = _split(state, (m) => m.id == id);
    _set(kept);
    return removed;
  }

  void restore(Removed<Meal> removed) => _set(_restore(state, removed, (m) => m.id));

  void _set(List<Meal> meals) {
    state = meals;
    ref.read(prefsProvider).setString(_key, jsonEncode([for (final m in meals) m.toJson()]));
  }
}

final savedProvider = NotifierProvider<SavedRecipes, List<Meal>>(SavedRecipes.new);

/// What the recipe page shows: the saved copy when there is one (instant and
/// offline), otherwise a fetch. Saved is read once, not watched, so un-saving
/// on the page doesn't swap the recipe out mid-view.
final recipeProvider = Provider.autoDispose.family<AsyncValue<Meal?>, String>((ref, id) {
  final saved = ref.read(savedProvider).where((m) => m.id == id).firstOrNull;
  return saved != null ? AsyncData(saved) : ref.watch(mealProvider(id));
});

String _keyOf(String recipe, String name) => '$recipe|${name.toLowerCase()}';

class ShoppingItem {
  const ShoppingItem({required this.name, required this.measure, required this.recipe, this.done = false});
  final String name;
  final String measure;
  final String recipe;
  final bool done;

  /// One item per ingredient per dish; "Soy Sauce" and "soy sauce" are the same.
  String get key => _keyOf(recipe, name);

  ShoppingItem copyWith({bool? done}) =>
      ShoppingItem(name: name, measure: measure, recipe: recipe, done: done ?? this.done);

  Map<String, dynamic> toJson() => {'name': name, 'measure': measure, 'recipe': recipe, 'done': done};
  factory ShoppingItem.fromJson(Map<String, dynamic> j) => ShoppingItem(
    name: j['name'] as String,
    measure: j['measure'] as String,
    recipe: j['recipe'] as String,
    done: j['done'] as bool,
  );
}

/// One ingredient across every dish that needs it, for the "All items" view.
/// Measures are free text ("3/4 cup", "2 cloves"), so they're listed per dish,
/// not added up.
class CombinedItem {
  const CombinedItem(this.name, this.items);
  final String name;
  final List<ShoppingItem> items;

  bool get done => items.every((i) => i.done);
}

/// Groups by ingredient name, ignoring case ("Garlic" = "garlic"), in the
/// order each ingredient was first added.
List<CombinedItem> combine(List<ShoppingItem> items) {
  final groups = <String, List<ShoppingItem>>{};
  for (final i in items) {
    groups.putIfAbsent(i.name.toLowerCase(), () => []).add(i);
  }
  return [for (final g in groups.values) CombinedItem(g.first.name, g)];
}

/// The design's "cart": ingredients to buy, grouped by recipe.
class ShoppingList extends Notifier<List<ShoppingItem>> {
  static const _key = 'shopping_list';

  @override
  List<ShoppingItem> build() {
    final raw = ref.watch(prefsProvider).getString(_key);
    if (raw == null) return [];
    return [for (final i in jsonDecode(raw) as List) ShoppingItem.fromJson(i as Map<String, dynamic>)];
  }

  /// Adds what isn't already on the list; returns how many were added.
  /// TheMealDB sometimes lists an ingredient twice in one recipe ("Soy Sauce"
  /// 1 tsp and 1 tablespoon); those become one item, "1 tsp + 1 tablespoon".
  int addAll(Meal meal, Iterable<Ingredient> ingredients) {
    final present = {for (final i in state) i.key};
    final fresh = <String, ShoppingItem>{};
    for (final i in ingredients) {
      if (present.contains(_keyOf(meal.name, i.name))) continue;
      final same = fresh[i.name.toLowerCase()];
      final measure = [?same?.measure, i.measure].where((m) => m.isNotEmpty).join(' + ');
      fresh[i.name.toLowerCase()] = ShoppingItem(name: same?.name ?? i.name, measure: measure, recipe: meal.name);
    }
    _set([...state, ...fresh.values]);
    return fresh.length;
  }

  void remove(String recipe, String name) => _set([...state.where((i) => i.key != _keyOf(recipe, name))]);

  void setDone(Iterable<ShoppingItem> items, bool done) {
    final keys = {for (final i in items) i.key};
    _set([for (final i in state) keys.contains(i.key) ? i.copyWith(done: done) : i]);
  }

  /// Returns the removed items so the caller can offer Undo.
  Removed<ShoppingItem> removeItems(Iterable<ShoppingItem> items) {
    final keys = {for (final i in items) i.key};
    return _remove((i) => keys.contains(i.key));
  }

  /// Returns the removed items so the caller can offer Undo.
  Removed<ShoppingItem> clearDone() => _remove((i) => i.done);

  Removed<ShoppingItem> _remove(bool Function(ShoppingItem) test) {
    final (kept, removed) = _split(state, test);
    _set(kept);
    return removed;
  }

  void restore(Removed<ShoppingItem> removed) => _set(_restore(state, removed, (i) => i.key));

  void _set(List<ShoppingItem> items) {
    state = items;
    ref.read(prefsProvider).setString(_key, jsonEncode([for (final i in items) i.toJson()]));
  }
}

final shoppingProvider = NotifierProvider<ShoppingList, List<ShoppingItem>>(ShoppingList.new);
