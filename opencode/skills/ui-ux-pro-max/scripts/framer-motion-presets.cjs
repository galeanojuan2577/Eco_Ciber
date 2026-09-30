/**
 * Professional Framer Motion Presets for LegalTech Pro
 */

export const transitions = {
  spring: {
    type: "spring",
    stiffness: 300,
    damping: 30
  },
  smooth: {
    type: "tween",
    ease: "easeInOut",
    duration: 0.3
  }
};

export const variants = {
  fadeInUp: {
    initial: { opacity: 0, y: 20 },
    animate: { opacity: 1, y: 0 },
    transition: transitions.spring
  },
  staggerContainer: {
    animate: {
      transition: {
        staggerChildren: 0.1
      }
    }
  },
  hoverScale: {
    whileHover: { scale: 1.02 },
    whileTap: { scale: 0.98 },
    transition: transitions.spring
  }
};
