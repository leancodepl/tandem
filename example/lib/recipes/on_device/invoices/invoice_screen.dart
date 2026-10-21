import 'package:example/recipes/on_device/invoices/invoice_store.dart';
import 'package:example/recipes/on_device/invoices/invoice_style.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tandem/tandem.dart';

part 'invoice_widgets.dart';

final class const InvoiceScreen({
  super.key,
  required final TextEditingController input,
  required final bool smart,
  required final String? command,
  required final VoidCallback onToggleSmart,
  required final VoidCallback onSubmit,
  required final VoidCallback onClear,
}) extends StatefulWidget {
  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

final class _InvoiceScreenState() extends State<InvoiceScreen> {
  var _unsent = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.command case final command? when _unsent) {
      _unsent = false;
      final session = TandemSessionScope.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          session.send(invoicePrompt(command));
        }
      });
    }
  }

  void _decide(TandemSession session, ApprovalRequest request, bool approve) {
    try {
      if (approve) {
        session.approve(request);
      } else {
        session.reject(request);
        widget.onClear();
      }
    } on ApprovalNotPending {
      widget.onClear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The invoices changed. Please try again.'),
        ),
      );
    }
  }

  Future<void> _archiveManually() async {
    final store = context.read<InvoiceStore>();
    final ids = store.selected.toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive ${ids.length} invoices?'),
        content: const Text('You can restore them with Undo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      store.archive(ids);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<InvoiceStore>();
    final session = TandemSessionScope.of(context);
    final pending = switch (session.status) {
      _ when widget.command != widget.input.text.trim() => null,
      AwaitingApproval(:final request) => request,
      _ => null,
    };
    final plan = pending == null ? null : store.planFor(pending.arguments);
    final match = plan is MonthPlan ? plan : null;
    final invoices = match?.invoices ?? store.visible;
    final busy = session.status is Thinking || session.status is Calling;
    final success = store.lastArchived.isNotEmpty;
    final failed = session.items.any((item) => item is ChatNotice);
    final question = switch ((pending, match)) {
      (final request?, final plan?) => (request: request, plan: plan),
      _ => null,
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ColoredBox(
            color: invoicePaper,
            child: SafeArea(
              child: Column(
                children: [
                  _Header(
                    onReset: () {
                      store.reset();
                      widget.onClear();
                    },
                  ),
                  _SearchInput(
                    controller: widget.input,
                    smart: widget.smart,
                    busy: busy,
                    onToggle: widget.onToggleSmart,
                    onSubmit: widget.onSubmit,
                    onClear: widget.onClear,
                    onChanged: (text) {
                      if (widget.smart) {
                        setState(() {});
                      } else {
                        store.search(text);
                      }
                    },
                  ),
                  if (question != null)
                    _AgentReply(
                      plan: question.plan,
                      onApprove: () => _decide(session, question.request, true),
                      onCancel: () => _decide(session, question.request, false),
                    ),
                  if (failed)
                    const _InputNotice('Could not finish. Please try again.')
                  else if (plan case RefusedPlan(:final hint))
                    _InputNotice(hint),
                  _ListHeading(
                    count: invoices.length,
                    period: match?.period,
                    busy: busy,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: invoices.isEmpty
                          ? _EmptyInvoices(success: success)
                          : ListView.builder(
                              key: const ValueKey('invoices'),
                              padding: const .symmetric(horizontal: 24),
                              itemCount: invoices.length,
                              itemBuilder: (context, index) {
                                final invoice = invoices[index];
                                return _InvoiceRow(
                                  key: ValueKey(invoice.id),
                                  invoice: invoice,
                                  selected:
                                      match != null ||
                                      store.selected.contains(invoice.id),
                                  additional:
                                      match?.foundByDateOnly(invoice) ?? false,
                                  index: match == null ? 0 : index,
                                  onTap: match != null || busy
                                      ? null
                                      : () => store.toggle(invoice.id),
                                );
                              },
                            ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    child: switch (question) {
                      _? => const SizedBox(height: 20, width: double.infinity),
                      _ when success => _ArchivedBanner(
                        count: store.lastArchived.length,
                        onUndo: store.undoArchive,
                      ),
                      _ when widget.smart => const SizedBox(
                        height: 20,
                        width: double.infinity,
                      ),
                      _ when store.selected.isNotEmpty => _ManualSelection(
                        count: store.selected.length,
                        onArchive: _archiveManually,
                      ),
                      _ => const SizedBox(height: 20, width: double.infinity),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
