# Animation Decision Tree

```
¿Qué tipo de animación necesitas?
│
├── ENTRADA / SALIDA de componentes
│   ├── Simple (fade, slide) → Motion Primitives / Framer Motion
│   └── Con secuencia → staggerChildren (Framer Motion)
│
├── TEXTO animado
│   ├── Character reveal → Motion Primitives TextEffect
│   └── Typewriter / scramble → GSAP SplitText
│
├── SCROLL
│   ├── Reveal al hacer scroll → IntersectionObserver + Framer Motion
│   └── Narrativa / parallax → GSAP ScrollTrigger
│
├── 3D / WEBGL
│   ├── Sin código → Unicorn Studio (embed)
│   └── Con código → Three.js / react-three-fiber
│
├── HERO section
│   ├── Inspiración rápida → MotionSites.ai (prompts)
│   └── Custom → Framer Motion + Tailwind
│
├── HOVER / MICRO-INTERACCIÓN
│   └── Framer Motion (whileHover, whileTap)
│
├── TIMELINE compleja
│   └── GSAP TimelineMax
│
├── SVG / MORPHING
│   └── GSAP MorphSVG (plugin)
│
├── ÍCONOS animados
│   └── LottieFiles / lucide-react
│
└── LOADING / SKELETON
    └── Tailwind animate-pulse / Framer Motion
```

## Reglas de Rendimiento

| Técnica | Impacto | Bundle |
|---------|---------|--------|
| CSS transitions | ✅ Mínimo | 0KB |
| Framer Motion | ✅ Bueno | ~15KB |
| Motion Primitives | ✅ Bueno | ~5KB |
| GSAP (core) | ⚠️ Moderado | ~15KB |
| GSAP + plugins | ⚠️ Moderado | ~30KB+ |
| Three.js / WebGL | 🔴 Alto | ~100KB+ |

## Detección Automática de Contexto

| Tipo de Proyecto | Animación Recomendada |
|-----------------|----------------------|
| SaaS / Dashboard | Framer Motion (entradas sutiles) |
| Landing page | Motion Primitives + GSAP ScrollTrigger |
| Portfolio | GSAP (narrativo) + Unicorn Studio (hero) |
| E-commerce | Framer Motion (hover cards) + Lottie |
| Mobile-first | CSS transitions (mínimo JS) |
