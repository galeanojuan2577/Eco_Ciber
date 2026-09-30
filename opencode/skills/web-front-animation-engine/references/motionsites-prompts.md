# MotionSites.ai — Prompts AI para Secciones Animadas

Sitio: https://motionsites.ai/
Biblioteca de secciones web animadas generadas con prompts AI.

## Qué Ofrece

- Hero sections animadas
- Landing pages completas
- Backgrounds animados
- Secciones SaaS, E-commerce, Portfolio
- Apps UI animadas

Cada asset tiene modo "Copy" (gratuito) o "Premium" (pago).

## Workflow

### Paso 1: Explorar
Ir a https://motionsites.ai/ y navegar por categorías:
- Sites → landing pages completas
- Apps → UI de aplicaciones
- Sections → heros, features, CTAs
- Backgrounds → fondos animados

### Paso 2: Seleccionar
Elegir un diseño que coincida con el tono del proyecto.
Los items "Copy" se pueden usar directamente.

### Paso 3: Copiar el Prompt
Cada sección tiene un prompt AI que la generó.
Usar ese prompt como base, adaptándolo al proyecto.

### Paso 4: Adaptar al Stack
```tsx
// Ejemplo: adaptar un hero prompt a Next.js + Tailwind
export function HeroSection() {
  return (
    <section className="relative min-h-screen flex items-center">
      <div className="container mx-auto px-4">
        <h1 className="text-5xl md:text-7xl font-bold">
          Título impactante
        </h1>
        <p className="text-xl mt-4">
          Descripción convincente
        </p>
      </div>
      {/* Fondo animado de Unicorn Studio o CSS */}
    </section>
  )
}
```

## Ejemplos de Uso

### Hero Section (paisajista, premium)
```tsx
'use client'
import { motion } from 'motion/react'

export function LuxuryHero() {
  return (
    <section className="relative h-screen bg-black text-white overflow-hidden">
      <div className="absolute inset-0 bg-gradient-to-br from-zinc-900 via-black to-zinc-800" />
      <motion.div
        initial={{ opacity: 0, y: 60 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 1, ease: 'easeOut' }}
        className="relative z-10 container mx-auto h-full flex flex-col justify-center px-4"
      >
        <h1 className="text-6xl md:text-8xl font-light tracking-tight">
          Elevate Your Vision
        </h1>
        <p className="text-zinc-400 text-xl mt-6 max-w-xl">
          Premium design for modern brands
        </p>
      </motion.div>
    </section>
  )
}
```

### Background Animado
```css
/* Animación CSS tipo "aurora" común en MotionSites */
@keyframes aurora {
  0%, 100% { transform: translate(0, 0) scale(1); }
  25% { transform: translate(10%, -10%) scale(1.1); }
  50% { transform: translate(-5%, 15%) scale(0.9); }
  75% { transform: translate(15%, 5%) scale(1.05); }
}

.aurora-bg {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  animation: aurora 20s ease-in-out infinite;
}
```

## Mejores Prácticas

- Usar como inspiración, no copiar exacto
- Adaptar los prompts AI al stack real del proyecto
- Preferir items "Copy" (gratis) para prototipos
- Invertir en items Premium solo para producción
- Combinar con getdesign.md para identidad visual consistente
