import 'package:example/desk/ui/desk_theme.dart';
import 'package:example/gallery/demo.dart';
import 'package:example/gallery/scenario_screen.dart';
import 'package:flutter/material.dart';

final class const GalleryScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const .all(24),
            children: [
              Text('TANDEM / EXAMPLES', style: context.textTheme.labelLarge),
              const SizedBox(height: 24),
              Text(
                'An agent on your screen.\nYou stay in control.',
                style: context.textTheme.headlineLarge?.copyWith(
                  fontWeight: .w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Run a scenario. Edit the app. Decide what happens next.',
                style: context.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              const Text('All six demos run locally with scripted responses.'),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final demo in Demo.values)
                      SizedBox(
                        width: constraints.maxWidth < 600
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 16) / 2,
                        child: _DemoCard(demo),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

final class const _DemoCard(final Demo demo) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
    margin: .zero,
    clipBehavior: .antiAlias,
    child: InkWell(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (context) => ScenarioScreen(demo)),
      ),
      child: Padding(
        padding: const .all(20),
        child: Column(
          crossAxisAlignment: .start,
          spacing: 16,
          children: [
            Row(
              children: [
                Icon(demo.icon, color: context.colorScheme.primary),
                const Spacer(),
                Text(demo.stateLibrary, style: context.textTheme.labelMedium),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward, size: 20),
              ],
            ),
            Text(demo.title, style: context.textTheme.titleLarge),
            Text(demo.summary),
          ],
        ),
      ),
    ),
  );
}
