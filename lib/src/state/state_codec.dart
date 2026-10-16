/// Converts between the app's state and the JSON document the agent sees.
///
/// The agent's state is one JSON object. The app owns some of its top-level
/// keys ([keys]); the agent backend owns the rest (ag-ui-adk adds
/// `_ag_ui_*` keys and `pending_tool_calls`). Tandem sends only the owned
/// keys and never sends the others back.
///
/// [encode] must be deterministic: Tandem compares encoded values to tell
/// the user's edits from its own writes.
abstract base class StateCodec<S> {
  /// For subclasses.
  const StateCodec();

  /// The whole state is one model, stored under [key].
  ///
  /// Paths in `AgentMarks` are relative to [key], such as
  /// `'lines/0/quantity'`.
  ///
  /// ```dart
  /// StateCodec.json('order', OrderDraft.fromJson,
  ///     toJson: (draft) => draft.toJson())
  /// ```
  factory StateCodec.json(
    String key,
    S Function(Map<String, Object?> json) fromJson, {
    required Map<String, Object?> Function(S value) toJson,
  }) => _KeyedCodec(
    key,
    encodeModel: toJson,
    decodeModel: (_, json) => fromJson(json),
  );

  /// Full control over several owned top-level keys.
  ///
  /// [encode] must return exactly [keys]. [decode] gets the current value and
  /// the whole agent document, so it can keep fields the agent does not see.
  /// Paths in `AgentMarks` start with the top-level key.
  factory StateCodec.custom({
    required Set<String> keys,
    required Map<String, Object?> Function(S state) encode,
    required S Function(S current, Map<String, Object?> document) decode,
  }) = _CustomCodec<S>;

  /// Only part of the state is shared, such as the draft inside a cubit
  /// state that also holds UI flags.
  ///
  /// [get] picks the shared model out of the state; [set] puts a model the
  /// agent built back and keeps the rest of the state. Paths in
  /// `AgentMarks` are relative to [key].
  ///
  /// ```dart
  /// StateCodec.lens('order',
  ///     get: (state) => state.draft,
  ///     set: (state, draft) => state.copyWith(draft: draft),
  ///     fromJson: OrderDraft.fromJson,
  ///     toJson: (draft) => draft.toJson())
  /// ```
  static StateCodec<S> lens<S, M>(
    String key, {
    required M Function(S state) get,
    required S Function(S state, M model) set,
    required M Function(Map<String, Object?> json) fromJson,
    required Map<String, Object?> Function(M model) toJson,
  }) => _KeyedCodec(
    key,
    encodeModel: (state) => toJson(get(state)),
    decodeModel: (current, json) => set(current, fromJson(json)),
  );

  /// The top-level keys of the agent document the app owns.
  Set<String> get keys;

  /// The owned part of the document for [state]: exactly [keys].
  ///
  /// The values must be JSON-encodable: plain JSON, or objects with a
  /// `toJson()` method, as `jsonEncode` accepts. The session turns them into
  /// plain JSON before it compares or sends them.
  Map<String, Object?> encode(S state);

  /// The value for the agent [document], starting from [current].
  ///
  /// May throw; the session then keeps the current value and reports a
  /// diagnostic.
  S decode(S current, Map<String, Object?> document);
}

/// The key that `AgentMarks` paths are relative to: the key of a
/// [StateCodec.json] or [StateCodec.lens] codec, `null` for every other
/// codec, whose paths start with the top-level key.
///
/// Internal: not exported.
String? marksKeyOf(StateCodec<Object?> codec) => switch (codec) {
  _KeyedCodec(:final key) => key,
  _ => null,
};

/// The codec of [StateCodec.json] and [StateCodec.lens]: one model under
/// [key].
final class _KeyedCodec<S> extends StateCodec<S> {
  const _KeyedCodec(
    this.key, {
    required Map<String, Object?> Function(S state) encodeModel,
    required S Function(S current, Map<String, Object?> json) decodeModel,
  }) : _encodeModel = encodeModel,
       _decodeModel = decodeModel;

  final String key;
  // Only called in [encode], with a value of this codec's own S, so the
  // unsafe call this lint warns about cannot happen. Storing the function is
  // what the factory constructors need; the alternative is a runtime cast.
  // ignore: unsafe_variance
  final Map<String, Object?> Function(S state) _encodeModel;
  // Only called in [decode]; see [_encodeModel].
  // ignore: unsafe_variance
  final S Function(S current, Map<String, Object?> json) _decodeModel;

  @override
  Set<String> get keys => {key};

  @override
  Map<String, Object?> encode(S state) => {key: _encodeModel(state)};

  @override
  S decode(S current, Map<String, Object?> document) =>
      _decodeModel(current, _modelJson(key, document));
}

final class _CustomCodec<S> extends StateCodec<S> {
  const _CustomCodec({
    required this.keys,
    required Map<String, Object?> Function(S state) encode,
    required S Function(S current, Map<String, Object?> document) decode,
  }) : _encode = encode,
       _decode = decode;

  @override
  final Set<String> keys;
  // Only called in [encode]; see _KeyedCodec._encodeModel.
  // ignore: unsafe_variance
  final Map<String, Object?> Function(S state) _encode;
  // Only called in [decode]; see _KeyedCodec._encodeModel.
  // ignore: unsafe_variance
  final S Function(S current, Map<String, Object?> document) _decode;

  @override
  Map<String, Object?> encode(S state) => _encode(state);

  @override
  S decode(S current, Map<String, Object?> document) =>
      _decode(current, document);
}

/// The model under [key] in [document], or a [FormatException] that says
/// what is there instead.
Map<String, Object?> _modelJson(String key, Map<String, Object?> document) =>
    switch (document[key]) {
      final Map<String, Object?> json => json,
      null when !document.containsKey(key) => throw FormatException(
        'The agent state has no "$key".',
      ),
      final other => throw FormatException(
        'The agent state "$key" is not a JSON object: $other.',
      ),
    };
