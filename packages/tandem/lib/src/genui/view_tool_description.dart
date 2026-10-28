import 'package:tandem/src/genui/catalog.dart';

/// The description of `tandem_show_view`: Tandem's catalog in A2UI, with one
/// example, for the model to read with the tool.
const viewToolDescription =
    '''
Shows a view on the user's screen, written in A2UI $a2uiVersion with only the components below. Each call replaces the whole view.

Pass "messages": a JSON array of exactly these two messages:
[
  {"version": "$a2uiVersion", "createSurface": {"surfaceId": "main", "catalogId": "$tandemCatalogId"}},
  {"version": "$a2uiVersion", "updateComponents": {"surfaceId": "main", "components": [ ... ]}}
]

"components" is a flat list. Every component has a unique "id" and a "component" type, one has the id "root", and a parent names its children by id.

- Text: "text", "variant": h1 | h2 | h3 | h4 | h5 | caption | body.
- Column, Row, List: "children": a list of ids, or {"componentId": <id>, "path": <path of a list>} to repeat one component for every item. Below it, a path without a leading "/" starts at the item, and "." is the item itself.
- Card: "child": an id.
- Divider.
- Button: "child": the id of its Text, "variant": default | primary | borderless, "action": {"event": {"name": <method>, "context": {<parameter>: <value>}}}.

A "text" is a string, {"path": <path>}, or {"call": "formatString", "args": {"value": "Total: \${/cart/total}"}, "returnType": "string"} to mix words and data.

Your context holds the screen's data: the entry "<name>: ..." is at the path /<name>.

Rules:
- Draw at most 500 components, counting every repeated list item and nested component.
- Show the screen's data only by path, never as copied text, so that the view follows the screen.
- A button calls one of the screen's methods, which are your other tools, with their parameter names; a value can be a path. When the user presses it, the method runs in the app, and app_notes in your context tells you what it answered.
- Nothing else: no other components, properties, functions or message types.
- Component accessibility metadata is not supported, including an empty accessibility object. Omit it; texts and buttons keep Flutter's default accessibility.

Example. Context: cart: {"items": [{"name": "Milk", "price": "2.50"}], "total": "2.50"}. Tools: remove_item(name), check_out(). The user asks to see the cart and remove items from it, so you call tandem_show_view with these messages:
[
  {"version": "$a2uiVersion", "createSurface": {"surfaceId": "main", "catalogId": "$tandemCatalogId"}},
  {"version": "$a2uiVersion", "updateComponents": {"surfaceId": "main", "components": [
    {"id": "root", "component": "Card", "child": "body"},
    {"id": "body", "component": "Column", "children": ["title", "lines", "total", "check_out"]},
    {"id": "title", "component": "Text", "variant": "h2", "text": "Your cart"},
    {"id": "lines", "component": "List", "children": {"componentId": "line", "path": "/cart/items"}},
    {"id": "line", "component": "Row", "children": ["name", "price", "remove"]},
    {"id": "name", "component": "Text", "text": {"path": "name"}},
    {"id": "price", "component": "Text", "text": {"path": "price"}},
    {"id": "remove", "component": "Button", "child": "remove_label", "variant": "borderless", "action": {"event": {"name": "remove_item", "context": {"name": {"path": "name"}}}}},
    {"id": "remove_label", "component": "Text", "text": "Remove"},
    {"id": "total", "component": "Text", "text": {"call": "formatString", "args": {"value": "Total: \${/cart/total}"}, "returnType": "string"}},
    {"id": "check_out", "component": "Button", "child": "check_out_label", "variant": "primary", "action": {"event": {"name": "check_out"}}},
    {"id": "check_out_label", "component": "Text", "text": "Check out"}
  ]}}
]''';
