import 'package:example/desk/order_desk_agent.dart';
import 'package:example/desk/ui/backend_dialog.dart';
import 'package:example/desk/ui/desk_theme.dart';
import 'package:example/desk/ui/order_desk_screen.dart';
import 'package:flutter/material.dart';
import 'package:tandem/tandem.dart';

final class const OrderDeskApp({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Tandem order desk',
    debugShowCheckedModeBanner: false,
    theme: deskTheme,
    home: const _OrderDesk(),
  );
}

final class const _OrderDesk() extends StatefulWidget {
  @override
  State<_OrderDesk> createState() => _OrderDeskState();
}

final class _OrderDeskState() extends State<_OrderDesk> {
  Uri? _backend;
  AgentConnection _connection = orderDeskAgent();
  var _starts = 0;

  void _start(Uri? backend) => setState(() {
    _backend = backend;
    _connection = switch (backend) {
      final uri? => HttpAgentConnection(uri),
      null => orderDeskAgent(),
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
      title: const Text('Order desk'),
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
                _AgentSource(_backend, onSwitch: _switchAgent),
                const Text(
                  'Fill the draft, edit a quantity, then ask to place the '
                  'order.',
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(_starts),
            child: OrderDeskScreen(connection: _connection),
          ),
        ),
      ],
    ),
  );
}

final class const _AgentSource(
  final Uri? backend, {
  required final VoidCallback onSwitch,
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
      TextButton(
        onPressed: onSwitch,
        child: Text(switch (backend) {
          _? => 'Use script',
          null => 'Use backend',
        }),
      ),
    ],
  );
}
