# Topbar Items

A topbar item is an icon Muxy shows for a declared command. By default it sits in the right-hand cluster of the window title bar, just before the built-in pane and tab controls. Users can move visible `togglePanel` items into an optional icon-only right rail. The title bar spans the remaining window width after the left sidebar; the rail starts below the title-bar hairline, runs to the window bottom beside the status bar, and does not cover the title bar. Right panels stay under the title bar, to the left of the rail. Split-child panes are separated by dividers and do not add another tab strip or another copy of the window topbar. Clicking the item runs one of the extension's declared [commands](palette-commands.md).

```json
{
  "commands": [
    { "id": "open-pr", "title": "Open PR…", "action": { "kind": "openTab", "tabType": "pr-viewer" } }
  ],
  "topbarItems": [
    {
      "id": "pr",
      "icon": { "symbol": "arrow.triangle.pull" },
      "tooltip": "Open Pull Request",
      "command": "open-pr"
    }
  ]
}
```

## Fields

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `id` | string | yes | Unique within the extension. |
| `icon` | object | yes | `{ "symbol": "<sf-symbol>" }` or `{ "svg": "<path>" }`. A bare string is treated as a symbol. See [Icons](manifest.md#icons). |
| `tooltip` | string | no | Hover tooltip and accessibility label. Defaults to the `id`. |
| `command` | string | yes | Must reference a declared `commands[].id`. |
| `visible` | boolean | no | Whether the item shows on load. Defaults to `true`. Set `false` to start hidden and reveal it later with `muxy.topbar.show`. |

## Behavior

A click dispatches the referenced command through the same path as the command palette, running its `action` (`event`, `openTab`, `togglePanel`, `openPopover`, or `runScript`). The action's permissions still apply — e.g. a `runScript` action needs `commands:run-script`, while `togglePanel` and `openPopover` need `panels:write`. `openPopover` is special because the popover anchors to the topbar item that was clicked. See [Permissions](permissions.md).

Disabled extensions contribute no topbar items.

## Updating an item at runtime

The icon and visibility can change while the extension runs — from `background.js`, any tab/panel/popover page, or a [`runScript`](scripts.md) command — with `muxy.topbar.set`:

```js
muxy.topbar.set({ id: "pr", icon: { symbol: "checkmark.circle.fill" } });
muxy.topbar.set({ id: "pr", icon: "arrow.triangle.pull" }); // bare string == symbol
muxy.topbar.set({ id: "pr", visible: false });               // hide
muxy.topbar.show("pr");                                       // sugar for { visible: true }
muxy.topbar.hide("pr");                                       // sugar for { visible: false }
```

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | Must reference a declared `topbarItems[].id`. |
| `icon` | string \| object | New icon: `"<sf-symbol>"`, `{ symbol }`, or `{ svg }` (the SVG must be a file bundled with the extension). Omit to leave the icon unchanged. |
| `visible` | boolean | Show or hide the item. Omit to leave visibility unchanged. |

Decide visibility at runtime: declare the item with `"visible": false` so it stays hidden until your `background.js` calls `muxy.topbar.show(id)` (e.g. once a repo is detected), then `muxy.topbar.hide(id)` when it no longer applies.

Needs `panels:write`. The override is in-memory for the session; disabling or reloading the extension restores the manifest icon and visibility. Throws on an unknown `id`.

## Placement and order

By default, items sit in the window title bar's right-hand cluster. In a single-pane Project Focused workspace they precede the built-in **Split** group. Among themselves they are ordered by extension directory name, then by their order in the `topbarItems` array. Title-bar placement always uses that default order.

Users can turn on **Show Extension Icon Rail** to move visible `togglePanel` items off the title bar into an icon-only rail on the right. The rail starts below the title-bar hairline and runs to the window bottom beside the status bar; it does not occupy the title-bar row. Docked and floating right panels stay under the title bar, to the left of the rail. Popover and other command icons stay in the title bar. The rail hides when no `togglePanel` items are visible. Rail order is the persisted `extensionID:itemID` list of rail IDs only; IDs that are currently visible as non-rail items are dropped, new rail items append, and hidden `togglePanel` items keep their saved slot and restore into it. Drag-reorder on the rail writes that list. Title-bar placement ignores this list and keeps the default directory-then-manifest order. The `muxy.topbar.*` API names stay the same.

## Limits

- A `command` that references an unknown id fails the manifest load.
- SVG icons must live inside the extension directory, end in `.svg`, and be at most 256 KiB.
