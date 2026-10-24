import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// TheMealDB's public test key "1": free for development and educational use,
/// no sign-up. https://www.themealdb.com/api.php
const _base = 'https://www.themealdb.com/api/json/v1/1';

/// The design's first category chip; Home opens on it.
const breakfast = 'Breakfast';

/// The request never reached the server (no connection, DNS, blocked).
class OfflineException implements Exception {
  const OfflineException();
}

/// The server answered badly or too slowly.
class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What list endpoints return: enough for a card.
class MealSummary {
  const MealSummary({required this.id, required this.name, required this.thumb});
  final String id;
  final String name;
  final String thumb;

  /// TheMealDB's ~350 px preview (~45 KB vs ~125 KB): enough for cards.
  String get thumbMedium => thumb.isEmpty ? thumb : '$thumb/medium';
}

class Ingredient {
  const Ingredient(this.name, this.measure);
  final String name;
  final String measure;
}

class Meal extends MealSummary {
  const Meal({
    required super.id,
    required super.name,
    required super.thumb,
    required this.category,
    required this.area,
    required this.ingredients,
    required this.steps,
  });

  final String category;
  final String area;
  final List<Ingredient> ingredients;
  final List<String> steps;

  /// "Japanese · Chicken", for card subtitles.
  String get origin => [area, category].where((s) => s.isNotEmpty).join(' · ');

  /// Parses TheMealDB's flat shape (strIngredient1..20 / strMeasure1..20).
  /// Also reads back what [toJson] wrote, so saved recipes work offline.
  factory Meal.fromJson(Map<String, dynamic> j) {
    String? str(String k) {
      final v = (j[k] as String?)?.trim();
      return v == null || v.isEmpty ? null : v;
    }

    return Meal(
      id: j['idMeal'] as String,
      name: str('strMeal') ?? 'Untitled recipe',
      thumb: str('strMealThumb') ?? '',
      category: str('strCategory') ?? '',
      area: str('strArea') ?? str('strCountry') ?? '',
      ingredients: [
        for (var i = 1; i <= 20; i++)
          if (str('strIngredient$i') case final name?)
            Ingredient(name[0].toUpperCase() + name.substring(1), str('strMeasure$i') ?? ''),
      ],
      steps: splitSteps(str('strInstructions') ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'idMeal': id,
    'strMeal': name,
    'strMealThumb': thumb,
    'strCategory': category,
    'strArea': area,
    for (final (i, ing) in ingredients.indexed) ...{
      'strIngredient${i + 1}': ing.name,
      'strMeasure${i + 1}': ing.measure,
    },
    'strInstructions': steps.join('\n'),
  };
}

/// Instructions arrive as one blob: lines, sometimes "STEP 1" headers or
/// "1." prefixes. Returns clean steps without the numbering.
List<String> splitSteps(String text) => text
    .split(RegExp(r'\r?\n'))
    .map((l) => l.replaceFirst(RegExp(r'^\s*(step\s*\d+[.):]?|\d+[.)])\s*', caseSensitive: false), '').trim())
    .where((l) => l.length > 1)
    .toList();

class MealApi {
  MealApi([http.Client? client]) : _client = client ?? http.Client();
  final http.Client _client;

  Future<Map<String, dynamic>> _get(String path) async {
    final http.Response res;
    try {
      res = await _client.get(Uri.parse('$_base/$path')).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const ApiException('TheMealDB is taking too long to answer.');
    } on http.ClientException {
      throw const OfflineException();
    }
    if (res.statusCode != 200) {
      throw ApiException('TheMealDB returned an error (${res.statusCode}).');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// TheMealDB returns `{"meals": null}` for no results.
  List<Map<String, dynamic>> _meals(Map<String, dynamic> body) =>
      ((body['meals'] as List?) ?? const []).cast<Map<String, dynamic>>();

  MealSummary _summary(Map<String, dynamic> m) =>
      MealSummary(id: m['idMeal'] as String, name: m['strMeal'] as String, thumb: m['strMealThumb'] as String);

  /// Category names (the names-only list: ~0.4 KB instead of ~10 KB),
  /// Breakfast first as in the design.
  Future<List<String>> categories() async {
    final names = [for (final c in _meals(await _get('list.php?c=list'))) c['strCategory'] as String];
    return [...names.where((n) => n == breakfast), ...names.where((n) => n != breakfast)];
  }

  Future<List<MealSummary>> byCategory(String category) async =>
      _meals(await _get('filter.php?c=${Uri.encodeQueryComponent(category)}')).map(_summary).toList();

  /// Search returns whole recipes, so opening or saving a result needs no
  /// extra request.
  Future<List<Meal>> search(String query) async =>
      _meals(await _get('search.php?s=${Uri.encodeQueryComponent(query)}')).map(Meal.fromJson).toList();

  /// The free key has no "latest" or "popular" endpoint, so Featured is a few
  /// random picks (one request each), with duplicates dropped.
  Future<List<Meal>> featured() async {
    final picks = await Future.wait([for (var i = 0; i < 5; i++) _get('random.php')]);
    final byId = {
      for (final p in picks)
        for (final m in _meals(p)) m['idMeal']: Meal.fromJson(m),
    };
    return byId.values.toList();
  }

  /// Null when the id doesn't exist.
  Future<Meal?> meal(String id) async {
    final meals = _meals(await _get('lookup.php?i=${Uri.encodeQueryComponent(id)}'));
    return meals.isEmpty ? null : Meal.fromJson(meals.first);
  }
}

final mealApiProvider = Provider((ref) => MealApi());

final featuredProvider = FutureProvider((ref) => ref.watch(mealApiProvider).featured());

final categoriesProvider = FutureProvider((ref) => ref.watch(mealApiProvider).categories());

// The families below are autoDispose so a failure isn't cached: once nothing
// shows it, the next visit fetches again (e.g. after reconnecting). Category
// lists keep successful results for the session.
final mealsByCategoryProvider = FutureProvider.autoDispose.family<List<MealSummary>, String>((ref, category) async {
  final meals = await ref.watch(mealApiProvider).byCategory(category);
  ref.keepAlive();
  return meals;
});

final searchProvider = FutureProvider.autoDispose.family<List<MealSummary>, String>(
  (ref, query) => ref.watch(mealApiProvider).search(query),
);

final mealProvider = FutureProvider.autoDispose.family<Meal?, String>((ref, id) => ref.watch(mealApiProvider).meal(id));
