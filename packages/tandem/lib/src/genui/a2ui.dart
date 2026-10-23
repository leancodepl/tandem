/// The A2UI version Tandem reads and draws, as messages name it.
/// https://a2ui.org/specification/v0_9_1
const a2uiVersion = 'v0.9.1';

/// A2UI wire fields read or written by Tandem.
abstract final class A2uiFields() {
  static const version = 'version';

  static const createSurface = 'createSurface';
  static const updateComponents = 'updateComponents';
  static const updateDataModel = 'updateDataModel';
  static const deleteSurface = 'deleteSurface';

  static const surfaceId = 'surfaceId';
  static const catalogId = 'catalogId';
  static const components = 'components';

  static const id = 'id';
  static const component = 'component';
  static const children = 'children';
  static const child = 'child';
  static const componentId = 'componentId';
  static const path = 'path';

  static const action = 'action';
  static const event = 'event';
  static const functionCall = 'functionCall';
  static const name = 'name';
  static const context = 'context';

  static const call = 'call';
  static const args = 'args';
  static const value = 'value';
  static const returnType = 'returnType';

  static const text = 'text';
  static const variant = 'variant';

  static const protocolVersion = 'protocolVersion';
  static const functions = 'functions';
}

/// The messages an agent may send to draw on a screen. Screen data comes
/// only from `.sees`, so `updateDataModel` is not one of them.
const allowedA2uiMessages = [
  A2uiFields.createSurface,
  A2uiFields.updateComponents,
  A2uiFields.deleteSurface,
];
