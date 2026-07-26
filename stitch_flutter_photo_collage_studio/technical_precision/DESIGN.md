---
name: Technical Precision
colors:
  surface: '#131313'
  surface-dim: '#131313'
  surface-bright: '#393939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1c1b1b'
  surface-container: '#201f1f'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353534'
  on-surface: '#e5e2e1'
  on-surface-variant: '#c7c4d8'
  inverse-surface: '#e5e2e1'
  inverse-on-surface: '#313030'
  outline: '#918fa1'
  outline-variant: '#464555'
  surface-tint: '#c3c0ff'
  primary: '#c3c0ff'
  on-primary: '#1d00a5'
  primary-container: '#4f46e5'
  on-primary-container: '#dad7ff'
  inverse-primary: '#4d44e3'
  secondary: '#89ceff'
  on-secondary: '#00344d'
  secondary-container: '#00a2e6'
  on-secondary-container: '#00344e'
  tertiary: '#ffb695'
  on-tertiary: '#571f00'
  tertiary-container: '#a44100'
  on-tertiary-container: '#ffd2be'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e2dfff'
  primary-fixed-dim: '#c3c0ff'
  on-primary-fixed: '#0f0069'
  on-primary-fixed-variant: '#3323cc'
  secondary-fixed: '#c9e6ff'
  secondary-fixed-dim: '#89ceff'
  on-secondary-fixed: '#001e2f'
  on-secondary-fixed-variant: '#004c6e'
  tertiary-fixed: '#ffdbcc'
  tertiary-fixed-dim: '#ffb695'
  on-tertiary-fixed: '#351000'
  on-tertiary-fixed-variant: '#7b2f00'
  background: '#131313'
  on-background: '#e5e2e1'
  surface-variant: '#353534'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  title-sm:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-caps:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.05em
  code-sm:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 4px
  sidebar-width: 260px
  toolbar-height: 48px
  gutter: 16px
  margin-page: 24px
  workspace-padding: 40px
---

## Brand & Style
The design system is engineered for high-performance creative workflows on Linux desktop environments. It balances the utilitarian nature of a technical tool with the polished aesthetics of modern creative software. The personality is focused, efficient, and reliable.

The style leverages **Minimalism** with a **Corporate/Modern** backbone, utilizing structural clarity to minimize cognitive load. It features high-density information layouts, subtle tonal layering to define workspace hierarchy, and precise "White Border" accents that reference classical framing and architectural blueprints.

## Colors
The palette is rooted in a "Deep Linux" aesthetic, using a range of charcoals and slates to create a low-fatigue environment for long creative sessions. 

- **Primary (Indigo):** Used exclusively for high-intent actions, progress indicators, and active states.
- **Secondary (Cyan):** Reserved for system-level feedback and secondary data visualizations.
- **Neutral/Surface:** A tiered system of dark greys. The darkest values are reserved for the sidebar and global navigation to push content forward.
- **White Border:** A specific high-contrast token used for highlighting selected workspace elements or framing the primary editor canvas.

## Typography
The typography system prioritizes technical legibility. **Inter** is the primary workhorse, chosen for its excellent X-height and clarity at small sizes on varied Linux display drivers. 

**JetBrains Mono** is introduced for labels, metadata, and technical readouts to reinforce the "creative tool" aesthetic. All headers use tight letter-spacing for a modern, compact look. Labels are set in uppercase with slight tracking to ensure they remain distinct from body text.

## Layout & Spacing
The layout follows a **Fixed-Fluid Hybrid** model optimized for desktop viewports. 
- **Sidebar:** Fixed width (260px) on the left for navigation and toolsets.
- **Workspace:** A fluid, center-anchored area with dynamic padding to ensure the collage editor remains the focal point.
- **Grid:** A 12-column internal grid is used for template selection screens, while a 4px baseline shift ensures all technical components align perfectly.

For the collage editor, an 8-pt grid system governs the placement of elements, with 16px gutters between modular panels.

## Elevation & Depth
In this design system, depth is communicated through **Tonal Layers** rather than soft shadows, maintaining a crisp, "flat-plus" technical look.

- **Level 0 (Background):** The deepest slate, used for the main application backdrop.
- **Level 1 (Sidebar/Panels):** Slightly lighter slate with a 1px solid border (hex: #2D2E32) to define edges.
- **Level 2 (Cards/Menus):** Elevated via a subtle inner glow or a strictly defined 1px border. 
- **The "White Border" Frame:** A specialized elevation state reserved for the active workspace selection, utilizing a 2px solid white stroke to "lift" the element above the UI hierarchy without using drop shadows.

## Shapes
The shape language is "Soft-Technical." Elements use a subtle 4px (`0.25rem`) corner radius to feel modern but precise. Large components like workspace cards may use 8px (`0.5rem`) to appear more approachable. Buttons are never pill-shaped; they remain rectangular with soft corners to fit the structured grid.

## Components

### Buttons & Inputs
- **Primary Action:** Solid Indigo (#4F46E5) with white text. High-contrast.
- **Secondary Action:** Ghost style with a 1px slate border.
- **Input Fields:** Darker than the background surface, utilizing a 1px focus ring of the primary color.

### Sidebar & Navigation
- **Active State:** A vertical Indigo bar (4px width) on the left edge of the nav item, with a subtle background highlight.
- **Icons:** 20px optical size, linear style, 1.5px stroke weight.

### Cards & Templates
- **Template Cards:** Aspect-ratio locked containers with a 1px neutral border. 
- **Selection State:** On hover, the border brightens. On select, the "White Border" (2px) is applied.

### Progress & Status
- **Progress Bars:** Thin (4px) tracks. The background is a dark slate, and the fill is a vibrant gradient from Primary to Secondary.
- **Technical Readouts:** Use JetBrains Mono for all numerical data within the workspace.

### Workspace Canvas
- The workspace area should include a visible but subtle dot-grid background (8px intervals) to assist in creative alignment. Elements being dragged should show a semi-transparent "ghost" with the White Border applied.