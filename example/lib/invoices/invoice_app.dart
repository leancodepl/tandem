import 'package:example/invoices/invoice_screen.dart';
import 'package:example/invoices/invoice_store.dart';
import 'package:example/invoices/invoice_style.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tandem/tandem.dart';

final class const InvoiceApp({
  super.key,
  required final AgentConnection connection,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Folio · Tandem',
    debugShowCheckedModeBanner: false,
    theme: invoiceTheme,
    home: _InvoiceDemo(connection: connection),
  );
}

final class const _InvoiceDemo({required final AgentConnection connection})
    extends StatefulWidget {
  @override
  State<_InvoiceDemo> createState() => _InvoiceDemoState();
}

final class _InvoiceDemoState() extends State<_InvoiceDemo> {
  final _store = InvoiceStore();
  final _input = TextEditingController();
  var _smart = false;
  var _generation = 0;
  String? _command;

  void _submit() {
    final command = _input.text.trim();
    if (_smart && command.isNotEmpty) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _command = command;
        _generation++;
      });
    }
  }

  void _toggleSmart() => setState(() {
    _smart = !_smart;
    _input.clear();
    _command = null;
    _generation++;
    // Smart input starts from what the search found.
    if (_smart) {
      return;
    }
    _store.search('');
  });

  void _clear() => setState(() {
    _input.clear();
    _command = null;
    _generation++;
    _store.search('');
  });

  @override
  void dispose() {
    _input.dispose();
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: _store,
    child: TandemScope.connected(
      // Each submitted command is a fresh interpretation, rather than a chat.
      key: ValueKey(_generation),
      surface: (context) => context.read<InvoiceStore>(),
      connection: widget.connection,
      approvals: const .fromState(),
      onEvent: (context, event, session) {
        if (event case AgentCall(tool: 'interpret_invoice_input')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _command = null;
                _generation++;
              });
            }
          });
        }
      },
      child: InvoiceScreen(
        input: _input,
        smart: _smart,
        command: _command,
        onToggleSmart: _toggleSmart,
        onSubmit: _submit,
        onClear: _clear,
      ),
    ),
  );
}
