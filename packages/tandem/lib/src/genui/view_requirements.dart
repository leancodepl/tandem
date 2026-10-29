import 'dart:convert';

import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/agent_schema.dart';
import 'package:tandem/src/genui/agent_catalog.dart';
import 'package:tandem/src/genui/view_check.dart';
import 'package:tandem/src/genui/view_render.dart';
import 'package:tandem/src/genui/view_types.dart';
import 'package:tandem/src/report.dart';
import 'package:tandem/src/session/tool_answer.dart';

/// What a view the agent draws with [_catalog] needs of the screen: an
/// agent list that reads, that describes each type as the catalog does, and
/// data on which the view draws at most [ViewCheck.maxComponents]
/// components.
final class ViewRequirements(final AgentCatalog _catalog) {
  /// Why the catalog and [listing] do not fit, such as two forms of one
  /// type, or null when they do.
  String? conflictWith(AgentListing listing) =>
      ViewTypes.conflict(catalog: _catalog, listing: listing);

  /// What [surface] lists now, or null when a view cannot show on it: the
  /// list throws or does not fit the catalog, which is reported, or [view]
  /// draws too many components on it.
  AgentListing? read(AgentSurface surface, {DrawnComponents? view}) {
    final listing = _listingOf(surface);
    if (listing == null) return null;
    if (conflictWith(listing) case final conflict?) {
      report(StateError(conflict), .current);
      return null;
    }
    if (view != null && _tooLarge(view, listing)) return null;
    return listing;
  }

  /// The view the agent sent as [components], the tool's argument, checked
  /// against [listing].
  CheckedView check(Object? components, AgentListing listing) {
    if (conflictWith(listing) case final conflict?) {
      return ViewNotShown(.refused(conflict));
    }
    final checked = _checked(_decoded(components), listing);
    if (checked case ViewToShow(:final view) when _tooLarge(view, listing)) {
      return ViewNotShown(.refused(_tooMany));
    }
    return checked;
  }

  /// Reports what of the catalog's example does not fit [schema]: every
  /// value and method the screen may list, not only the ones of the current
  /// route. The agent gets the example, so a misfit teaches it paths and
  /// methods the screen does not have.
  void checkExample(AgentSchema schema) {
    final problems = _exampleProblems(schema);
    if (problems.isEmpty) return;
    report(
      StateError(
        'The example of ${_catalog.runtimeType} does not fit the screen:\n'
        '${problems.join('\n')}',
      ),
      .current,
    );
  }

  CheckedView _checked(Object? components, AgentListing listing) {
    try {
      final (:view, :problems) = ViewCheck(
        _catalog,
        _dataOf(listing),
      ).check(components);
      if (problems.isEmpty) return ViewToShow(view);
      return ViewNotShown(.refused(problems.join('\n')));
    } catch (err, st) {
      // A bug of a converter of the app fails the call, as for a method.
      report(err, st);
      return const ViewNotShown(ToolAnswer.failed);
    }
  }

  List<String> _exampleProblems(AgentSchema schema) {
    final data = (
      roots: {for (final view in schema.sees) view.name: view.type},
      methods: {
        for (final tool in schema.calls)
          tool.name: (tool: tool, needsApproval: false),
      },
    );
    try {
      return ViewCheck(_catalog, data).check(_catalog.example).problems;
    } catch (err, st) {
      report(err, st);
      return const [];
    }
  }

  bool _tooLarge(DrawnComponents view, AgentListing listing) =>
      ViewRender.count(view, listing) > ViewCheck.maxComponents;

  static AgentListing? _listingOf(AgentSurface surface) {
    try {
      return AgentListing.of(surface);
    } catch (err, st) {
      report(err, st);
      return null;
    }
  }

  /// The components as JSON, a model's string decoded; null for a string
  /// that is not JSON, which the check refuses.
  static Object? _decoded(Object? components) {
    if (components is! String) return components;
    try {
      return jsonDecode(components);
    } on FormatException {
      return null;
    }
  }

  static ViewData _dataOf(AgentListing listing) => (
    roots: {
      for (final MapEntry(:key, :value) in listing.roots.entries)
        key: value.type,
    },
    methods: {
      for (final name in listing.toolNames)
        if (listing.toolNamed(name) case final tool?)
          name: (tool: tool, needsApproval: listing.listedWithApproval(name)),
    },
  );

  static const _tooMany =
      'The view draws more than ${ViewCheck.maxComponents} components, '
      'counting one for every place a component is drawn, the items of a '
      'list too. Draw fewer.';
}

/// A view the agent sent, checked against the screen.
sealed class const CheckedView();

/// A view that fits the screen and shows.
final class const ViewToShow(final DrawnComponents view) extends CheckedView;

/// A view that does not show, with what the agent gets instead.
final class const ViewNotShown(final ToolAnswer answer) extends CheckedView;
