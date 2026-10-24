import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_finder/api.dart';
import 'package:recipe_finder/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

ShoppingItem _item(String name, String recipe, {bool done = false}) =>
    ShoppingItem(name: name, measure: '', recipe: recipe, done: done);

void main() {
  test('combine groups an ingredient across dishes, ignoring case, in first-added order', () {
    final combined = combine([
      _item('Garlic', 'Pad Thai'),
      _item('Rice', 'Pad Thai'),
      _item('garlic', 'Teriyaki', done: true),
    ]);
    expect(combined.map((c) => c.name), ['Garlic', 'Rice']);
    expect(combined.first.items.map((i) => i.recipe), ['Pad Thai', 'Teriyaki']);
    expect(combined.first.done, isFalse); // only one of the two is checked
  });

  test('an ingredient listed twice in one recipe becomes one item with both amounts', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(await SharedPreferences.getInstance())],
    );
    addTearDown(container.dispose);
    final meal = Meal.fromJson({
      'idMeal': '1',
      'strMeal': 'Beef and Broccoli',
      'strIngredient1': 'Soy Sauce',
      'strMeasure1': '1 tsp',
      'strIngredient2': 'Beef',
      'strMeasure2': '1 lb',
      'strIngredient3': 'soy sauce',
      'strMeasure3': '1 tablespoon',
    });
    final list = container.read(shoppingProvider.notifier);

    expect(list.addAll(meal, meal.ingredients), 2);
    expect(container.read(shoppingProvider).map((i) => '${i.name}: ${i.measure}'), [
      'Soy Sauce: 1 tsp + 1 tablespoon',
      'Beef: 1 lb',
    ]);
    expect(list.addAll(meal, meal.ingredients), 0); // already on the list
  });

  test('Undo puts removed items back where they were, without duplicates', () async {
    SharedPreferences.setMockInitialValues({
      'shopping_list':
          '[{"name":"A","measure":"","recipe":"X","done":false},'
          '{"name":"B","measure":"","recipe":"X","done":true},'
          '{"name":"C","measure":"","recipe":"Y","done":false},'
          '{"name":"D","measure":"","recipe":"Y","done":true}]',
    });
    final container = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(await SharedPreferences.getInstance())],
    );
    addTearDown(container.dispose);
    final list = container.read(shoppingProvider.notifier);
    List<String> names() => container.read(shoppingProvider).map((i) => i.name).toList();

    final removed = list.clearDone();
    expect(names(), ['A', 'C']);
    list.restore(removed);
    expect(names(), ['A', 'B', 'C', 'D']);
    list.restore(removed); // a second Undo adds nothing
    expect(names(), ['A', 'B', 'C', 'D']);
  });
}
