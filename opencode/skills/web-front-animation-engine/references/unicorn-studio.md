# Unicorn Studio — WebGL No-Code

Sitio: https://www.unicorn.studio/
Crea assets de movimiento interactivo 3D/WebGL sin escribir código.

## Qué Ofrece

- Partículas animadas
- Morphing 3D
- Ondas interactivas
- Fondos dinámicos
- Efectos de cursor
- Transiciones de escena

## Integración en Proyectos Web

### 1. Exportar desde Unicorn Studio
El asset se exporta como:
- HTML standalone
- Iframe embed code
- WebGL component
- Framer code
- Webflow embed

### 2. Embed directo
```html
<iframe
  src="https://unicorn.studio/embed/your-asset-id"
  width="100%"
  height="500"
  frameborder="0"
  allow="autoplay"
></iframe>
```

### 3. Como componente React
```tsx
export function UnicornBackground() {
  return (
    <div className="absolute inset-0 -z-10">
      <iframe
        src="https://unicorn.studio/embed/your-asset-id"
        className="w-full h-full"
        style={{ border: 'none', pointerEvents: 'none' }}
        title="Interactive background"
        loading="lazy"
      />
    </div>
  )
}
```

## Buenas Prácticas

- **Lazy loading**: `loading="lazy"` en el iframe
- **Responsive**: width 100%, height define ratio
- **Fallback**: mostrar un fondo estático mientras carga
- **Performance**: limitar a 1-2 assets WebGL por página
- **Mobile**: probar que no degrade rendimiento en dispositivos

## Alternativas Open Source

Si no se necesita la plataforma no-code:
- Three.js + react-three-fiber (código)
- Spline (similar, editor visual)
- LottieFiles (animaciones vectoriales)

## Cuándo Usar Unicorn Studio

| Situación | Recomendado |
|-----------|------------|
| Hero con partículas 3D | ✅ Sí |
| Fondo interactivo | ✅ Sí |
| Animación compleja sin dev | ✅ Sí |
| Micro-interacción simple | ❌ Mejor Motion Primitives |
| Animación scroll-driven | ❌ Mejor GSAP |
