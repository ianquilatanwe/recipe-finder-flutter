import 'package:flutter/material.dart';

/// Credits for the design, data and font (CC BY 4.0 asks for attribution).
class AboutButton extends StatelessWidget {
  const AboutButton({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: IconButton(
      tooltip: 'About and credits',
      icon: const Icon(Icons.info_outline_rounded),
      onPressed: () => showAboutDialog(
        context: context,
        applicationName: 'Recipe Finder',
        applicationVersion: 'Flutter portfolio demo by Ian Quilatan',
        children: const [
          SizedBox(height: 8),
          Text(
            'Design: "Recipely – Food Recipe Mobile App UI Kit" by DhuhaCreative / Illiyin Studio, '
            'Figma Community, CC BY 4.0. Adapted: colours darkened for contrast, '
            'nutrition tiles replaced with recipe facts.',
          ),
          SizedBox(height: 8),
          Text('Recipes and images: TheMealDB (themealdb.com), free test API.'),
          SizedBox(height: 8),
          Text('Font: Sofia Sans, SIL Open Font License.'),
        ],
      ),
    ),
  );
}
