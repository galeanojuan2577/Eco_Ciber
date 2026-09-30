# Motion Primitives — Referencia

Repositorio: https://github.com/ibelick/motion-primitives
Licencia: MIT
Stack: React + Framer Motion + Tailwind CSS

## Instalación

No requiere instalación de paquete. Es copy-paste.

Cada componente se copia directamente desde la documentación:
https://motion-primitives.com/docs

## Componentes Principales

### Text Effects
```tsx
'use client'
import { TextEffect } from '@/components/ui/text-effect'

export function HeroTitle() {
  return (
    <TextEffect per="char" preset="fade">
      Build Beautiful Interfaces
    </TextEffect>
  )
}
```

### Staggered Reveal
```tsx
'use client'
import { Staggered } from '@/components/ui/staggered'

export function FeatureList({ items }: { items: string[] }) {
  return (
    <Staggered>
      {items.map((item) => (
        <div key={item}>{item}</div>
      ))}
    </Staggered>
  )
}
```

### Scroll Reveal
```tsx
'use client'
import { useState, useRef, useEffect } from 'react'
import { motion } from 'motion/react'

export function ScrollReveal({ children }: { children: React.ReactNode }) {
  const ref = useRef(null)
  const [isVisible, setIsVisible] = useState(false)

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) setIsVisible(true) },
      { threshold: 0.1 }
    )
    if (ref.current) observer.observe(ref.current)
    return () => observer.disconnect()
  }, [])

  return (
    <motion.div
      ref={ref}
      initial={{ opacity: 0, y: 40 }}
      animate={isVisible ? { opacity: 1, y: 0 } : {}}
      transition={{ duration: 0.6, ease: 'easeOut' }}
    >
      {children}
    </motion.div>
  )
}
```

## Cuándo Usar

| Necesidad | Motion Primitives | GSAP |
|-----------|------------------|------|
| Texto animado | ✅ TextEffect | ✅ SplitText (plugin) |
| Scroll reveals | ✅ ScrollReveal | ✅ ScrollTrigger |
| Timeline compleja | ❌ | ✅ TimelineMax |
| SVG morphing | ❌ | ✅ MorphSVG |
| Rendimiento en React | ✅ Nativo | ⚠️ useGSAP hook |
| Bundle size | ~5KB | ~30KB (con plugins) |

## Mejores Prácticas

- Preferir Motion Primitives para UI animations (entradas, hover, transiciones)
- Usar GSAP para animaciones narrativas/scroll-intensive
- No mezclar Framer Motion y GSAP en el mismo elemento
- Envolver en `'use client'` para Next.js App Router
