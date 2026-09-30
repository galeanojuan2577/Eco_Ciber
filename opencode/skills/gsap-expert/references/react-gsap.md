# GSAP in React & Next.js

## The `useGSAP()` Hook

The official GSAP hook for React handles scope and cleanup automatically.

```javascript
import { useRef } from 'react';
import gsap from 'gsap';
import { useGSAP } from '@gsap/react';

gsap.registerPlugin(useGSAP);

const MyComponent = () => {
  const container = useRef();

  useGSAP(() => {
    // GSAP code here
    gsap.to(".box", { rotation: 360 });
  }, { scope: container }); // Scoping prevents targeting outside the component

  return (
    <div ref={container}>
      <div className="box">Rotate me</div>
    </div>
  );
};
```

## Why `useGSAP()`?

1. **Automatic Cleanup**: Reverts animations when the component unmounts.
2. **Scoping**: Makes `gsap.to(".box")` only look for `.box` inside your component's ref.
3. **Wait for Render**: Ensures the DOM is ready before animating.

## Next.js (SSR) Considerations

- Always register plugins inside a `useEffect` or `useLayoutEffect` (or let `useGSAP` handle it).
- For `ScrollTrigger`, you might need `ScrollTrigger.refresh()` after dynamic content loads.
- Check for `window` availability if using GSAP outside of hooks.
