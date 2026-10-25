part of 'invoice_screen.dart';

final class const _Header({required final VoidCallback onReset})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const .fromLTRB(24, 24, 14, 24),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Invoices',
            style: TextStyle(
              fontSize: 32,
              fontWeight: .w700,
              letterSpacing: -.8,
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Demo options',
          icon: const Icon(Icons.more_horiz_rounded, color: invoiceMuted),
          color: invoicePaper,
          surfaceTintColor: Colors.transparent,
          onSelected: (value) {
            if (value == 'reset') {
              onReset();
            } else {
              showDialog<void>(
                context: context,
                builder: (context) => const _AboutDemo(),
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'reset', child: Text('Reset demo')),
            const PopupMenuItem(value: 'about', child: Text('About this demo')),
          ],
        ),
      ],
    ),
  );
}

final class const _SearchInput({
  required final TextEditingController controller,
  required final bool smart,
  required final bool busy,
  required final VoidCallback onToggle,
  required final VoidCallback onSubmit,
  required final VoidCallback onClear,
  required final ValueChanged<String> onChanged,
}) extends StatelessWidget {
  bool get _searching => !smart;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .symmetric(horizontal: 24),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      constraints: const BoxConstraints(minHeight: 60),
      padding: const .fromLTRB(14, 5, 6, 5),
      decoration: BoxDecoration(
        color: smart ? invoicePaper : const Color(0xFFF2F2F7),
        borderRadius: .circular(16),
        border: Border.all(
          color: smart ? invoiceBlue : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          if (_searching) ...[
            const Icon(Icons.search_rounded, size: 21, color: invoiceMuted),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              key: const ValueKey('invoice-search'),
              controller: controller,
              style: const TextStyle(fontSize: 16, height: 1.35),
              minLines: 1,
              maxLines: 2,
              textInputAction: .search,
              onSubmitted: (_) => onSubmit(),
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: smart ? 'Ask about your invoices' : 'Search invoices',
                hintStyle: const TextStyle(color: invoiceMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const .symmetric(vertical: 8),
              ),
            ),
          ),
          if (_searching && controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              onPressed: onClear,
              iconSize: 16,
              padding: .zero,
              constraints: const BoxConstraints.tightFor(width: 30, height: 44),
              icon: const Icon(Icons.cancel, color: invoiceMuted),
            ),
          const SizedBox(width: 4),
          IconButton(
            key: const ValueKey('smart-toggle'),
            tooltip: smart ? 'Turn off smart input' : 'Turn on smart input',
            onPressed: busy ? null : onToggle,
            style: IconButton.styleFrom(
              foregroundColor: smart ? invoiceBlue : invoiceMuted,
              backgroundColor: smart
                  ? const Color(0xFFEAF3FF)
                  : Colors.transparent,
              minimumSize: const Size(44, 44),
              shape: RoundedRectangleBorder(borderRadius: .circular(11)),
            ),
            icon: const Icon(Icons.psychology_outlined, size: 25),
          ),
          if (smart && controller.text.isNotEmpty)
            IconButton(
              key: const ValueKey('smart-submit'),
              tooltip: 'Run smart input',
              onPressed: busy ? null : onSubmit,
              color: invoiceBlue,
              constraints: const BoxConstraints.tightFor(width: 36, height: 44),
              padding: .zero,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 1.8),
                    )
                  : const Icon(Icons.arrow_upward_rounded, size: 22),
            ),
        ],
      ),
    ),
  );
}

final class const _ListHeading({
  required final int count,
  required final String? period,
  required final bool busy,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const .fromLTRB(24, 18, 24, 8),
    child: SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: .centerLeft,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  busy ? 'Finding invoices…' : '$count invoices',
                  key: ValueKey((count, busy)),
                  style: const TextStyle(fontSize: 13, color: invoiceMuted),
                ),
              ),
            ),
          ),
          if (period case final period?)
            Text(
              'Issued in $period',
              style: const TextStyle(fontSize: 13, color: invoiceMuted),
            ),
        ],
      ),
    ),
  );
}

