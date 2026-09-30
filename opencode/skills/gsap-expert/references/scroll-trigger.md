# ScrollTrigger & Observer

## Basic ScrollTrigger

```javascript
gsap.registerPlugin(ScrollTrigger);

gsap.to(".box", {
  scrollTrigger: {
    trigger: ".box",
    start: "top 80%", // top of trigger hits 80% of viewport
    end: "top 20%",
    scrub: true, // link animation progress to scroll position
    pin: true, // pin the element while animating
    markers: false // set to true during development
  },
  x: 500
});
```

## Advanced Patterns

### Horizontal Scroll Section
Use `xPercent: -100 * (sections.length - 1)` with `pin: true` and `scrub: 1`.

### Parallax Effects
```javascript
gsap.to(".bg", {
  yPercent: -20,
  ease: "none",
  scrollTrigger: {
    trigger: ".container",
    scrub: true
  }
});
```

### Reveal on Scroll (Batch)
```javascript
ScrollTrigger.batch(".reveal", {
  onEnter: batch => gsap.to(batch, { autoAlpha: 1, y: 0, stagger: 0.15 })
});
```

## Observer Plugin
Use for "scroll-jacking" or custom touch/wheel interactions where you need to detect intent rather than actual scroll position.
