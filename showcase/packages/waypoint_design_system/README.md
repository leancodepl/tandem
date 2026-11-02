# Waypoint design system

Import `package:waypoint_design_system/waypoint_design_system.dart` from the app.
Public types use the `WP` prefix, such as `WPTextStyle`, `WPCard` and `WPButton`.

## Structure

- `src/foundations`: colours, typography, radii, layout widths and the Material
  theme. Waypoint has one dark theme; `wpTheme()` maps its styles to Material.
- `src/atoms`: basic visual elements and motion widgets. They depend on the
  foundations and other atoms.
- `src/components`: compositions grouped by purpose, including cards, forms,
  chat, feedback, navigation and page layouts.
- `lib/l10n`: the design system's own labels, generated from its arb file.

Keep business data, agent sessions and feature decisions in the app. Widgets
receive display values and callbacks. The design system owns how an assistant's
work looks, while callers decide what is marked, working or awaiting approval.

Within the package, import the defining file directly. Keep support widgets out
of the public barrel. Put spacing at the use site, following the repository's
code-quality rules.
