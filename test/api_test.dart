import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recipe_finder/api.dart';

const _teriyaki = {
  'idMeal': '52772',
  'strMeal': 'Teriyaki Chicken Casserole',
  'strMealThumb': 'https://example.com/t.jpg',
  'strCategory': 'Chicken',
  'strArea': 'Japanese',
  'strInstructions': 'STEP 1\r\nPreheat oven.\r\n2. Mix sauce.\r\n\r\n350 degrees, bake 35 minutes.',
  'strIngredient1': 'soy sauce',
  'strMeasure1': '3/4 cup',
  'strIngredient2': ' ',
  'strMeasure2': ' ',
  'strIngredient3': 'water',
  'strMeasure3': null,
  'strYoutube': '',
};

MealApi _api(int status, Object body) => MealApi(MockClient((_) async => http.Response(jsonEncode(body), status)));

void main() {
  test('parses a recipe: skips blank ingredients and step numbering', () async {
    final meal = await _api(200, {
      'meals': [_teriyaki],
    }).meal('52772');
    expect(meal!.name, 'Teriyaki Chicken Casserole');
    expect(meal.ingredients.map((i) => '${i.measure}|${i.name}'), ['3/4 cup|Soy sauce', '|Water']);
    expect(meal.steps, ['Preheat oven.', 'Mix sauce.', '350 degrees, bake 35 minutes.']);
  });

  test('saved JSON reads back the same recipe', () async {
    final meal = (await _api(200, {
      'meals': [_teriyaki],
    }).meal('52772'))!;
    final again = Meal.fromJson(jsonDecode(jsonEncode(meal.toJson())) as Map<String, dynamic>);
    expect(again.toJson(), meal.toJson());
  });

  test('"meals": null means no results, not an error', () async {
    expect(await _api(200, {'meals': null}).search('zzzz'), isEmpty);
    expect(await _api(200, {'meals': null}).meal('0'), isNull);
  });

  test('no connection is OfflineException, bad status is ApiException', () async {
    final offline = MealApi(MockClient((_) async => throw http.ClientException('Failed to fetch')));
    await expectLater(offline.categories(), throwsA(isA<OfflineException>()));
    await expectLater(_api(500, {}).categories(), throwsA(isA<ApiException>()));
  });

  test('categories come from the names-only list, Breakfast first', () async {
    final api = _api(200, {
      'meals': [
        {'strCategory': 'Beef'},
        {'strCategory': 'Breakfast'},
        {'strCategory': 'Chicken'},
      ],
    });
    expect(await api.categories(), ['Breakfast', 'Beef', 'Chicken']);
  });
}
