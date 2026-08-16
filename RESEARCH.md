# Research

Product and architecture notes for work planned from brainstorm sessions. External API research is not required for the current effort.

## Decisions

### 2026-08-16 — Optional vertical extension icon rail

Source: brainstorm grilling for moving extension topbar items off the title bar.

1. **Rail contents**
   - Chosen: only visible extension topbar items (the same icons that appear in the title-bar cluster today).
   - Why: those items already declare an icon, tooltip, and command. Extensions without a topbar item already have the Extension Store and Extensions view.
   - Rejected: listing every enabled extension as a launcher.

2. **Default**
   - Chosen: opt-in. The preference defaults to off.
   - Why: the user called this a breaking layout change; current title-bar placement stays the default.
   - Rejected: turning the rail on for everyone.

3. **Move vs duplicate**
   - Chosen: when the rail is on, items leave the title bar. Built-in title-bar actions stay.
   - Why: the request is to move the icons, not to show them twice.
   - Rejected: showing the same items in both the title bar and the rail.

4. **Chrome**
   - Chosen: icon-only rail. No expand/collapse, no labels.
   - Why: topbar items are already icon plus tooltip. Collapse/expand would copy left-sidebar machinery without need.
   - Rejected: an expandable named list.

5. **Empty state**
   - Chosen: hide the rail when no enabled extension has a visible topbar item.
   - Why: do not reserve empty chrome.
   - Rejected: a persistent empty strip.

6. **Independence from Show Top Bar Actions**
   - Chosen: the rail has its own setting. “Show Top Bar Actions” continues to hide built-in title-bar controls only.
   - Why: once items have moved, hiding window chrome should not also hide the rail.
   - Rejected: keeping rail visibility tied to `muxy.showTopBarActions`.

7. **Vertical span**
   - Chosen: full-height right column, the mirror of the left project rail.
   - Why: matches the left-side analog and keeps the title bar free of extension icons.
   - Rejected: a rail only under the title bar inside the workspace column.

8. **Overflow**
   - Chosen: vertical scroll. No wrap. No overflow button.
   - Why: simplest match for a tall icon list.
   - Rejected: clipping or a chevron overflow menu.

9. **Remembered order**
   - Chosen: persist a stable `extensionID:itemID` list. New visible items append. Hidden or disabled items leave the live rail. If an item returns and is still in the saved list, restore that slot; otherwise append.
   - Why: drag order should survive relaunch without inventing a second sort mode.
   - Rejected: session-only order.

10. **Order when the rail is off**
    - Chosen: title-bar placement uses today’s default order (extension directory name, then `topbarItems` array order). Saved rail order is ignored while the rail is off.
    - Why: turning the setting off should restore the documented current behavior, not a custom sequence.
    - Rejected: applying the custom order in both placements.

11. **Layouts**
    - Chosen: Project Focused, Tab Focused, and Agents Focused.
    - Why: those items already appear in every layout.
    - Rejected: limiting the rail to one layout.

12. **Click behavior**
    - Chosen: same as today — run the command or toggle the popover on that icon. No new context menu.
    - Why: this is a placement change, not a new interaction model.
    - Rejected: extra chrome on the rail items.
