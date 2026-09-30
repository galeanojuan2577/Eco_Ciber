# getdesign.md — DESIGN.md Workflow

Sitio: https://getdesign.md/
Catálogo: 300+ DESIGN.md analyses de marcas reales.

## Qué es DESIGN.md

Un archivo de referencia de diseño que contiene:
- Paleta de colores (primario, secundario, acento, neutro)
- Tipografía (headings, body, mono)
- Espaciado (márgenes, padding, grid)
- Componentes (buttons, cards, inputs, modals)
- Rationale de diseño (por qué se eligió cada cosa)

Sigue la especificación oficial de Google.

## Workflow para Proyectos Web

### Paso 1: Elegir Referencia
Navegar https://getdesign.md/design-md y buscar una marca cuyo tono coincida:

| Si el proyecto es... | Elegir DESIGN.md de... |
|---------------------|----------------------|
| SaaS / Tech | Linear, Vercel, Stripe, Supabase |
| E-commerce | Shopify, Nike, Apple |
| Landing page | Framer, Notion, Raycast |
| Fintech | Revolut, Coinbase, Stripe |
| AI / LLM | Claude, Cursor, ElevenLabs |
| Lujo | Lamborghini, Ferrari, Bugatti |
| Corporativo | IBM, Dell, Mastercard |

### Paso 2: Leer el DESIGN.md
Extraer los valores clave:
```yaml
colors:
  primary: "#..."
  secondary: "#..."
  accent: "#..."
  neutral: "#..."
typography:
  display: { family: "...", weight: 700, size: "..." }
  body: { family: "...", weight: 400, size: "..." }
spacing:
  unit: 4px
  grid: 8px
```

### Paso 3: Traducir a Tailwind
```ts
// tailwind.config.ts
export default {
  theme: {
    extend: {
      colors: {
        brand: { 50: '...', 500: '#...', 900: '...' },
      },
      fontFamily: {
        display: ['"..."', 'serif'],
        body: ['"..."', 'sans-serif'],
      },
    },
  },
}
```

### Paso 4: Generar theme.json
```json
{
  "brand": { "name": "Mi Proyecto", "audience": "tech" },
  "colors": { "primary": "...", "secondary": "...", "accent": "..." },
  "typography": { "headings": "...", "body": "..." }
}
```

Esto permite que las skills `ui-ux-pro-max` y `FullStack-Sentinel` detecten automáticamente el tema.

## Beneficios

- Consistencia visual entre páginas
- Diseño profesional sin ser diseñador
- Reutilizable: mismo DESIGN.md para todo el proyecto
- Los agentes AI generan código que respeta la identidad visual
