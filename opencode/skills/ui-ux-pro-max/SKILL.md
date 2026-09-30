---
name: ui-ux-pro-max
description: Professional UI/UX transformation for modern web applications. Use when upgrading visual aesthetics with Framer Motion, modern backgrounds, and high-end design patterns.
---

# UI/UX Pro Max: Professional Web Transformation (v2.0 Theme Engine)

Transform generic web interfaces into impressive, high-end professional applications using Framer Motion and modern design patterns.

## Design Systems
- **LegalTech Pro**: Use for projects requiring authority, trust, and precision. Refer to [references/legal-tech-pro.md](references/legal-tech-pro.md) for full specifications.

## Visual Components
- **Backgrounds**: Implement structural and atmospheric layers using templates in [assets/BackgroundComponents.tsx](assets/BackgroundComponents.tsx). Use Grid for data-dense areas and Dot patterns for dark mode/premium sections.
- **Animations**: Use spring-based transitions to maintain a "physical" and responsive feel. Refer to [scripts/framer-motion-presets.cjs](scripts/framer-motion-presets.cjs) for reusable variants.

## 🆕 Theme Engine & Dynamic Constraints (v2.0)
Esta skill ahora integra un motor de temas automático y estado dinámico.

### Auto-Layout Engine
1. **Análisis de Densidad:** Detectar si la vista es:
   - **Data-Dense:** Si hay tablas, listas largas, o formularios complejos -> sugerir Grid Background + Tipografía sans-serif.
   - **Visual-First:** Si hay imágenes, hero sections, o espacios amplios -> sugerir Aurora/Radial Glows + Tipografía serif para títulos.
2. **Selección Automática:** Aplicar el template visual recomendado y justificarlo.

### Dynamic Theme Contract (v2.0)
Si existe un archivo `theme.json` o `tailwind.config.ts`:
- **Adaptar automáticamente** los componentes generados a la paleta de colores y espaciado definido.
- Si no existe: generar un `theme.json` base basado en el tipo de proyecto (Legal, SaaS, e-Commerce).

### Accessibility & Motion Preferences
- **`prefers-reduced-motion`:** Si el usuario (o el sistema operativo) indica que prefiere menos movimiento, las animaciones deben degradarse a transiciones sencillas de `opacity` y omitir springs complejos.
- **`prefers-color-scheme`:** Si no hay tema definido manualmente, preferir `dark` o `light` según el sistema.

## Professional Workflow
1. **Analyze Structure**: Identify core data blocks (Bento Grid) and navigation flows.
2. **Atmosphere Setup**: Apply a base structural background (Grid/Dot) with soft radial glows (Aurora) in corners.
3. **Typography Upgrade**: Pair a serif heading with a clean sans-serif body to convey authority and modern technicality.
4. **Motion Enhancement**: Apply Framer Motion to all layout changes, entrances, and micro-interactions. Ensure transitions are under 300ms.
5. **Interactive Feedback**: Use subtle hover scales and layout transitions to maintain user context.

## Design Constraints
- **Color**: Avoid "AI purple" gradients. Use Deep Navy, Slate Gray, and Professional Blue.
- **Speed**: Animations must feel efficient, not bouncy. Use high damping (30+).
- **Icons**: Use minimal SVG icons (Lucide/Heroicons) only.

## 🏛️ Mandatos de Diseño Judicial (GMA Dynamics)
- **Atmósfera de Autoridad**: En vistas públicas de notificación, usar fondos neutros (`#f1f5f9`), tipografía sans-serif de alto contraste y componentes con bordes suavizados pero definidos (`borderRadius: 24px+`).
- **Transparencia Funcional**: Los estados de carga deben ser explícitos y solemnes (ej: "Verificando Identidad Judicial...").
- **Jerarquía de Advertencia**: Las alertas legales deben usar contrastes de naranja/ámbar sobre blanco para denotar precaución sin causar pánico visual.
- **Actas Judiciales**: El diseño de certificados debe emular el papel físico (fuentes serif, marcas de agua, firmas electrónicas) para proyectar validez oficial.

## 📊 Registro de Rendimiento Visual
Para cada componente generado, evaluar:
- **Lighthouse Performance Score** objetivo: >90
- **CLS (Cumulative Layout Shift):** <0.1
- **FCP (First Contentful Paint):** <1.5s

Registrar estos targets y los resultados prácticos (si se miden) en `/tmp/opencode/skills/learning-logs/ui-ux-pro-max/`.
Los entries deben incluir tipo de imagen: hero, background, icon, o thumbnail.

## 🧠 Learning Loop (Auto-Mejora)
Si un diseño generado recibe retroalimentación negativa del usuario o falla en métricas de accesibilidad:
1. **Identificar:** ¿Es un problema de color (contraste), movimiento (motion sickness), o layout (responsiveness)?
2. **Documentar:** Añadir al learning log el tipo de error y la solución.
3. **Ajustar:** Asegurar que la próxima vez que se genere un componente similar, se validen automáticamente: bajo `prefers-reduced-motion` y contraste `WCAG 2.1 AA`.

### Procedimiento de Auto-Mejora
1. **Trigger:** Feedback negativo o falla en Lighthouse/axe.
2. **RCA:** ¿Es contraste, animación, o responsive?
3. **Documentar:** Guardar en `/tmp/opencode/skills/learning-logs/ui-ux-pro-max/{YYYY-MM-DD}_{timestamp}_ux_issue.md`.
4. **Aprender:** Si un tipo de error se repite 2 veces, añadir `Guardia de UX`: validar automáticamente antes de entregar.