# Local inference documentation design

Shared guideline for miyako/uzu, miyako/llama-cpp, miyako/onnx-genai,
miyako/CTranslate2, and miyako/swama. Version 1, 2026-11-02.

## Intent and boundaries

These are a family of documentation sites, not five unrelated landing pages.
Use the same shell, hierarchy, spacing, components, and responsive behavior.
Keep engine names, logos, accent colors, supported platforms, endpoints, ports,
model formats, installation paths, and capability-specific sections accurate.
Do not invent feature parity or remove content or links to obtain visual parity.
Keep each repository's build pipeline and existing URL/anchor contracts.

## Tokens and type

Use semantic CSS variables; existing variable names may alias these values.
Do not share a runtime stylesheet across repositories or add a CSS framework.

| Token | Light | Dark |
|---|---|---|
| paper | `#faf9f6` | `#1b1e22` |
| surface (cards/nodes) | `#ffffff` | `#23272c` |
| sidebar background | `#f3f3ef` | `#23272c` |
| ink | `#202b38` | `#e7ebef` |
| muted | `#596675` | `#b0bac4` |
| line | `#e0e3e5` | `#3a424c` |
| panel gradient end | `#edf1f5` | `#292f36` |
| code background | `#122b3b` | `#101820` |
| code foreground | `#faf6e4` | `#faf6e4` |
| panel shadow | `0 18px 45px -30px #233c60` | `0 18px 45px -30px #000000` |

Brand accents: Uzu `#28664d`, ONNX `#28644b`, llama.cpp/Swama `#265da2`,
CTranslate2 `#963239`. Dark accents: green `#9dc9aa`, blue `#9fc5f5`,
burgundy `#efa2a4`. Accent-soft light: green `#e8eee1`, blue `#e1e9f4`,
burgundy `#f2e5e3`; dark: green `#293d30`, blue `#26384d`,
burgundy `#38282d`. Primary buttons use white text in light mode and dark
ink (`#1b1e22`) in dark mode. Apply automatic `prefers-color-scheme` and
declare `color-scheme: light dark`; no theme toggle is required.

System sans-serif stack: `-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`.
Body `16px/1.8`; paragraph bottom margin `20px`. Headings `1.2` line height.
Hero H1 `clamp(36px, 4.5vw, 64px)`, weight `650`, tracking `-1.3px`,
bottom margin `25px`; allow natural wrapping (no forced nowrap).
H2 `clamp(27px, 3vw, 36px)`, weight `650`; H3 `20px`.
Hero lede `17px/1.8`, muted, max width `610px`.
Eyebrows/section indices `11px`, weight `700`, uppercase, tracking `1.5px`.
Small meaningful labels must be at least `11px`; do not shrink badges to 8px.
Monospace: `"SFMono-Regular", Consolas, "Liberation Mono", monospace`.

## Shell and rhythm

Use border-box sizing. Fixed desktop sidebar `252px`, padding `34px 25px 24px`,
overflow-y auto. Workspace offset matches sidebar. Brand icon `42px`, gap `12px`,
wordmark `22px/1.25` with an `11px` subtitle.
Navigation links `13px/1.5`, padding `8px 10px`, radius `5px`, gap `4px`;
active links use accent plus accent-soft.
Topbar min-height `76px`, padding `18px 48px`, `12px` type; wrap rather than clip.
Main and footer centered, max-width `1240px` including `64px` inline padding.
Content sections have `56px` block padding and a bottom border.
Footer `11px`, wraps, gap `20px`, padding-block `28px 34px`.

At `<=1200px`: sidebar `225px`, padding-inline `18px`; main, footer,
topbar inline padding `36px`; hero gap `28px`; panel padding `18px`.
At `<=1000px`: hero becomes one column with `28px` row gap, copy max `620px`,
panel width `100%` / max `520px`; cards become one column. Keep desktop sidebar
until the mobile breakpoint. Never hide the stack diagram.
At `<=720px`: sidebar becomes static/full width, padding `20px 24px`;
hide only sidebar captions/bottom/section labels, not navigation links.
Navigation wraps (no horizontal nav strip), workspace offset zero.
Main/footer inline padding `24px`; topbar min-height `60px`, padding `14px 24px`.
Hero padding `44px 0 36px`; lede `16px`; sections `38px 0`; cards padding `24px`.
Do not hide topbar links at narrow widths; let them wrap.
At `<=380px`: main/footer/sidebar/topbar inline padding `18px`.

## Hero and local stack

