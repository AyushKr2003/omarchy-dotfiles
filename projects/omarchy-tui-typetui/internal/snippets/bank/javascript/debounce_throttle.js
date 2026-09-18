function debounce(fn, delay) {
  let timeoutId = null;

  return function debounced(...args) {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => {
      fn.apply(this, args);
    }, delay);
  };
}

function throttle(fn, limit) {
  let inThrottle = false;

  return function throttled(...args) {
    if (!inThrottle) {
      fn.apply(this, args);
      inThrottle = true;
      setTimeout(() => {
        inThrottle = false;
      }, limit);
    }
  };
}

const handleResize = debounce(() => {
  console.log("window resized:", window.innerWidth);
}, 200);

window.addEventListener("resize", handleResize);
