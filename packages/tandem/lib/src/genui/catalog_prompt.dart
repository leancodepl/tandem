import 'package:tandem/src/genui/a2ui.dart';
import 'package:tandem/src/genui/catalog.dart';

/// The description of `show_view`, which teaches the agent the catalog with
/// one example.
const catalogPrompt =
    '''
Shows a view on the user's screen, drawn in A2UI $a2uiVersion with the components below and nothing else. Each call replaces the whole view.

Pass "messages": a JSON array of two messages:
[
  {"version": "$a2uiVersion", "createSurface": {"surfaceId": "main", "catalogId": "$tandemCatalogId"}},
  {"version": "$a2uiVersion", "updateComponents": {"surfaceId": "main", "components": [ ... ]}}
]

Components are a flat list. Each has a unique "id" and a "component" type. The first one has the id "root". A parent names its children by id.

- Text: "text" (a string, {"path": ...}, or a formatString call), "variant": h1 | h2 | h3 | caption | body.
- Column, Row, List: "children": a list of ids, or {"componentId": <id>, "path": <list path>} to repeat one component for each item of a list. Inside the repeated component, paths are relative to the item, such as {"path": "customer"}, and {"path": "."} is the item itself.
- Card: "child": one id.
- Divider: nothing else.
- Button: "child": the id of a Text, "action": {"event": {"name": <tool>, "context": {<parameter>: <value or {"path": ...}>}}}, "variant": default | primary | borderless.

A text may mix words and values, always under "text": {"call": "formatString", "args": {"value": "Total: \${/cart/total}"}, "returnType": "string"}.

The screen's data is your context: an entry "<name>: ..." is at the path /<name>.

Rules:
- Show the screen's data only by path, never as copied text.
- A button calls one of your other tools when the user clicks it, with its parameter names. You see what it did in your context next time.
- No other components, properties, functions or message types.

Example. Context: profile: {"name": "Ann", "email": "ann@example.com"}. Tools: save_profile(). The user asks to see their profile, and you call show_view with these messages:
[
  {"version": "$a2uiVersion", "createSurface": {"surfaceId": "main", "catalogId": "$tandemCatalogId"}},
  {"version": "$a2uiVersion", "updateComponents": {"surfaceId": "main", "components": [
    {"id": "root", "component": "Card", "child": "body"},
    {"id": "body", "component": "Column", "children": ["title", "email", "save"]},
    {"id": "title", "component": "Text", "variant": "h2", "text": {"call": "formatString", "args": {"value": "Profile of \${/profile/name}"}, "returnType": "string"}},
    {"id": "email", "component": "Text", "text": {"path": "/profile/email"}},
    {"id": "save", "component": "Button", "child": "save_label", "variant": "primary", "action": {"event": {"name": "save_profile"}}},
    {"id": "save_label", "component": "Text", "text": "Save"}
  ]}}
]''';
