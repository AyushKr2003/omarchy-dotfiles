class EventEmitter {
  constructor() {
    this.listeners = new Map();
  }

  on(event, callback) {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, []);
    }
    this.listeners.get(event).push(callback);
    return this;
  }

  off(event, callback) {
    const callbacks = this.listeners.get(event);
    if (!callbacks) return this;
    this.listeners.set(
      event,
      callbacks.filter((cb) => cb !== callback)
    );
    return this;
  }

  emit(event, ...args) {
    const callbacks = this.listeners.get(event);
    if (!callbacks) return false;
    callbacks.forEach((callback) => callback(...args));
    return true;
  }

  once(event, callback) {
    const wrapper = (...args) => {
      callback(...args);
      this.off(event, wrapper);
    };
    return this.on(event, wrapper);
  }
}
