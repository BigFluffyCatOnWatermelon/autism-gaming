/* Bridge between the web workspace and the Godot Web Object Builder host. */
(() => {
  "use strict";

  const CHANNEL = "object-builder";
  const listeners = new Map();
  const pending = new Map();
  let requestSequence = 0;
  const embedded = typeof window.ipc === "object" &&
    window.ipc !== null &&
    typeof window.ipc.postMessage === "function";

  function normalizeMessage(value) {
    if (typeof value !== "string") return value;
    try { return JSON.parse(value); }
    catch (_error) { return null; }
  }

  function receive(event) {
    const detail = event && (event.detail ?? event.data);
    const message = normalizeMessage(detail);
    if (!message || typeof message !== "object" || message.channel !== CHANNEL) return;

    if (message.type === "response") {
      const responsePayload = message.payload || {};
      const requestId = String(responsePayload.request_id || "");
      const entry = pending.get(requestId);
      if (entry) {
        pending.delete(requestId);
        window.clearTimeout(entry.timer);
        const result = responsePayload.result || {};
        if (result.ok === false) entry.reject(new Error(result.error || "Godot backend rejected the request."));
        else entry.resolve(result);
      }
    }

    const handlers = listeners.get(String(message.type || ""));
    if (handlers) {
      for (const handler of [...handlers]) {
        try { handler(message.payload ?? {}, message); }
        catch (error) { console.error("[WebObjectBuilderHost] Message handler failed:", error); }
      }
    }

    window.dispatchEvent(new CustomEvent("object-builder:host-message", { detail: message }));
  }

  document.addEventListener("message", receive);
  window.addEventListener("message", receive);

  function send(type, payload = {}, requestId = "") {
    if (!embedded || typeof type !== "string" || !type.trim()) return false;
    try {
      const message = {
        channel: CHANNEL,
        type,
        payload,
        source: "web"
      };
      if (requestId) message.request_id = requestId;
      window.ipc.postMessage(JSON.stringify(message));
      return true;
    } catch (error) {
      console.error("[WebObjectBuilderHost] Could not send:", error);
      return false;
    }
  }

  window.ObjectBuilderHost = Object.freeze({
    isEmbedded: embedded,
    send,

    request(type, payload = {}, timeoutMs = 20000) {
      if (!embedded) return Promise.reject(new Error("Запусти Web Object Builder внутри Godot."));
      const requestId = "web-" + (++requestSequence) + "-" + Date.now().toString(36);
      return new Promise((resolve, reject) => {
        const timer = window.setTimeout(() => {
          pending.delete(requestId);
          reject(new Error("Godot не ответил на запрос: " + type));
        }, timeoutMs);
        pending.set(requestId, { resolve, reject, timer });
        if (!send(type, payload, requestId)) {
          window.clearTimeout(timer);
          pending.delete(requestId);
          reject(new Error("Не удалось отправить запрос в Godot."));
        }
      });
    },

    on(type, handler) {
      if (typeof type !== "string" || typeof handler !== "function") {
        throw new TypeError("ObjectBuilderHost.on expects a message type and a handler");
      }
      if (!listeners.has(type)) listeners.set(type, new Set());
      listeners.get(type).add(handler);
      return () => {
        const handlers = listeners.get(type);
        if (!handlers) return;
        handlers.delete(handler);
        if (handlers.size === 0) listeners.delete(type);
      };
    }
  });

  window.dispatchEvent(new CustomEvent("object-builder:host-ready", {
    detail: { embedded }
  }));
})();
