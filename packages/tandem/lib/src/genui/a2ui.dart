/// A2UI wire fields read or written by Tandem.
/// https://a2ui.org/specification/v0_9_1
abstract final class A2uiFields() {
  static const createSurface = 'createSurface';
  static const updateComponents = 'updateComponents';
  static const surfaceId = 'surfaceId';
  static const catalogId = 'catalogId';
  static const components = 'components';

  static const id = 'id';
  static const component = 'component';
  static const child = 'child';
  static const children = 'children';
  static const componentId = 'componentId';
  static const path = 'path';
  static const text = 'text';
  static const variant = 'variant';

  static const action = 'action';
  static const event = 'event';
  static const name = 'name';
  static const context = 'context';

  static const call = 'call';
  static const args = 'args';
  static const value = 'value';
}
