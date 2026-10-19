import 'package:flutter/material.dart';

final class const ItemInput({
  super.key,
  required final String label,
  required final ValueChanged<String> onAdd,
}) extends StatefulWidget {
  @override
  State<ItemInput> createState() => _ItemInputState();
}

final class _ItemInputState() extends State<ItemInput> {
  final _controller = TextEditingController();

  void _add() {
    if (_controller.text.trim() case final item when item.isNotEmpty) {
      widget.onAdd(item);
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .all(12),
    child: Row(
      spacing: 8,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(labelText: widget.label),
            onEditingComplete: _add,
          ),
        ),
        IconButton.filled(
          tooltip: 'Add',
          onPressed: _add,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
  );
}
