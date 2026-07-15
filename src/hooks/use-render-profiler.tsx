import {
  Profiler,
  useCallback,
  useRef,
  type ProfilerOnRenderCallback,
  type ReactNode,
} from "react";

type Sample = {
  id: string;
  phase: "mount" | "update" | "nested-update";
  actualDuration: number;
  baseDuration: number;
  ts: number;
};

const buffer: Sample[] = [];
const MAX = 200;

function isEnabled(): boolean {
  if (import.meta.env.DEV) return true;
  if (typeof window === "undefined") return false;
  try {
    return window.localStorage.getItem("perfProfiler") === "1";
  } catch {
    return false;
  }
}

/**
 * Wrap une page ou une section pour mesurer son coût de rendu React.
 * Activé automatiquement en dev, ou en prod si l'utilisateur définit
 * localStorage.perfProfiler = '1' (console admin).
 *
 * Les échantillons sont bufferisés en mémoire et exposés via
 * `window.__perfSamples` pour lecture par la page /admin/perf.
 */
export function RenderProfiler({ id, children }: { id: string; children: ReactNode }) {
  const enabled = useRef(isEnabled()).current;
  const onRender = useCallback<ProfilerOnRenderCallback>(
    (profId, phase, actualDuration, baseDuration) => {
      if (actualDuration < 1) return; // ignorer bruit
      buffer.push({
        id: profId,
        phase: phase as Sample["phase"],
        actualDuration,
        baseDuration,
        ts: Date.now(),
      });
      if (buffer.length > MAX) buffer.splice(0, buffer.length - MAX);
      if (typeof window !== "undefined") {
        (window as unknown as { __perfSamples: Sample[] }).__perfSamples = buffer;
      }
    },
    [],
  );
  if (!enabled) return <>{children}</>;
  return (
    <Profiler id={id} onRender={onRender}>
      {children}
    </Profiler>
  );
}

export function getPerfSamples(): Sample[] {
  return [...buffer];
}

export function clearPerfSamples(): void {
  buffer.length = 0;
}
