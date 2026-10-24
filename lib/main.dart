import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'screens/home_screen.dart';
import 'screens/recipe_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/shopping_screen.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      // Riverpod 3 retries failed requests for ~10 s by default; the screens
      // show error/offline states with a "Try again" button instead.
      retry: (_, _) => null,
      child: const RecipeApp(),
    ),
  );
}

class RecipeApp extends StatelessWidget {
  const RecipeApp({super.key});

  /// `/`, `/recipe/<id>` and `/shopping`. Named routes keep the web URL in
  /// sync, so a recipe link can be shared or refreshed.
  static Route<void> _route(RouteSettings settings) {
    final segments = Uri.parse(settings.name ?? '/').pathSegments;
    final Widget page = switch (segments) {
      ['recipe', final id] => RecipeScreen(id: id, meal: settings.arguments as Meal?),
      ['shopping'] => const ShoppingScreen(),
      _ => const Shell(),
    };
    return MaterialPageRoute(settings: settings, builder: (_) => page);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Recipe Finder',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    onGenerateRoute: _route,
    // Default would also push '/recipe' for '/recipe/123'; keep home + target,
    // so every page always has Home to go back to.
    onGenerateInitialRoutes: (name) => [
      _route(const RouteSettings(name: '/')),
      if (name != '/') _route(RouteSettings(name: name)),
    ],
  );
}

/// Home and Saved tabs: bottom bar on phones, side rail from 840 px.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  /// Tabs are built the first time they're opened (then kept), so launch
  /// doesn't build the Saved grid and download its photos.
  final _opened = {0};

  void _open(int tab) => setState(() => _opened.add(_tab = tab));

  static const _destinations = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.favorite_border_rounded, Icons.favorite_rounded, 'Saved'),
  ];

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      bottom: false,
      child: IndexedStack(
        index: _tab,
        children: [
          const HomeScreen(),
          if (_opened.contains(1)) SavedScreen(onBrowse: () => _open(0)) else const SizedBox.shrink(),
        ],
      ),
    );

    if (MediaQuery.sizeOf(context).width >= 840) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _tab,
              onDestinationSelected: _open,
              labelType: NavigationRailLabelType.all,
              groupAlignment: -0.9,
              destinations: [
                for (final (icon, selected, label) in _destinations)
                  NavigationRailDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: Text(label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _open,
        destinations: [
          for (final (icon, selected, label) in _destinations)
            NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: label),
        ],
      ),
    );
  }
}
