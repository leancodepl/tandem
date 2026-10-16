import 'dart:async';

import 'package:tandem/protocol.dart';
import 'package:tandem/tandem.dart';

/// A customer of the B2B order screen.
final class Customer {
  const Customer({required this.id, required this.name});

  factory Customer.fromJson(Map<String, Object?> json) =>
      Customer(id: json['id']! as String, name: json['name']! as String);

  final String id;
  final String name;

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      other is Customer && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// One line of an order.
final class OrderLine {
  const OrderLine({required this.sku, required this.quantity, this.unitPrice});

  factory OrderLine.fromJson(Map<String, Object?> json) => OrderLine(
    sku: json['sku']! as String,
    quantity: (json['quantity']! as num).toInt(),
    unitPrice: (json['unitPrice'] as num?)?.toDouble(),
  );

  final String sku;
  final int quantity;
  final double? unitPrice;

  OrderLine copyWith({int? quantity}) => OrderLine(
    sku: sku,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice,
  );

  Map<String, Object?> toJson() => {
    'sku': sku,
    'quantity': quantity,
    'unitPrice': unitPrice,
  };

  @override
  bool operator ==(Object other) =>
      other is OrderLine &&
      other.sku == sku &&
      other.quantity == quantity &&
      other.unitPrice == unitPrice;

  @override
  int get hashCode => Object.hash(sku, quantity, unitPrice);
}

/// The order draft the agent and the user fill in together.
final class OrderDraft {
  const OrderDraft({this.customer, this.lines = const [], this.notes = ''});

  factory OrderDraft.fromJson(Map<String, Object?> json) => OrderDraft(
    customer: switch (json['customer']) {
      final Map<String, Object?> customer => Customer.fromJson(customer),
      _ => null,
    },
    lines: [
      for (final line in json['lines'] as List<Object?>? ?? const [])
        OrderLine.fromJson(line! as Map<String, Object?>),
    ],
    notes: json['notes'] as String? ?? '',
  );

  static const empty = OrderDraft();

  final Customer? customer;
  final List<OrderLine> lines;
  final String notes;

  OrderDraft copyWith({String? notes, List<OrderLine>? lines}) => OrderDraft(
    customer: customer,
    lines: lines ?? this.lines,
    notes: notes ?? this.notes,
  );

  /// The draft with the quantity of line [index] set to [quantity].
  OrderDraft withQuantity(int index, int quantity) => copyWith(
    lines: [
      for (final (i, line) in lines.indexed)
        if (i == index) line.copyWith(quantity: quantity) else line,
    ],
  );

  Map<String, Object?> toJson() => {
    'customer': customer?.toJson(),
    'lines': [for (final line in lines) line.toJson()],
    'notes': notes,
  };

  @override
  bool operator ==(Object other) =>
      other is OrderDraft &&
      other.customer == customer &&
      other.notes == notes &&
      _listEquals(other.lines, lines);

  @override
  int get hashCode => Object.hash(customer, notes, Object.hashAll(lines));
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// The codec most tests use: the draft under `order`.
final orderCodec = StateCodec<OrderDraft>.json(
  'order',
  OrderDraft.fromJson,
  toJson: (draft) => draft.toJson(),
);

/// A screen state that shares only its draft, for the lens codec.
final class ScreenState {
  const ScreenState(this.draft, {this.isSaving = false});

  final OrderDraft draft;
  final bool isSaving;

  @override
  bool operator ==(Object other) =>
      other is ScreenState &&
      other.draft == draft &&
      other.isSaving == isSaving;

  @override
  int get hashCode => Object.hash(draft, isSaving);
}

/// A state host that behaves like a bloc `Cubit`: [state] changes at once,
/// [stream] delivers in a later microtask, and nothing is emitted for an
/// equal value.
///
/// It records every [writeFromAgent] and fails a test that writes after
/// [lock].
final class AsyncHost<S> implements StateHost<S> {
  AsyncHost(this._state);

  S _state;
  final _controller = StreamController<S>.broadcast();
  var _isLocked = false;

  /// Every value Tandem wrote, oldest first.
  final writes = <S>[];

  @override
  S get state => _state;

  @override
  Stream<S> get stream => _controller.stream;

  @override
  void writeFromAgent(S value) {
    if (_isLocked) {
      throw StateError('Tandem wrote into the host after it was locked.');
    }
    writes.add(value);
    _emit(value);
  }

  /// A user edit.
  void update(S Function(S current) edit) => _emit(edit(_state));

  /// From now on, a write fails the test.
  void lock() => _isLocked = true;

  Future<void> close() => _controller.close();

  void _emit(S value) {
    if (value == _state) {
      return;
    }
    _state = value;
    _controller.add(value);
  }
}

/// A [MemoryStateHost] that records what Tandem wrote.
final class RecordingHost<S> implements StateHost<S> {
  RecordingHost(S initial) : memory = MemoryStateHost(initial);

  final MemoryStateHost<S> memory;

  /// Every value Tandem wrote, oldest first.
  final writes = <S>[];

  @override
  S get state => memory.state;

  @override
  Stream<S> get stream => memory.stream;

  @override
  void writeFromAgent(S value) {
    writes.add(value);
    memory.writeFromAgent(value);
  }

  /// A user edit.
  void update(S Function(S current) edit) => memory.update(edit);
}

/// Options for tests that check no diagnostics: they are dropped instead
/// of logged.
final quiet = TandemOptions(onDiagnostic: (_) {});

/// A tool that returns `result` (or throws `error`) and keeps its calls.
final class RecordingTool {
  RecordingTool(
    String name, {
    Object? result,
    Exception? error,
    bool needsApproval = false,
    Map<String, Param> params = const {},
    String? label,
  }) {
    tool = Tool(
      name,
      'The $name tool.',
      params: params,
      needsApproval: needsApproval,
      label: label,
      run: (call) {
        calls.add(call);
        if (error != null) {
          throw error;
        }
        return result;
      },
    );
  }

  /// The tool, as the session gets it.
  late final Tool<OrderDraft> tool;

  /// The calls so far, oldest first.
  final calls = <ToolCall<OrderDraft>>[];
}

/// An [AgentConnection] whose runs a test writes as plain event streams,
/// for runs a `ScriptedAgent` cannot play: a stream that ends without
/// `RUN_FINISHED`, a transport error, `RUN_ERROR` without `RUN_STARTED`.
final class ManualConnection implements AgentConnection {
  ManualConnection(this._runs);

  final List<Stream<WireEvent> Function(RunInput input)> _runs;

  /// Every input so far, oldest first.
  final inputs = <RunInput>[];

  @override
  Stream<WireEvent> run(RunInput input) {
    inputs.add(input);
    return _runs[inputs.length - 1](input);
  }
}

/// [events] as wire events, sent one per microtask.
Stream<WireEvent> events(List<Map<String, Object?>> events) async* {
  for (final event in events) {
    await Future<void>.value();
    yield WireEvent.fromJson(event);
  }
}
