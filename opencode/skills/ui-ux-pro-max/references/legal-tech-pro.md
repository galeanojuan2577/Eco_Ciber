# LegalTech Pro: Professional UI/UX Design System

## Design Philosophy
Balance traditional legal authority with modern digital efficiency. The UI must feel "stable," "precise," and "exclusive."

## Typography
- **Headings**: Cormorant Garamond (Serif) - Evokes tradition, law, and history.
- **Body**: Inter or Montserrat (Sans-serif) - Modern, readable, and technical.

## Color Palette
- **Primary**: Deep Navy (#0F172A) - Authority and trust.
- **Secondary**: Slate Gray (#64748B) - Neutrality and professional context.
- **Accent**: Gold (#D4AF37) or Professional Blue (#3B82F6) - Actions and highlights.
- **Background**: Soft Grid / Dotted Surface with very low opacity (5%).

## Layout Patterns
- **Bento Grid**: For dashboard data visualization.
- **Swiss Minimalism**: For landing pages and document lists.
- **Progressive Disclosure**: Hide complexity until needed via layout transitions.

## Animation Guidelines (Framer Motion)
- **Philosophy**: Functional, not decorative.
- **Presets**:
  - `Standard`: { type: "spring", stiffness: 300, damping: 30 }
  - `SmoothReveal`: { opacity: [0, 1], y: [20, 0], transition: { duration: 0.5, ease: "easeOut" } }
  - `Layout`: Use `layout` prop for all container size changes.

## Background Styles
- **Structural**: Subtle Grid or Dot patterns.
- **Atmospheric**: Low opacity (5-10%) Radial Glows or Aurora effects in corners.
- **Dynamic**: Slow, tracing background beams for primary CTAs.
