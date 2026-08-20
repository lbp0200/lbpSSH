# Design System Master File

> **LOGIC:** When building a specific page, first check `design-system/pages/[page-name].md`.
> If that file exists, its rules **override** this Master file.
> If not, strictly follow the rules below.

---

**Project:** lbpSSH
**Generated:** 2026-04-19 13:56:22
**Category:** Developer Tool / IDE
**Updated:** 2026-08-06 (aligned with `lib/core/theme/app_theme.dart`)

---

## Global Rules

### Color Palette

Dark-mode-first (Linear design system). Source of truth: `LinearColors` in `lib/core/theme/app_theme.dart`.

| Role | Hex | Token |
|------|-----|-------|
| Background | `#08090A` | `LinearColors.background` |
| Panel (app bar / sidebar) | `#0F1011` | `LinearColors.panel` |
| Surface (cards) | `#191A1B` | `LinearColors.surface` |
| Surface Elevated (menus/tooltips) | `#28282C` | `LinearColors.surfaceElevated` |
| Text Primary | `#F7F8F8` | `LinearColors.textPrimary` |
| Text Secondary | `#D0D6E0` | `LinearColors.textSecondary` |
| Text Tertiary | `#8A8F98` | `LinearColors.textTertiary` |
| Text Quaternary | `#62666D` | `LinearColors.textQuaternary` |
| Accent (buttons) | `#5E6AD2` | `LinearColors.accent` |
| Accent Interactive (focus/links) | `#7170FF` | `LinearColors.accentInteractive` |
| Accent Hover | `#828FFF` | `LinearColors.accentHover` |
| Border Subtle | `rgba(255,255,255,0.05)` | `LinearColors.borderSubtle` |
| Border Standard | `rgba(255,255,255,0.08)` | `LinearColors.borderStandard` |
| Border Solid | `#23252A` | `LinearColors.borderSolid` |
| Success | `#27A644` | `LinearColors.success` |
| Error | `#F85149` | `LinearColors.error` |
| Warning | `#D29922` | `LinearColors.warning` |

**Color Notes:** Near-black backgrounds, indigo-violet accent, translucent surfaces and semi-transparent borders (Linear style). Terminal itself uses `#1E1E1E` bg / `#D4D4D4` fg.

### Typography

- **Terminal font:** JetBrainsMono / JetBrainsMonoNerdFontMono (bundled in `assets/fonts/`)
- **UI font:** System default (Material 3), with negative letter-spacing on headings
- **Mood:** minimal, clean, functional, neutral, professional

### Spacing Variables

Source of truth: `LinearSpacing` in `lib/core/theme/app_theme.dart` (4/7/8/11/12/16/19/20/22/24/28/32/35 px scale).

| Token | Value | Usage |
|-------|-------|-------|
| `LinearSpacing.spacing4` | `4px` | Tight gaps |
| `LinearSpacing.spacing8` | `8px` | Icon gaps, inline spacing |
| `LinearSpacing.spacing16` | `16px` | Standard padding |
| `LinearSpacing.spacing24` | `24px` | Section padding |
| `LinearSpacing.spacing32` | `32px` | Large gaps |

### Radii

Source of truth: `LinearRadius` (2/4/6/8/12/22/9999 px scale).

| Token | Value | Usage |
|-------|-------|-------|
| `LinearRadius.micro` | `2px` | Tooltips |
| `LinearRadius.small` | `4px` | Chips |
| `LinearRadius.standard` | `6px` | Buttons, inputs |
| `LinearRadius.card` | `8px` | Cards, menu |
| `LinearRadius.panel` | `12px` | Dialogs |
| `LinearRadius.large` | `22px` | Large surfaces |
| `LinearRadius.pill` | `9999px` | Pills |

### Durations

Source of truth: `LinearDuration` (fast 150ms / normal 200ms / slow 300ms).

---

## Component Specs

### Buttons

```css
/* Primary Button (ElevatedButton) */
background: #5E6AD2 (LinearColors.accent);
color: white;
padding: 10px 16px;
border-radius: 6px; /* LinearRadius.standard */
font-weight: 500;
transition: all 150ms ease; /* LinearDuration.fast */
```

```css
/* Secondary Button (OutlinedButton) */
background: transparent;
color: #F7F8F8;
border: 1px solid #23252A (LinearColors.borderSolid);
border-radius: 6px;
```

```css
/* Text Button */
color: #7170FF (LinearColors.accentInteractive);
border-radius: 6px;
```

### Cards

```css
.card {
  background: #191A1B (LinearColors.surface);
  border: 1px solid rgba(255,255,255,0.08); /* borderStandard */
  border-radius: 8px; /* LinearRadius.card */
  padding: 16px;
}
```

### Inputs

```css
.input {
  padding: 12px 20px;
  background: rgba(255,255,255,0.10);
  border: 1px solid rgba(255,255,255,0.08);
  border-radius: 6px;
}

.input:focus {
  border-color: #7170FF; /* accentInteractive */
  border-width: 2px;
  box-shadow: none;
}
```

### Modals

```css
.modal {
  background: #191A1B; /* surface */
  border: 1px solid rgba(255,255,255,0.08);
  border-radius: 12px; /* LinearRadius.panel */
  padding: 24px;
  box-shadow: 0 20px 25px rgba(0,0,0,0.15);
}
```

---

## Style Guidelines

**Style:** Dark, minimal, functional (Linear design system)

**Keywords:** dark-mode-first, near-black, indigo-violet accent, translucent surfaces, semi-transparent borders, clean, focused, developer tool

**Best For:** SSH terminal manager, developer tooling, desktop productivity

---

## Anti-Patterns (Do NOT Use)

- ❌ Flat design without depth
- ❌ Text-heavy pages

### Additional Forbidden Patterns

- ❌ **Emojis as icons** — Use Material/SVG icons
- ❌ **Missing cursor:pointer** — All clickable elements must have cursor:pointer
- ❌ **Layout-shifting hovers** — Avoid scale transforms that shift layout
- ❌ **Low contrast text** — Maintain 4.5:1 minimum contrast ratio
- ❌ **Instant state changes** — Always use transitions (150-300ms)
- ❌ **Invisible focus states** — Focus states must be visible for a11y

---

## Pre-Delivery Checklist

Before delivering any UI code, verify:

- [ ] No emojis used as icons (use Material/SVG instead)
- [ ] All icons from consistent icon set
- [ ] `cursor-pointer` on all clickable elements
- [ ] Hover states with smooth transitions (150-300ms)
- [ ] Dark mode: text contrast 4.5:1 minimum
- [ ] Focus states visible for keyboard navigation
- [ ] `prefers-reduced-motion` respected
- [ ] No horizontal scroll
