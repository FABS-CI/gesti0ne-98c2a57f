// Client-side error tracing with a per-session client ID and per-error IDs.
// Logs unhandled errors/rejections to the console with a stable prefix so a
// crashing page can be correlated with the server "x-request-id" shown on
// the fallback UI.

function newId(prefix: string): string {
  try {
    return `${prefix}_${crypto.randomUUID()}`;
  } catch {
    return `${prefix}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`;
  }
}

let clientSessionId: string | undefined;

export function getClientSessionId(): string {
  if (clientSessionId) return clientSessionId;
  if (typeof window === "undefined") return newId("cs");
  try {
    const stored = window.sessionStorage.getItem("client-session-id");
    if (stored) {
      clientSessionId = stored;
      return stored;
    }
    const fresh = newId("cs");
    window.sessionStorage.setItem("client-session-id", fresh);
    clientSessionId = fresh;
    return fresh;
  } catch {
    const fresh = newId("cs");
    clientSessionId = fresh;
    return fresh;
  }
}

export function newClientErrorId(): string {
  return newId("cerr");
}

export function readServerRequestId(): string | undefined {
  if (typeof document === "undefined") return undefined;
  const meta = document.querySelector('meta[name="x-request-id"]');
  return meta?.getAttribute("content") ?? undefined;
}

let installed = false;
export function installClientErrorTracing() {
  if (installed || typeof window === "undefined") return;
  installed = true;
  const session = getClientSessionId();
  window.addEventListener("error", (event) => {
    const id = newClientErrorId();
    // eslint-disable-next-line no-console
    console.error(
      `[client:${session}:${id}] ${window.location.pathname} onerror ->`,
      event.error ?? event.message,
    );
  });
  window.addEventListener("unhandledrejection", (event) => {
    const id = newClientErrorId();
    // eslint-disable-next-line no-console
    console.error(
      `[client:${session}:${id}] ${window.location.pathname} unhandledrejection ->`,
      event.reason,
    );
  });
}
