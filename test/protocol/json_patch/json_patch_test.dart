// Tested at the level of this internal module on purpose. The session
// applies STATE_DELTA with it and ignores a patch that fails, so through the
// public interface a failing case shows only as a diagnostic, and a result
// only as far as a codec keeps it. The RFC cases need the exact result
// document and error. The session's side is tested in test/session.

import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/protocol.dart';
import 'package:tandem/src/protocol/json_patch/json_patch.dart';
import 'package:tandem/src/protocol/json_patch/json_value.dart';

import '../fixtures/ag_ui_adk.dart';

/// One conformance case: the operations applied to the document give the
/// expected document, or fail when it is `null`.
typedef _Case = ({
  String name,
  Map<String, Object?> document,
  List<Map<String, Object?>> operations,
  Map<String, Object?>? expected,
});

/// RFC 6902, Appendix A. A.13 (an operation with two "op" members) cannot be
/// written as decoded JSON, where the last member wins, so it is left out.
const _rfc6902AppendixA = <_Case>[
  (
    name: 'A.1 adding an object member',
    document: {'foo': 'bar'},
    operations: [
      {'op': 'add', 'path': '/baz', 'value': 'qux'},
    ],
    expected: {'baz': 'qux', 'foo': 'bar'},
  ),
  (
    name: 'A.2 adding an array element',
    document: {
      'foo': ['bar', 'baz'],
    },
    operations: [
      {'op': 'add', 'path': '/foo/1', 'value': 'qux'},
    ],
    expected: {
      'foo': ['bar', 'qux', 'baz'],
    },
  ),
  (
    name: 'A.3 removing an object member',
    document: {'baz': 'qux', 'foo': 'bar'},
    operations: [
      {'op': 'remove', 'path': '/baz'},
    ],
    expected: {'foo': 'bar'},
  ),
  (
    name: 'A.4 removing an array element',
    document: {
      'foo': ['bar', 'qux', 'baz'],
    },
    operations: [
      {'op': 'remove', 'path': '/foo/1'},
    ],
    expected: {
      'foo': ['bar', 'baz'],
    },
  ),
  (
    name: 'A.5 replacing a value',
    document: {'baz': 'qux', 'foo': 'bar'},
    operations: [
      {'op': 'replace', 'path': '/baz', 'value': 'boo'},
    ],
    expected: {'baz': 'boo', 'foo': 'bar'},
  ),
  (
    name: 'A.6 moving a value',
    document: {
      'foo': {'bar': 'baz', 'waldo': 'fred'},
      'qux': {'corge': 'grault'},
    },
    operations: [
      {'op': 'move', 'from': '/foo/waldo', 'path': '/qux/thud'},
    ],
    expected: {
      'foo': {'bar': 'baz'},
      'qux': {'corge': 'grault', 'thud': 'fred'},
    },
  ),
  (
    name: 'A.7 moving an array element',
    document: {
      'foo': ['all', 'grass', 'cows', 'eat'],
    },
    operations: [
      {'op': 'move', 'from': '/foo/1', 'path': '/foo/3'},
    ],
    expected: {
      'foo': ['all', 'cows', 'eat', 'grass'],
    },
  ),
  (
    name: 'A.8 testing a value: success',
    document: {
      'baz': 'qux',
      'foo': ['a', 2, 'c'],
    },
    operations: [
      {'op': 'test', 'path': '/baz', 'value': 'qux'},
      {'op': 'test', 'path': '/foo/1', 'value': 2},
    ],
    expected: {
      'baz': 'qux',
      'foo': ['a', 2, 'c'],
    },
  ),
  (
    name: 'A.9 testing a value: error',
    document: {'baz': 'qux'},
    operations: [
      {'op': 'test', 'path': '/baz', 'value': 'bar'},
    ],
    expected: null,
  ),
  (
    name: 'A.10 adding a nested member object',
    document: {'foo': 'bar'},
    operations: [
      {
        'op': 'add',
        'path': '/child',
        'value': {'grandchild': <String, Object?>{}},
      },
    ],
    expected: {
      'foo': 'bar',
      'child': {'grandchild': <String, Object?>{}},
    },
  ),
  (
    name: 'A.11 ignoring unrecognized elements',
    document: {'foo': 'bar'},
    operations: [
      {'op': 'add', 'path': '/baz', 'value': 'qux', 'xyz': 123},
    ],
    expected: {'foo': 'bar', 'baz': 'qux'},
  ),
  (
    name: 'A.12 adding to a nonexistent target',
    document: {'foo': 'bar'},
    operations: [
      {'op': 'add', 'path': '/baz/bat', 'value': 'qux'},
    ],
    expected: null,
  ),
  (
    name: 'A.14 ~ escape ordering',
    document: {'/': 9, '~1': 10},
    operations: [
      {'op': 'test', 'path': '/~01', 'value': 10},
    ],
    expected: {'/': 9, '~1': 10},
  ),
  (
    name: 'A.15 comparing strings and numbers',
    document: {'/': 9, '~1': 10},
    operations: [
      {'op': 'test', 'path': '/~01', 'value': '10'},
    ],
    expected: null,
  ),
  (
    name: 'A.16 adding an array value',
    document: {
      'foo': ['bar'],
    },
    operations: [
      {
        'op': 'add',
        'path': '/foo/-',
        'value': ['abc', 'def'],
      },
    ],
    expected: {
      'foo': [
        'bar',
        ['abc', 'def'],
      ],
    },
  ),
];

