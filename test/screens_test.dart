import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_finder/api.dart';
import 'package:recipe_finder/main.dart';
import 'package:recipe_finder/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _meal = Meal.fromJson({
  'idMeal': '1',
  'strMeal': 'A very long recipe name that keeps going to test wrapping on small phones',
  'strMealThumb': 'https://example.com/a.jpg',
  'strCategory': 'Breakfast',
  'strArea': 'Japanese',
  'strInstructions': 'Mix.\nBake.',
  'strIngredient1': 'soy sauce',
  'strMeasure1': '3/4 cup',
});

class FakeApi extends MealApi {
  FakeApi([this.error]);

  /// Set to null mid-test to "reconnect".
  Object? error;
  List<String> categoryList = const ['Breakfast', 'Beef'];

  Future<T> _or<T>(T value) async => error == null ? value : throw error!;

  @override
  Future<List<String>> categories() => _or(categoryList);
  @override
  Future<List<Meal>> featured() => _or([_meal]);
  @override
  Future<List<MealSummary>> byCategory(String category) => _or(List.filled(6, _meal));
  @override
  Future<List<Meal>> search(String query) => _or(<Meal>[]);
  int lookups = 0;
  @override
  Future<Meal?> meal(String id) {
    lookups++;
    return _or(_meal);
  }
}

const _oneItem = '[{"name":"Soy sauce","measure":"3/4 cup","recipe":"Teriyaki","done":false}]';

