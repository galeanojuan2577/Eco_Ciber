# GSAP Core Best Practices

## Performance Optimization

- **Hardware Acceleration**: Always animate properties that don't trigger layout (reflow).
  - ✅ Use: `x`, `y`, `rotation`, `scale`, `skewX`, `skewY`.
  - ❌ Avoid: `top`, `left`, `width`, `height`, `margin`.
- **autoAlpha**: Use `autoAlpha: 0` instead of `opacity: 0`. It sets `visibility: hidden` when opacity hits 0, improving performance and preventing accidental clicks on hidden elements.
- **Force 3D**: Use `force3D: true` for elements that need extra smoothness (GPU acceleration).

## Syntax & Selection

- **Selector Strings**: GSAP uses `document.querySelectorAll()` internally. You can pass ".class" or "#id" directly.
- **Staggers**: Use the `stagger` property for sequential animations of multiple elements.
  ```javascript
  gsap.from(".box", {
    y: 100,
    stagger: 0.1,
    ease: "back.out"
  });
  ```

## Easing

- **Standard**: `power1`, `power2`, `power3`, `power4`.
- **Specialized**: `back`, `elastic`, `bounce`, `slow`, `expo`, `sine`, `circ`.
- **Default**: `power2.out` is the most natural-feeling default.

## Position Parameter

The secret to great timelines is the position parameter:
- `"+=1"`: Wait 1 second after the previous tween.
- `"-=1"`: Start 1 second before the previous tween ends.
- `"<"`: Start at the same time as the previous tween.
- `">"`: Start at the end of the previous tween.
- `"label"`: Start at a specific label.