/// More cases in the style of github.com/json-patch/json-patch-tests.
const _moreCases = <_Case>[
  (
    name: 'empty patch',
    document: {'foo': 1},
    operations: [],
    expected: {'foo': 1},
  ),
  (
    name: 'add replaces an existing member',
    document: {'foo': 1},
    operations: [
      {'op': 'add', 'path': '/foo', 'value': 2},
    ],
    expected: {'foo': 2},
  ),
  (
    name: 'add with a null value',
    document: {'foo': 1},
    operations: [
      {'op': 'add', 'path': '/bar', 'value': null},
    ],
    expected: {'foo': 1, 'bar': null},
  ),
  (
    name: 'add an object member whose name looks like an index',
    document: {'foo': <String, Object?>{}},
    operations: [
      {'op': 'add', 'path': '/foo/1', 'value': 'x'},
    ],
    expected: {
      'foo': {'1': 'x'},
    },
  ),
  (
    name: 'add a member with an empty name',
    document: {'foo': 1},
    operations: [
      {'op': 'add', 'path': '/', 'value': 2},
    ],
    expected: {'foo': 1, '': 2},
  ),
  (
    name: 'add at the end of a list by index',
    document: {
      'foo': [1, 2],
    },
    operations: [
      {'op': 'add', 'path': '/foo/2', 'value': 3},
    ],
    expected: {
      'foo': [1, 2, 3],
    },
  ),
  (
    name: 'add at the start of a list',
    document: {
      'foo': [1, 2],
    },
    operations: [
      {'op': 'add', 'path': '/foo/0', 'value': 0},
    ],
    expected: {
      'foo': [0, 1, 2],
    },
  ),
  (
    name: 'add past the end of a list',
    document: {
      'foo': [1, 2],
    },
    operations: [
      {'op': 'add', 'path': '/foo/3', 'value': 3},
    ],
    expected: null,
  ),
  (
    name: 'add with a negative index',
    document: {
      'foo': [1, 2],
    },
    operations: [
      {'op': 'add', 'path': '/foo/-1', 'value': 3},
    ],
    expected: null,
  ),
  (
    name: 'add with a leading zero index',
    document: {
      'foo': [1, 2],
    },
    operations: [
      {'op': 'add', 'path': '/foo/01', 'value': 3},
    ],
    expected: null,
  ),
  (
    name: 'add with an index that does not fit in an int',
    document: {
      'foo': [1, 2],
    },
    operations: [
      {'op': 'add', 'path': '/foo/99999999999999999999999', 'value': 3},
    ],
    expected: null,
  ),
  (
    name: 'add into a nested list',
    document: {
      'order': {
        'lines': [
          {'sku': 'A', 'quantity': 1},
        ],
      },
    },
    operations: [
      {
        'op': 'add',
        'path': '/order/lines/-',
        'value': {'sku': 'B', 'quantity': 2},
      },
      {'op': 'replace', 'path': '/order/lines/0/quantity', 'value': 40},
    ],
    expected: {
      'order': {
        'lines': [
          {'sku': 'A', 'quantity': 40},
          {'sku': 'B', 'quantity': 2},
        ],
      },
    },
  ),
  (
    name: 'add below a scalar',
    document: {'foo': 1},
    operations: [
      {'op': 'add', 'path': '/foo/bar', 'value': 2},
    ],
    expected: null,
  ),
  (
    name: 'add the whole document',
    document: {'foo': 1},
    operations: [
      {
        'op': 'add',
        'path': '',
        'value': {'bar': 2},
      },
    ],
    expected: {'bar': 2},
  ),
  (
    name: 'add without a value',
    document: {'foo': 1},
    operations: [
      {'op': 'add', 'path': '/bar'},
    ],
    expected: null,
  ),
  (
    name: 'remove a missing member',
    document: {'foo': 1},
    operations: [
      {'op': 'remove', 'path': '/bar'},
    ],
    expected: null,
  ),
  (
    name: 'remove a member whose value is null',
    document: {'foo': 1, 'bar': null},
    operations: [
      {'op': 'remove', 'path': '/bar'},
    ],
    expected: {'foo': 1},
  ),
  (
    name: 'remove the last list item',
    document: {
      'foo': [1, 2, 3],
    },
    operations: [
      {'op': 'remove', 'path': '/foo/2'},
    ],
    expected: {
      'foo': [1, 2],
    },
  ),
  (
    name: 'remove past the end of a list',
    document: {
      'foo': [1, 2],
    },
    operations: [
      {'op': 'remove', 'path': '/foo/2'},
    ],
    expected: null,
  ),
  (
    name: 'remove with "-"',
    document: {
      'foo': [1, 2],
    },
    operations: [
      {'op': 'remove', 'path': '/foo/-'},
    ],
    expected: null,
  ),
  (
    name: 'remove the whole document',
    document: {'foo': 1},
    operations: [
      {'op': 'remove', 'path': ''},
    ],
    expected: null,
  ),
  (
    name: 'replace a missing member',
    document: {'foo': 1},
    operations: [
      {'op': 'replace', 'path': '/bar', 'value': 2},
    ],
    expected: null,
  ),
  (
    name: 'replace a list item',
    document: {
      'foo': [1, 2],
    },
    operations: [
      {
        'op': 'replace',
        'path': '/foo/0',
        'value': {'a': 1},
      },
    ],
    expected: {
      'foo': [
        {'a': 1},
        2,
      ],
    },
  ),
  (
    name: 'replace with "-"',
    document: {
      'foo': [1, 2],
    },
    operations: [
      {'op': 'replace', 'path': '/foo/-', 'value': 3},
    ],
    expected: null,
  ),
  (
    name: 'replace the whole document',
    document: {'foo': 1},
    operations: [
      {
        'op': 'replace',
        'path': '',
        'value': {'baz': 'qux'},
      },
    ],
    expected: {'baz': 'qux'},
  ),
  (
    name: 'replace the whole document with a scalar',
    document: {'foo': 1},
    operations: [
      {'op': 'replace', 'path': '', 'value': 42},
    ],
    expected: null,
  ),
  (
    name: 'replace without a value',
    document: {'foo': 1},
    operations: [
      {'op': 'replace', 'path': '/foo'},
    ],
    expected: null,
  ),
  (
    name: 'move to the same place',
    document: {
      'foo': [1, 2],
    },
    operations: [
      {'op': 'move', 'from': '/foo/1', 'path': '/foo/1'},
    ],
    expected: {
      'foo': [1, 2],
    },
  ),
  (
    name: 'move a member up',
    document: {
      'foo': {
        'bar': [1, 2],
      },
    },
    operations: [
      {'op': 'move', 'from': '/foo/bar', 'path': '/bar'},
    ],
    expected: {
      'foo': <String, Object?>{},
      'bar': [1, 2],
    },
  ),
  (
    name: 'move into its own child',
    document: {
      'foo': {'bar': 1},
    },
    operations: [
      {'op': 'move', 'from': '/foo', 'path': '/foo/bar/baz'},
    ],
    expected: null,
  ),
  (
    name: 'move from a missing location',
    document: {'foo': 1},
    operations: [
      {'op': 'move', 'from': '/bar', 'path': '/baz'},
    ],
    expected: null,
  ),
  (
    name: 'move without from',
    document: {'foo': 1},
    operations: [
      {'op': 'move', 'path': '/baz'},
    ],
    expected: null,
  ),
  (
    name: 'copy a list into a list',
    document: {
      'foo': [1, 2],
      'bar': <Object?>[],
    },
    operations: [
      {'op': 'copy', 'from': '/foo', 'path': '/bar/-'},
    ],
    expected: {
      'foo': [1, 2],
      'bar': [
        [1, 2],
      ],
    },
  ),
  (
    name: 'copy the whole document into itself',
    document: {'foo': 1},
    operations: [
      {'op': 'copy', 'from': '', 'path': '/self'},
    ],
    expected: {
      'foo': 1,
      'self': {'foo': 1},
    },
  ),
  (
    name: 'copy from a missing location',
    document: {'foo': 1},
    operations: [
      {'op': 'copy', 'from': '/bar', 'path': '/baz'},
    ],
    expected: null,
  ),
  (
    name: 'test numbers by value',
    document: {'foo': 40},
    operations: [
      {'op': 'test', 'path': '/foo', 'value': 40.0},
    ],
    expected: {'foo': 40},
  ),
  (
    name: 'test objects regardless of member order',
    document: {
      'foo': {'a': 1, 'b': 2},
    },
    operations: [
      {
        'op': 'test',
        'path': '/foo',
        'value': {'b': 2, 'a': 1},
      },
    ],
    expected: {
      'foo': {'a': 1, 'b': 2},
    },
  ),
  (
    name: 'test lists in order',
    document: {
      'foo': [1, 2],
    },
    operations: [
      {
        'op': 'test',
        'path': '/foo',
        'value': [2, 1],
      },
    ],
    expected: null,
  ),
  (
    name: 'test a null value',
    document: {'foo': null},
    operations: [
      {'op': 'test', 'path': '/foo', 'value': null},
    ],
    expected: {'foo': null},
  ),
  (
    name: 'test null against a missing member',
    document: {'foo': 1},
    operations: [
      {'op': 'test', 'path': '/bar', 'value': null},
    ],
    expected: null,
  ),
  (
    name: 'test the whole document',
    document: {'foo': 1},
    operations: [
      {
        'op': 'test',
        'path': '',
        'value': {'foo': 1},
      },
    ],
    expected: {'foo': 1},
  ),
  (
    name: 'test without a value',
    document: {'foo': 1},
    operations: [
      {'op': 'test', 'path': '/foo'},
    ],
    expected: null,
  ),
  (
    name: 'unknown op',
    document: {'foo': 1},
    operations: [
      {'op': 'spam', 'path': '/foo', 'value': 1},
    ],
    expected: null,
  ),
  (
    name: 'missing op',
    document: {'foo': 1},
    operations: [
      {'path': '/foo', 'value': 1},
    ],
    expected: null,
  ),
  (
    name: 'missing path',
    document: {'foo': 1},
    operations: [
      {'op': 'add', 'value': 1},
    ],
    expected: null,
  ),
  (
    name: 'path that does not start with "/"',
    document: {'foo': 1},
    operations: [
      {'op': 'add', 'path': 'foo', 'value': 1},
    ],
    expected: null,
  ),
  (
    name: 'path with an invalid escape',
    document: {'foo': 1},
    operations: [
      {'op': 'add', 'path': '/foo~2', 'value': 1},
    ],
    expected: null,
  ),
  (
    name: 'path through "-" of a list',
    document: {
      'foo': [
        {'a': 1},
      ],
    },
    operations: [
      {'op': 'add', 'path': '/foo/-/a', 'value': 2},
    ],
    expected: null,
  ),
];

