import { useEffect, useState } from "react";
import { useServerFn } from "@tanstack/react-start";
import { useNavigate, useRouterState } from "@tanstack/react-router";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Lock, ShieldCheck, AlertCircle, Loader2 } from "lucide-react";
import { mfaStatus, mfaVerify, mfaVerifyBackupCode } from "@/lib/mfa.functions";


export function MfaGate({ children }: { children: React.ReactNode }) {
  const status = useServerFn(mfaStatus);
  const verify = useServerFn(mfaVerify);
  const verifyBackup = useServerFn(mfaVerifyBackupCode);
  const navigate = useNavigate();
  const path = useRouterState({ select: (s) => s.location.pathname });
  const [state, setState] = useState<{
    loading: boolean;
    enrolled: boolean;
    valid: boolean;
    exempt: boolean;
  }>({ loading: true, enrolled: false, valid: false, exempt: false });
  const [code, setCode] = useState("");
  const [useBackup, setUseBackup] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const onEnrollPage = path.startsWith("/mfa/");

  useEffect(() => {
    let alive = true;
    status()
      .then((r) => {
        if (!alive) return;
        setState({
          loading: false,
          enrolled: r.enrolled,
          valid: r.sessionValid,
          exempt: !!(r as { exempt?: boolean }).exempt,
        });
      })
      .catch(
        () =>
          alive &&
          setState({ loading: false, enrolled: false, valid: true, exempt: true }),
      );
    return () => {
      alive = false;
    };
  }, [status, path]);

  // If not enrolled and not already on enroll page → redirect
  useEffect(() => {
    if (state.loading) return;
    if (state.exempt) return;
    if (!state.enrolled && !onEnrollPage) {
      navigate({ to: "/mfa/enroll" });
    }
  }, [state, onEnrollPage, navigate]);

  async function onSubmit() {
    setBusy(true);
    setError(null);
    try {
      if (useBackup) {
        await verifyBackup({ data: { code } });
      } else {
        await verify({ data: { code } });
      }
      setState((s) => ({ ...s, valid: true }));
      setCode("");
    } catch (e) {
      setError(String((e as Error).message ?? e));
    } finally {
      setBusy(false);
    }
  }

  if (state.loading) return null;

  // Super admin exempté du MFA conformément aux spécifications.
  if (state.exempt) return <>{children}</>;

  // Not enrolled and on enroll page → let user enroll
  if (!state.enrolled) {
    if (onEnrollPage) return <>{children}</>;
    return null;
  }

  // Enrolled but session not validated → block with modal
  if (!state.valid) {
    return (
      <>
        {children}
        <Dialog open>
          <DialogContent
            onEscapeKeyDown={(e) => e.preventDefault()}
            onPointerDownOutside={(e) => e.preventDefault()}
            onInteractOutside={(e) => e.preventDefault()}
          >
            <DialogHeader>
              <DialogTitle>Vérification à deux facteurs</DialogTitle>
            </DialogHeader>
            <div className="space-y-4">
              <p className="text-sm text-muted-foreground">
                {useBackup
                  ? "Saisissez l'un de vos codes de secours."
                  : "Ouvrez votre application authenticator et saisissez le code à 6 chiffres."}
              </p>
              <div className="space-y-2">
                <Label htmlFor="mfa-code">{useBackup ? "Code de secours" : "Code"}</Label>
                <Input
                  id="mfa-code"
                  autoFocus
                  value={code}
                  maxLength={useBackup ? 20 : 6}
                  onChange={(e) =>
                    setCode(
                      useBackup
                        ? e.target.value.toUpperCase()
                        : e.target.value.replace(/\D/g, ""),
                    )
                  }
                  placeholder={useBackup ? "XXXXXXXXXX" : "123456"}
                />
              </div>
              {error && (
                <Alert variant="destructive">
                  <AlertDescription>{error}</AlertDescription>
                </Alert>
              )}
              <div className="flex gap-2">
                <Button
                  onClick={onSubmit}
                  disabled={busy || code.length < (useBackup ? 6 : 6)}
                  className="flex-1"
                >
                  {busy ? "Vérification…" : "Valider"}
                </Button>
              </div>
              <button
                type="button"
                className="text-xs text-muted-foreground underline w-full text-center"
                onClick={() => {
                  setUseBackup((b) => !b);
                  setCode("");
                  setError(null);
                }}
              >
                {useBackup ? "Utiliser mon application" : "Utiliser un code de secours"}
              </button>
            </div>
          </DialogContent>
        </Dialog>
      </>
    );
  }

  return <>{children}</>;
}