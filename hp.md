# hokusai-pocket — Text Input Handling: Acceptance Criteria

## Cursor & caret
- [x] Cursor renders at correct pixel position for current `PieceTable` offset, accounting for word-wrap
- [ ] Cursor blinks/shows only when field has keyboard focus
- [ ] Left/Right arrow moves by one grapheme cluster (no landing mid-emoji/combining char)
- [ ] Up/Down preserves horizontal goal column across lines of different length, incl. wrapped lines
- [ ] Home/End behavior confirmed for visual vs. logical line
- [ ] Ctrl/Option+Left/Right jumps by word boundary per platform convention
- [ ] Click places cursor at nearest character boundary, not nearest pixel
- [ ] Cursor clamps correctly at document start/end

## Text insertion (PieceTable)
- [ ] Typing inserts at cursor, advances by one grapheme
- [ ] Insert at start/middle/end/piece-boundary doesn't corrupt piece table
- [ ] Paste inserts full clipboard content, cursor lands after it
- [ ] IME composition buffers correctly, commits only on confirmation
- [ ] Rapid/held keypresses don't drop or reorder characters
- [ ] Unicode/emoji/combining chars round-trip without corruption

## Deletion
- [ ] Backspace/Delete removes one grapheme left/right
- [ ] Backspace/Delete with active selection deletes whole selection
- [ ] Ctrl/Option+Backspace deletes previous word
- [ ] Deleting across piece boundary merges/splits pieces correctly
- [ ] Deleting entire buffer leaves valid empty state

## Selection
- [ ] Shift+Arrow extends/shrinks by grapheme; Shift+Ctrl+Arrow by word
- [ ] Click-drag selection matches geometry across wrapped lines
- [ ] Double-tap/click selects word under cursor
- [ ] Triple-tap/click selects full line (if supported)
- [ ] Drag past visible edge auto-scrolls and continues selecting
- [ ] Selection highlight matches selected text exactly across wraps
- [ ] Typing/pasting during active selection replaces it
- [ ] Selection survives resize/re-wrap via logical position remap
- [ ] Copy with no selection is safe no-op

## Word wrap & layout
- [ ] Resize reflow preserves cursor/selection logical position
- [ ] Long unbroken strings wrap mid-word instead of overflowing
- [ ] Wrap cache invalidates correctly for all affected lines, not just edited one
- [ ] Scroll-into-view keeps cursor visible on arrow key/typing

## Touch input
- [ ] Tap places cursor; tap-hold invokes selection/word-select
- [ ] Swipe scrolls rather than selects (outside active drag)
- [ ] Pinch doesn't trigger unintended selection or internal zoom
- [ ] Selection handle touch targets are large enough and distinct from tap-to-place

## Keyboard event edge cases
- [ ] KeyDown/KeyPress/KeyUp sequence doesn't double-insert characters
- [ ] Held modifiers don't leak into character insertion
- [ ] Non-printable keys ignored by buffer unless explicitly bound
- [ ] Focus loss mid-IME-composition commits/discards cleanly

## Undo/redo
- [ ] Each logical edit is one undo step (confirm granularity)
- [ ] Undo after multi-piece delete/insert restores exact prior state
- [ ] Redo restores exact cursor/selection state, not just text

## State/props
- [ ] `cursor_color` prop renders and updates live
- [ ] Empty state doesn't crash on read at position 0
- [ ] Disabled/non-focused state ignores keyboard/touch input