Future<void> pumpApp(
  WidgetTester tester,
  MealApi api, {
  String route = '/',
  double text = 1,
  String shoppingList = _oneItem,
  List<Meal> saved = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    'shopping_list': shoppingList,
    'saved_recipes': jsonEncode([for (final m in saved) m.toJson()]),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs), mealApiProvider.overrideWithValue(api)],
      retry: (_, _) => null,
      child: MediaQuery(
        data: MediaQueryData(
          size: tester.view.physicalSize / tester.view.devicePixelRatio,
          textScaler: TextScaler.linear(text),
        ),
        child: const RecipeApp(),
      ),
    ),
  );
  if (route != '/') {
    tester.state<NavigatorState>(find.byType(Navigator).first).pushNamed(route);
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no connection shows the offline state with a retry', (tester) async {
    await pumpApp(tester, FakeApi(const OfflineException()));
    expect(find.text("You're offline"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
  });

  testWidgets('a server error shows its message with a retry', (tester) async {
    await pumpApp(tester, FakeApi(const ApiException('TheMealDB returned an error (500).')));
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('TheMealDB returned an error (500).'), findsOneWidget);
  });

  testWidgets('an offline recipe page still has a way back', (tester) async {
    await pumpApp(tester, FakeApi(const OfflineException()), route: '/recipe/1');
    expect(find.text("You're offline"), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text("You're offline"), findsOneWidget); // home, also offline
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('"Add all" snackbar names the dish, View opens the list, and it goes away', (tester) async {
    await pumpApp(tester, FakeApi(), route: '/recipe/1', shoppingList: '[]');
    await tester.ensureVisible(find.text('Add all to list'));
    await tester.tap(find.text('Add all to list'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.textContaining('Added 1 ingredient for A very long recipe name'), findsOneWidget);

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(find.text('Shopping list'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('the "Add all" snackbar hides by itself', (tester) async {
    await pumpApp(tester, FakeApi(), route: '/recipe/1', shoppingList: '[]');
    await tester.ensureVisible(find.text('Add all to list'));
    await tester.tap(find.text('Add all to list'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750)); // slide-in done, 4 s timer starts
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('All items merges an ingredient across dishes and checks it everywhere', (tester) async {
    await pumpApp(
      tester,
      FakeApi(),
      route: '/shopping',
      shoppingList:
          '[{"name":"Garlic","measure":"2 cloves","recipe":"Pad Thai","done":false},'
          '{"name":"Rice","measure":"1 cup","recipe":"Pad Thai","done":false},'
          '{"name":"garlic","measure":"","recipe":"Teriyaki","done":false}]',
    );
    expect(find.textContaining('Pad Thai  2 ingredients', findRichText: true), findsOneWidget); // By dish header
    expect(find.text('Garlic'), findsOneWidget);
    expect(find.text('garlic'), findsOneWidget);

    await tester.tap(find.text('All items'));
    await tester.pumpAndSettle();
    expect(find.text('Garlic'), findsOneWidget);
    expect(find.text('garlic'), findsNothing);
    expect(find.text('2 cloves for Pad Thai\nfor Teriyaki'), findsOneWidget);

    await tester.tap(find.text('Garlic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('By dish'));
    await tester.pumpAndSettle();
    final checked = tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).where((c) => c.value == true);
    expect(checked, hasLength(2));
    expect(find.text('1 left to buy · 2 dishes'), findsOneWidget);
  });

  testWidgets('View still works after leaving the recipe page', (tester) async {
    await pumpApp(tester, FakeApi(), route: '/recipe/1', shoppingList: '[]');
    await tester.ensureVisible(find.text('Add all to list'));
    await tester.tap(find.text('Add all to list'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();
    expect(find.text('What will you cook today?'), findsOneWidget); // back on Home

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Shopping list'), findsOneWidget);
  });

  testWidgets('a recipe that failed offline loads on the next visit after reconnecting', (tester) async {
    final api = FakeApi(const OfflineException());
    await pumpApp(tester, api, route: '/recipe/1');
    expect(find.text("You're offline"), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    api.error = null;
    tester.state<NavigatorState>(find.byType(Navigator).first).pushNamed('/recipe/1');
    await tester.pumpAndSettle();
    expect(find.text('Instructions'), findsOneWidget);
  });

  testWidgets('un-saving on the recipe page keeps the recipe and tab, with Undo', (tester) async {
    await pumpApp(tester, FakeApi(const OfflineException()), route: '/recipe/1', saved: [_meal]);
    await tester.tap(find.text('Instructions'));
    await tester.pumpAndSettle();
    expect(find.text('Bake.'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove ${_meal.name} from saved'));
    await tester.pumpAndSettle();
    expect(find.text('Bake.'), findsOneWidget); // still the same recipe and tab, even offline
    expect(find.text('Removed ${_meal.name} from saved'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove ${_meal.name} from saved'), findsOneWidget);
  });

  testWidgets('an empty category list shows a message instead of crashing', (tester) async {
    await pumpApp(tester, FakeApi()..categoryList = []);
    expect(tester.takeException(), isNull);
    expect(find.text('No recipes right now'), findsOneWidget);
  });

  testWidgets('View on the shopping list itself does not stack a second copy', (tester) async {
    await pumpApp(tester, FakeApi(), route: '/recipe/1', shoppingList: '[]');
    await tester.ensureVisible(find.text('Add all to list'));
    await tester.tap(find.text('Add all to list'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Shopping list, 1 items'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('View')); // snackbar still up on the list
    await tester.pumpAndSettle();
    expect(find.text('Shopping list', skipOffstage: false), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('What will you cook today?'), findsOneWidget);
  });

  testWidgets('opening a Featured recipe shows it without another request', (tester) async {
    final api = FakeApi();
    await pumpApp(tester, api);
    await tester.tap(find.text(_meal.name).first); // the Featured card
    await tester.pumpAndSettle();
    expect(find.text('Instructions'), findsOneWidget);
    expect(api.lookups, 0);
  });

  // Small phone, large phone, tablet; normal and 200% text. Any overflow
  // ("yellow stripes") fails the test, and Flutter's own accessibility
  // guidelines check tap targets, labels and text contrast.
  const sizes = {'small phone': Size(320, 568), 'large phone': Size(412, 915), 'tablet': Size(800, 1280)};
  for (final MapEntry(key: name, value: size) in sizes.entries) {
    for (final text in [1.0, 2.0]) {
      for (final route in ['/', '/recipe/1', '/shopping', '/shopping (All items)']) {
        testWidgets('$route on $name at ${(text * 100).round()}% text', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final handle = tester.ensureSemantics();
          await pumpApp(tester, FakeApi(), route: route.split(' ').first, text: text);
          if (route.endsWith('(All items)')) {
            await tester.tap(find.text('All items'));
            await tester.pumpAndSettle();
          }

          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        });
      }
    }
  }
}
