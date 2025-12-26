# Yjs Cursor Visualization Guide

## Overview

This document explains how different users' cursors and selections appear in the collaborative CodePad editor.

## Visual Representation

### In the Monaco Editor

```
┌─────────────────────────────────────────────────────────────┐
│  1  def fibonacci(n):                                       │
│  2      if n <= 1:                                          │
│  3          return n                                        │
│  4      return fibonacci(n-1) + fibonacci(n-2)              │
│  5                                                           │
│  6  ┌─────────┐                                             │
│  7  │ alice   │ ← Username label (Red background)           │
│  8  │for i in range(10):                                    │
│  9  │    print(fibonacci(i))                                │
│ 10  └─────────────────────┘                                 │
│     └─ Light red selection background with red border       │
│        Cursor: 3px red blinking border on left side         │
│                                                              │
│ 11  ┌──────┐                                                │
│ 12  │ bob  │ ← Username label (Blue background)             │
│ 13  │# TODO: Add memoization                                │
│ 14  │                                                        │
│     └─ Cursor: 3px blue blinking border                     │
└─────────────────────────────────────────────────────────────┘
```

## Color Coding

### 10 Predefined Colors

| Color Name     | Hex Code  | Usage                                    |
|----------------|-----------|------------------------------------------|
| Red            | `#e74c3c` | User 1                                   |
| Blue           | `#3498db` | User 2                                   |
| Green          | `#2ecc71` | User 3                                   |
| Orange         | `#f39c12` | User 4                                   |
| Purple         | `#9b59b6` | User 5                                   |
| Turquoise      | `#1abc9c` | User 6                                   |
| Pink           | `#e91e63` | User 7                                   |
| Cyan           | `#00bcd4` | User 8                                   |
| Deep Orange    | `#ff5722` | User 9                                   |
| Light Green    | `#8bc34a` | User 10                                  |

**Note**: Colors are randomly assigned when a user joins. If more than 10 users join, colors will cycle.

## Component Breakdown

### 1. Cursor (Remote User's Current Position)

```
│
│ ← 3px solid border
│    Color: User's assigned color
│    Animation: Blinking (1s cycle)
│    Z-index: 12 (above selections)
```

**CSS Properties**:
```css
border-left-width: 3px;
border-left-style: solid;
border-left-color: #e74c3c; /* User's color */
animation: cursor-blink 1s ease-in-out infinite;
```

### 2. Selection (Remote User's Highlighted Text)

```
┌───────────────────────────┐
│ Light background (25% opacity)
│ 1px border in user's color
│ Z-index: 11 (below cursor)
└───────────────────────────┘
```

**CSS Properties**:
```css
background: rgba(231, 76, 60, 0.25); /* User's color at 25% */
border: 1px solid rgba(231, 76, 60, 0.25);
mix-blend-mode: normal;
pointer-events: none;
```

### 3. Username Label (Identifies the User)

```
┌──────────┐
│  alice   │ ← White text, bold (600)
└──────────┘    12px font size
     ↑          2-8px padding
     └─ Background: User's color (#e74c3c)
        Shadow: 0 2px 4px rgba(0,0,0,0.3)
        Border radius: 4px
```

**CSS Properties**:
```css
background-color: #e74c3c; /* User's color */
color: #fff;
font-size: 12px;
font-weight: 600;
padding: 2px 8px;
border-radius: 4px;
box-shadow: 0 2px 4px rgba(0,0,0,0.3);
z-index: 13; /* Above everything */
```

## Blinking Animation

The cursor blinks to draw attention and indicate active presence:

```css
@keyframes cursor-blink {
  0%, 49% {
    opacity: 1;      /* Fully visible */
  }
  50%, 100% {
    opacity: 0.6;    /* Slightly faded */
  }
}
```

**Duration**: 1 second per cycle
**Effect**: Subtle fade from 100% to 60% opacity

## Peer List (Top Right of CodePad)

In addition to cursors in the editor, users are also shown in the peer list:

```
┌───────────────────────────────────────┐
│  Peers:                               │
│  ● alice    (red dot)                 │
│  ● bob      (blue dot)                │
│  ● User-x7a (green dot)               │
└───────────────────────────────────────┘
```

Each peer:
- Shows username (real or guest)
- Has a colored dot matching their cursor/selection color
- Updates in real-time as users join/leave

## Real-World Example

### Scenario: Admin Interview with 3 Candidates

```
Admin creates room → 3 candidates join via invite link

┌─────────────────────────────────────────┐
│ Monaco Editor                           │
│                                         │
│ ┌─────────┐                             │
│ │ alice   │ (Red - Candidate 1)         │
│ │def solve(arr):                        │
│ │    return sorted(arr)                 │
│ └─────────────────┘                     │
│                                         │
│ ┌──────┐                                │
│ │ bob  │ (Blue - Candidate 2)           │
│ │# Testing edge cases                   │
│ │                                       │
│                                         │
│ ┌──────────┐                            │
│ │ charlie  │ (Green - Candidate 3)      │
│ │assert solve([3,1,2]) == [1,2,3]      │
│ │                                       │
│                                         │
│ Peers: ● alice  ● bob  ● charlie       │
└─────────────────────────────────────────┘
```

**Visual Benefits**:
- ✅ Admin can instantly see who is typing where
- ✅ Colors make it easy to track multiple users
- ✅ Username labels prevent confusion
- ✅ Blinking cursors indicate active users
- ✅ Selection highlights show what each user is focusing on

## Implementation Details

### Color Assignment Logic

```typescript
// In CodePad component (onMount callback)
const colorPalette = [ /* 10 colors */ ];
const colorIndex = Math.floor(Math.random() * colorPalette.length);
const { color, colorLight } = colorPalette[colorIndex];

awareness.setLocalState({
  user: {
    name: userName,      // From /api/auth/me
    color: color,        // Solid color for cursor/label
    colorLight: colorLight // Transparent color for selection
  }
});
```

### Dynamic Style Injection

For each connected user, the CodePad component dynamically injects CSS rules:

```typescript
const applyClientStyles = () => {
  const states = awareness.getStates();
  const rules = [];

  states.forEach((state, clientId) => {
    const { color, colorLight } = state.user;

    // Generate CSS for this user's cursor, selection, and label
    rules.push(`
      .yRemoteSelectionHead-${clientId} {
        border-left-color: ${color};
        /* ... */
      }
      .yRemoteSelection-${clientId} {
        background: ${colorLight};
        /* ... */
      }
      .yRemoteSelectionHead-${clientId} .yRemoteSelectionHeadLabel {
        background-color: ${color};
        /* ... */
      }
    `);
  });

  styleEl.textContent = rules.join('\n');
};

// Update styles when users join/leave or change colors
awareness.on('change', applyClientStyles);
```

## Accessibility Considerations

- **High contrast**: Colors are vibrant and distinct
- **Multiple indicators**: Color + username + position
- **Clear boundaries**: 1px borders on selections
- **Size**: 12px labels are readable
- **Shadow**: Ensures labels are visible on any background

## Troubleshooting

### Cursors not showing different colors

**Check**:
1. Multiple users are connected to the same room
2. Each user has a unique `clientId` in Yjs awareness
3. Browser DevTools > Elements > `<style id="y-remote-style-...">` contains CSS rules

**Fix**: Refresh the page and ensure WebSocket connection is established

### Username labels not visible

**Check**:
1. User authentication is working (`/api/auth/me` returns username)
2. Awareness state includes `{ user: { name, color, colorLight } }`
3. CSS for `.yRemoteSelectionHeadLabel` is applied

**Fix**: Check browser console for errors, ensure `awareness.setLocalState()` is called

### Colors look similar

**Issue**: Random color assignment may occasionally assign similar colors to adjacent users

**Solution**: Current implementation uses 10 distinct colors from a predefined palette, reducing this issue significantly compared to pure HSL randomization