final class const _InvoiceRow({
  super.key,
  required final Invoice invoice,
  required final bool selected,
  required final bool additional,
  required final int index,
  required final VoidCallback? onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    // Only rows the date match adds grow in; the rest stay put on rebuilds.
    tween: Tween(begin: additional ? 0 : 1, end: 1),
    duration: Duration(milliseconds: 260 + index * 70),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => ClipRect(
      child: Align(
        alignment: .topCenter,
        heightFactor: value,
        child: Opacity(opacity: value, child: child),
      ),
    ),
    child: Semantics(
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            constraints: const BoxConstraints(minHeight: 70),
            padding: const .symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: additional ? const Color(0xFFEAF3FF) : null,
              borderRadius: additional ? .circular(12) : null,
              border: additional
                  ? null
                  : const Border(
                      bottom: BorderSide(color: invoiceLine, width: .5),
                    ),
            ),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    key: ValueKey(selected),
                    size: 22,
                    color: selected ? invoiceBlue : const Color(0xFFC7C7CC),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        invoice.title,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: .w500),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Issued ${invoice.issuedLabel}',
                        key: additional
                            ? ValueKey('date-match-${invoice.id}')
                            : null,
                        style: TextStyle(
                          fontSize: 12,
                          color: additional ? invoiceBlue : invoiceMuted,
                          fontWeight: additional ? .w600 : .w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  invoiceMoney(invoice.amount),
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

extension on MonthPlan {
  String get verb => archives ? 'Archive' : 'Show';

  String get question => '$verb ${invoices.length} invoices issued in $period?';

  String get unnamed {
    final count = invoices.where(foundByDateOnly).length;
    return "$count don't mention ${invoiceMonths[month - 1]} in the title.";
  }
}

final class const _AgentGlyph({final double size = 34})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: Color(0xFFEAF3FF),
      shape: BoxShape.circle,
    ),
    child: Icon(
      Icons.psychology_outlined,
      size: size * .62,
      color: invoiceBlue,
    ),
  );
}

final class const _AgentReply({
  required final MonthPlan plan,
  required final VoidCallback onApprove,
  required final VoidCallback onCancel,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const .fromLTRB(24, 10, 24, 0),
    child: Container(
      padding: const .fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7FF),
        borderRadius: .circular(16),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            crossAxisAlignment: .start,
            children: [
              const _AgentGlyph(size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      plan.question,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: .w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      plan.unnamed,
                      style: const TextStyle(fontSize: 13, color: invoiceMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: .end,
            spacing: 6,
            children: [
              TextButton(onPressed: onCancel, child: const Text('Not now')),
              FilledButton(
                key: const ValueKey('agent-approve'),
                onPressed: onApprove,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const .symmetric(horizontal: 18),
                ),
                child: Text(plan.verb),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

final class const _ActionBar({required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const .fromLTRB(24, 16, 24, 20),
    decoration: const BoxDecoration(
      color: invoicePaper,
      border: Border(top: BorderSide(color: invoiceLine, width: .5)),
    ),
    child: child,
  );
}

final class const _ArchivedBanner({
  required final int count,
  required final VoidCallback onUndo,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _ActionBar(
    child: Row(
      children: [
        const Icon(Icons.check_circle_outline, size: 21, color: invoiceBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$count invoices archived',
            style: const TextStyle(fontSize: 15),
          ),
        ),
        TextButton(onPressed: onUndo, child: const Text('Undo')),
      ],
    ),
  );
}

final class const _ManualSelection({
  required final int count,
  required final VoidCallback onArchive,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _ActionBar(
    child: SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onArchive,
        child: Text('Archive $count ${count == 1 ? 'invoice' : 'invoices'}'),
      ),
    ),
  );
}

final class const _EmptyInvoices({required final bool success})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      success ? 'No invoices left in this view' : 'No invoices found',
      style: const TextStyle(fontSize: 15, color: invoiceMuted),
    ),
  );
}

final class const _InputNotice(final String message) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const .fromLTRB(24, 12, 24, 0),
    child: Align(
      alignment: .centerLeft,
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: invoiceMuted),
      ),
    ),
  );
}

final class const _AboutDemo() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Folio, built with Tandem'),
    content: const Text(
      'Apple Foundation Models interprets the input on your device. '
      'Tandem connects it to this screen and waits for your approval. '
      'No backend or API key.\n\n'
      'Experimental AI. Results may vary. Review before confirming.\n\n'
      'Fictional invoices. Changes live in memory.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Done'),
      ),
    ],
  );
}
