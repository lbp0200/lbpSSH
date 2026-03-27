# UI Refinement Design — Refined Modern

**Date**: 2026-03-28
**Status**: Approved
**Approach**: Refined Modern — Keep layout, improve dark mode quality, spacing/typography, component polish

---

## Goals

1. **Dark mode quality** — Deeper contrast, softer accent colors, better readability
2. **Spacing & typography** — Consistent spacing system, refined font usage
3. **Component polish** — Cards, buttons, inputs, tabs — refined styling

---

## Color Palette

### Dark Mode

| Token | Hex | Usage |
|-------|-----|-------|
| background | #0B0F19 | Scaffold background |
| surface | #161B22 | Cards, sidebar, dialogs |
| surfaceRaised | #1C2128 | Elevated cards, dropdowns |
| border | #30363D | All borders in dark mode |
| borderSubtle | #21262D | Dividers, subtle separators |
| textPrimary | #E6EDF3 | Primary text |
| textSecondary | #8B949E | Secondary text, labels |
| textTertiary | #6E7681 | Hints, placeholders |
| accent | #238636 | Primary accent (softer green) |
| accentHover | #2EA043 | Hover state |
| accentMuted | rgba(35,134,54,0.15) | Background tint |

### Light Mode

| Token | Hex | Usage |
|-------|-----|-------|
| background | #FFFFFF | Scaffold background |
| surface | #F6F8FA | Cards, sidebar |
| surfaceRaised | #FFFFFF | Elevated cards |
| border | #D0D7DE | All borders |
| borderSubtle | #EAECEF | Dividers |
| textPrimary | #1F2328 | Primary text |
| textSecondary | #656D76 | Secondary text |
| textTertiary | #8C959F | Hints, placeholders |
| accent | #1A7F37 | Primary accent |
| accentHover | #2DA44E | Hover state |
| accentMuted | rgba(26,127,55,0.1) | Background tint |

---

## Spacing Scale

4pt base grid:

| Token | Value |
|-------|-------|
| xs | 4px |
| sm | 8px |
| md | 12px |
| lg | 16px |
| xl | 24px |
| xxl | 32px |

---

## Component Specifications

### Cards

- Border radius: 8px
- Border: 1px solid border color
- Box shadow: `0 1px 3px rgba(0,0,0,0.12)` (light), `0 1px 3px rgba(0,0,0,0.4)` (dark)
- Padding: 12px (compact) / 16px (standard)

### Buttons

- Border radius: 6px
- Horizontal padding: 16px → 12px (reduce)
- Vertical padding: 12px → 10px (tighten)
- Hover: background shift (darken/lighten 5%)

### Inputs

- Border radius: 6px
- Border: 1px solid border color
- Focus: accent border + subtle glow (`box-shadow: 0 0 0 3px accentMuted`)
- Height: 40px standard

### Sidebar Items

- Border radius: 8px
- Hover: background shift + left accent border (3px)
- Active: accent left border + slight background tint
- Transition: 150ms ease

### Tabs

- Height: 40px (reduce from 48px)
- Active: bottom border 2px accent
- Inactive: transparent bottom border
- Transition: 200ms ease

---

## Anti-Patterns to Fix

- ❌ Remove all `Colors.grey.shadeXXX` in dark mode
- ❌ Remove all manual `isDark ? Colors.white : Colors.black`
- ❌ Remove explicit hex colors like `#FFFFFF` in components
- ❌ Remove scattered `AppTheme.accentGreen` in widgets — use `Theme.of(context).colorScheme.primary`
- ❌ Remove scattered `.withValues(alpha: X)` — define as theme tokens

---

## Implementation Phases

### Phase 1 — Theme Foundation

1. Add semantic color tokens to `AppTheme`
2. Update `darkTheme` with new palette
3. Update `lightTheme` for consistency
4. Define spacing constants

### Phase 2 — Component Refinement

5. Refactor card styling
6. Refactor button styling
7. Refactor input styling

### Phase 3 — Widget Updates

8. Refactor `connection_list.dart`
9. Refactor `collapsible_sidebar.dart`
10. Refactor `terminal_view.dart`
11. Refactor `app_settings_screen.dart`
12. Update other widgets as needed

---

## Files to Modify

- `lib/core/theme/app_theme.dart` — Colors, spacing, theme data
- `lib/presentation/widgets/connection_list.dart`
- `lib/presentation/widgets/collapsible_sidebar.dart`
- `lib/presentation/widgets/terminal_view.dart`
- `lib/presentation/screens/app_settings_screen.dart`
- Other widget files using manual dark/light checks
