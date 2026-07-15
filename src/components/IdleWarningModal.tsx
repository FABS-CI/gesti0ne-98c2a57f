import { AlertTriangle } from "lucide-react";

export function IdleWarningModal({
  countdown,
  onExtend,
  onLogout,
}: {
  countdown: number;
  onExtend: () => void;
  onLogout: () => void;
}) {
  const minutes = Math.floor(countdown / 60);
  const seconds = String(countdown % 60).padStart(2, "0");

  return (
    <div
      className="fixed inset-0 z-[200] flex items-center justify-center bg-black/50 p-4"
      role="dialog"
      aria-modal="true"
    >
      <div className="w-full max-w-md rounded-2xl bg-card p-6 text-center shadow-2xl">
        <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-orange-100">
          <AlertTriangle className="h-7 w-7 text-orange-600" />
        </div>
        <h2 className="text-lg font-bold text-foreground">Session sur le point d'expirer</h2>
        <p className="mt-2 text-sm text-muted-foreground">
          Inactivité détectée. Déconnexion automatique dans :
        </p>
        <div className="my-5 text-4xl font-black tabular-nums text-orange-600">
          {minutes}:{seconds}
        </div>
        <div className="flex gap-3">
          <button
            onClick={onLogout}
            className="flex-1 rounded-lg border border-border px-4 py-2.5 text-sm font-semibold text-foreground hover:bg-muted"
          >
            Se déconnecter
          </button>
          <button
            onClick={onExtend}
            className="flex-1 rounded-lg bg-orange-600 px-4 py-2.5 text-sm font-semibold text-white hover:brightness-110"
          >
            Rester connecté
          </button>
        </div>
      </div>
    </div>
  );
}