Desktop hero: copy on the left, local stack on the right, in the same grid.
Columns `minmax(0, 1.2fr) minmax(300px, 380px)`, gap `44px`, align center;
padding `72px 0 48px`. No separate decorative hero logo competing with the stack.
Metadata, if present, spans both columns; preserve project-specific metadata.

Panel: 1px line border, radius `12px`, padding `24px`, gradient `145deg`
surface to panel-end, shared panel-shadow token. Min-width zero.
Header: "The local stack" label, "On your machine" tag; flex-wrap,
gap `10px`, align center, margin-bottom `28px`. Tag uses accent-soft/accent,
`11px` type, `3px 7px` padding, radius `4px`.
App/model rows: unboxed, flex, gap `13px`; title `14px/1.4`, subtitle `12px/1.5`.
4D mark: bordered surface, radius `9px`, `19px` bold, padding `6px 10px`.
Connector between app and engine: dashed left line, margin `6px 0 6px 23px`,
padding `10px 18px`, `11px/2` monospace muted text. Use the same connector
between engine and model, labeled "loads". No horizontal floating arrow labels.
Show the real protocol/host/port; do not imply HTTP for non-HTTP integrations.
Engine: surface, 1px line border, radius `8px`, padding `16px`, gap `13px`;
logo `52px` square with matching HTML dimensions and empty alt.
Title `20px` (may wrap), subtitle `12px`. Optional badge `11px`, kept in normal
flow or on its own row so it cannot overlap the title or connector.
Model mark: radius `5px`, `10px 8px` padding, `12px` monospace, accent-soft/accent.
Use `.onnx` for ONNX; preserve each other engine's truthful extension/directory
mark. The text must still explain directory-based model loading where applicable.
Panel footer: top border, padding-top `14px`, gap `8px`, `12px` muted text;
wrap capability lists. Preserve project-specific endpoint lists or explanations.

## Reusable components

Actions wrap, gap `12px`, margin-top `30px`.
Buttons: min-height `44px`, padding `11px 17px`, radius `6px`, 1px line border,
`13px` / weight `600`; accent primary, surface secondary.
Cards: two minmax-zero columns, gap `18px`; padding `26px`, radius `8px`,
1px line border, surface; body `14px/1.8`. Hover accent border and subtle
`translateY(-2px)`; transition `.2s`, disabled for reduced motion.
Tables: enclosing horizontal-scroll wrapper, 1px line border, radius `7px`;
`13px` body, `11px` caption/header, cell padding `14px 16px` (`12px` mobile).
Never clip or hide columns to fit mobile.
Code: `13px/1.85`, padding `24px`, radius `7px`, horizontal scroll, no wrapping
inside pre; inline code `.86em`, surface background, `2px 4px` padding.
Where syntax highlighting exists, comments use `#9fb3c1` and error/deletion
foregrounds use `#ff9a9a` on the dark code background; retain other syntax colors
that pass contrast. Error tokens with a red background retain pale foregrounds.
Wrapped pre reserves `48px` top padding for the copy control; keep the same font,
colors and size as unwrapped pre despite legacy copy.css cascades.
Copy control min-height `32px`, `11px` type, top/right `8px`; preserve success
feedback and show an explicit failure message (not console-only).
Callouts: padding `22px 24px`, accent-soft, 3px accent left rule, radius
`0 6px 6px 0`, `14px` text.

## Accessibility and verification

Keep semantic landmarks, one H1, descriptive nav, current-page indicator,
working keyboard skip link and a focusable main target (`tabindex="-1"`).
Stack container has `role="group"` and a meaningful `aria-label`. Decorative
logos, connector lines and file marks are `aria-hidden` or empty-alt.
Never hide meaningful model/protocol information from assistive technology.
Links/buttons have a visible 3px accent focus ring with 4px offset.
Reduced-motion disables smooth scrolling and hover movement/transitions.
Keep table captions/scopes and all existing keyboard/clipboard behavior.
Check text contrast in both modes; do not use low-contrast brand colors as small
text on an incompatible surface.

Build with the repository's existing tool. Check home and one guide/reference
page at `1440`, `1024`, `768`, `390`, and `320` CSS-pixel widths, plus dark mode.
Capture desktop/mobile screenshots; assert no document horizontal overflow,
panel beside copy above 1000px and below it at/below 1000px, visible non-none
panel shadow, correct model mark, no overlapping badges, no broken local links.
Use browser-computed styles/geometry, not CSS source alone, as layout evidence.
Keep generated output, browser scripts, screenshots and dependency lockfiles
out of the change unless already tracked by that repository.
