import 'package:example/desk/ui/desk_theme.dart';
import 'package:example/gallery/backend_dialog.dart';
import 'package:example/gallery/demo.dart';
import 'package:flutter/material.dart';
import 'package:tandem/tandem.dart';

final class const ScenarioScreen(final Demo demo, {super.key})
    extends StatefulWidget {
  @override
  State<ScenarioScreen> createState() => _ScenarioScreenState();
}

final class _ScenarioScreenState() extends State<ScenarioScreen> {
  Uri? _backend;
  late AgentConnection _connection = widget.demo.scriptedAgent();
  var _starts = 0;

  void _start(Uri? backend) => setState(() {
    _backend = backend;
    _connection = switch (backend) {
      final uri? => HttpAgentConnection(uri),
      null => widget.demo.scriptedAgent(),
    };
    _starts++;
  });

  Future<void> _switchAgent() async {
    switch (_backend) {
      case _?:
        _start(null);
      case null:
        final uri = await showDialog<Uri>(
          context: context,
          builder: (context) => const BackendDialog(),
        );
        if (uri case final backend? when mounted) {
          _start(backend);
        }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      scrolledUnderElevation: 0,
      title: Text(widget.demo.title),
      actions: [
        IconButton(
          tooltip: 'Reset example',
          onPressed: () => _start(_backend),
          icon: const Icon(Icons.restart_alt),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: Column(
      crossAxisAlignment: .stretch,
      children: [
        Visibility(
          visible: MediaQuery.viewInsetsOf(context).bottom == 0,
          child: Padding(
            padding: const .fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: .start,
              spacing: 8,
              children: [
                _AgentSource(
                  _backend,
                  onSwitch: widget.demo.canUseBackend ? _switchAgent : null,
                ),
                Text(widget.demo.instruction),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(_starts),
            child: widget.demo.screen(_connection),
          ),
        ),
      ],
    ),
  );
}

final class const _AgentSource(
  final Uri? backend, {
  required final VoidCallback? onSwitch,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    spacing: 8,
    children: [
      Icon(
        switch (backend) {
          _? => Icons.cloud_outlined,
          null => Icons.offline_bolt,
        },
        size: 16,
        color: context.colorScheme.primary,
      ),
      Expanded(
        child: Text(switch (backend) {
          final uri? => 'Backend · $uri',
          null => 'Scripted · fixed responses',
        }, style: context.textTheme.labelMedium),
      ),
      if (onSwitch case final onPressed?)
        TextButton(
          onPressed: onPressed,
          child: Text(switch (backend) {
            _? => 'Use script',
            null => 'Use backend',
          }),
        ),
    ],
  );
}
