---
name: web-front-animation-engine
description: Central de recursos front-end y animaciones web: Motion Primitives, getdesign.md, Unicorn Studio, MotionSites.ai. Estilos únicos, componentes animados, WebGL sin código.
---

# Web Front Animation Engine

Central de recursos para construir frontends con estilos únicos y animaciones profesionales. Integra Motion Primitives (OS), getdesign.md (300+ DESIGN.md), Unicorn Studio (WebGL no-code) y MotionSites.ai (secciones animadas).

## When to Use

- Landing page con animaciones de alto impacto
- Diseño con identidad visual única (usando DESIGN.md)
- Necesidad de WebGL/3D interactivo sin código
- Componentes animados listos para copiar
- Secciones hero animadas con prompts AI

## Árbol de Decisión

```
¿Qué necesitas?
│
├── Componentes UI animados → Motion Primitives
│   (text effects, staggered reveals, animated cards)
│
├── Identidad visual única → getdesign.md
│   (paletas, tipografías, spacing de Apple, Stripe, Linear...)
│
├── WebGL/3D interactivo → Unicorn Studio
│   (partículas, morphing, ondas 3D sin código)
│
├── Hero sections animadas → MotionSites.ai
│   (prompts AI ready-to-copy)
│
└── Animaciones complejas GSAP → gsap-expert skill
    (scroll-triggered, timeline, morphing SVG)
```

## Motion Primitives

Repositorio: https://github.com/ibelick/motion-primitives
Licencia: MIT (Open Source)
Stack: React + Framer Motion + Tailwind

Componentes disponibles:
- Text Effects (scramble, reveal, gradient)
- Staggered containers
- Animated cards
- Hover effects
- Scroll reveals

Uso: copy-paste directo. Ver `references/motion-primitives.md`.

## getdesign.md

Sitio: https://getdesign.md/
300+ DESIGN.md analyses de marcas reales (Apple, Stripe, Linear, Vercel, Supabase...).

Formato: colors + typography + spacing + components + design rationale.

Uso: elegir un DESIGN.md que coincida con el tono deseado y pasarlo como referencia de diseño al agente de código.

Workflow completo en `references/getdesign-workflow.md`.

## Unicorn Studio

Sitio: https://www.unicorn.studio/
WebGL no-code: crear assets de movimiento interactivo en minutos.

Exporta a: Framer, Webflow, Wix, Figma Sites, o HTML directo.

Uso en proyectos: embed como iframe o exportar como WebGL component.

Guía en `references/unicorn-studio.md`.

## MotionSites.ai

Sitio: https://motionsites.ai/
Biblioteca de secciones animadas con prompts AI.

Categorías: Hero sections, Backgrounds, Landing Pages, Apps.
Tiene items gratuitos ("Copy") y premium.

Uso: inspeccionar la sección deseada, copiar el prompt, adaptar al proyecto.

Guía en `references/motionsites-prompts.md`.

## Flujo de Trabajo

1. **DEFINIR** identidad visual → getdesign.md (elegir DESIGN.md de referencia)
2. **ESTRUCTURAR** layout → shadcn/ui + Tailwind (desde web-developer-engine)
3. **ANIMAR** componentes → Motion Primitives / GSAP según necesidad
4. **ELEVAR** secciones clave → Unicorn Studio (WebGL) / MotionSites.ai (hero prompts)
5. **AUDITAR** seguridad + rendimiento → web-developer-engine + Chrome DevTools MCP