/// The document of RFC 6901, section 5.
const _rfc6901Document = {
  'foo': ['bar', 'baz'],
  '': 0,
  'a/b': 1,
  'c%d': 2,
  'e^f': 3,
  'g|h': 4,
  r'i\j': 5,
  'k"l': 6,
  ' ': 7,
  'm~n': 8,
};

void main() {
  group('applyJsonPatch', () {
    for (final (suite, cases) in [
      ('RFC 6902 Appendix A', _rfc6902AppendixA),
      ('conformance', _moreCases),
    ]) {
      group(suite, () {
        for (final (:name, :document, :operations, :expected) in cases) {
          test(name, () {
            if (expected == null) {
              expect(
                () => applyJsonPatch(document, operations),
                throwsA(isA<JsonPatchException>()),
              );
            } else {
              expect(applyJsonPatch(document, operations), expected);
            }
          });
        }
      });
    }

    test('resolves the pointers of RFC 6901, section 5', () {
      const values = {
        '': _rfc6901Document,
        '/foo': ['bar', 'baz'],
        '/foo/0': 'bar',
        '/': 0,
        '/a~1b': 1,
        '/c%d': 2,
        '/e^f': 3,
        '/g|h': 4,
        r'/i\j': 5,
        '/k"l': 6,
        '/ ': 7,
        '/m~0n': 8,
      };

      for (final MapEntry(key: path, :value) in values.entries) {
        expect(
          () => applyJsonPatch(_rfc6901Document, [
            {'op': 'test', 'path': path, 'value': value},
          ]),
          returnsNormally,
          reason: path,
        );
      }
    });

    test('applies all operations or none', () {
      final document = <String, Object?>{
        'order': {
          'lines': [
            {'sku': 'A', 'quantity': 1},
          ],
          'notes': 'Urgent',
        },
      };
      final before = copyJson(document);

      expect(
        () => applyJsonPatch(document, [
          {'op': 'replace', 'path': '/order/notes', 'value': 'Later'},
          {'op': 'remove', 'path': '/order/lines/0'},
          {'op': 'remove', 'path': '/order/lines/7'},
        ]),
        throwsA(
          isA<JsonPatchException>()
              .having((e) => e.message, 'message', contains('/order/lines/7'))
              .having((e) => e.operation, 'operation', {
                'op': 'remove',
                'path': '/order/lines/7',
              }),
        ),
      );
      expect(document, before);
    });

    test('never modifies the document or the operations', () {
      final value = <String, Object?>{
        'tags': ['new'],
      };
      final operations = [
        <String, Object?>{'op': 'add', 'path': '/order/meta', 'value': value},
        <String, Object?>{'op': 'remove', 'path': '/order/lines/0'},
      ];
      final document = <String, Object?>{
        'order': {
          'lines': [
            {'sku': 'A'},
          ],
        },
      };
      final documentBefore = copyJson(document);
      final operationsBefore = copyJson(operations);

      final result = applyJsonPatch(document, operations);

      expect(document, documentBefore);
      expect(operations, operationsBefore);
      expect(result, {
        'order': {
          'lines': <Object?>[],
          'meta': {
            'tags': ['new'],
          },
        },
      });
    });

    test('returns a result that shares nothing with its inputs', () {
      final value = <String, Object?>{
        'tags': ['new'],
      };
      final document = <String, Object?>{
        'order': {
          'lines': [
            {'sku': 'A'},
          ],
        },
      };

      final result = applyJsonPatch(document, [
        {'op': 'add', 'path': '/order/meta', 'value': value},
        {'op': 'copy', 'from': '/order/lines/0', 'path': '/order/lines/-'},
      ]);
      final order = result['order']! as Map<String, Object?>;
      final lines = order['lines']! as List<Object?>;
      (lines[0]! as Map<String, Object?>)['sku'] = 'changed';
      lines.add('more');
      ((order['meta']! as Map<String, Object?>)['tags']! as List<Object?>).add(
        'changed',
      );

      expect(document, {
        'order': {
          'lines': [
            {'sku': 'A'},
          ],
        },
      });
      expect(value, {
        'tags': ['new'],
      });
      expect(lines[1], {'sku': 'A'});
    });

    test('works on a constant document', () {
      const document = {
        'lines': [1, 2],
      };

      expect(
        applyJsonPatch(document, [
          {'op': 'add', 'path': '/lines/-', 'value': 3},
        ]),
        {
          'lines': [1, 2, 3],
        },
      );
    });

    test('applies every STATE_DELTA of the real ag-ui-adk streams', () {
      var deltas = 0;
      for (final name in AgUiAdkTranscripts.names) {
        var document = <String, Object?>{};
        for (final json in AgUiAdkTranscripts.frames(name)) {
          switch (WireEvent.fromJson(json)) {
            case StateSnapshot(:final snapshot):
              // ag-ui-adk's snapshot restates what its deltas wrote.
              for (final key in document.keys) {
                expect(snapshot[key], document[key], reason: '$name: $key');
              }
              document = snapshot;
            case StateDelta(:final operations):
              document = applyJsonPatch(document, operations);
              deltas++;
            case _:
          }
        }
      }
      expect(deltas, 17);
    });
  });
}
