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
    required: boolean;
  }>({ loading: true, enrolled: false, valid: false, exempt: false, required: false });

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
        
        // La session est valide si :
        // 1. Le MFA n'est pas requis pour cet utilisateur
        // 2. OU si le MFA a déjà été validé pour cette session
        const isValid = !r.required || r.sessionValid;

        setState({
          loading: false,
          enrolled: r.enrolled,
          valid: isValid,
          exempt: !!r.isSuperAdmin,
          required: !!r.required,
        });
      })
      .catch(
        () =>
          alive &&
          setState({ loading: false, enrolled: false, valid: true, exempt: false, required: false }),
      );
    return () => {
      alive = false;
    };
  }, [status, path]);


  // If not enrolled and not already on enroll page → redirect
  useEffect(() => {
    if (state.loading) return;
    if (state.exempt) return;
    // Rediriger vers l'enrôlement uniquement si le MFA est requis
    if (!state.enrolled && !onEnrollPage && state.required) {
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
        <div className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm z-40 pointer-events-none" />
        <Dialog open>
          <DialogContent
            className="sm:max-w-md border-primary/20 shadow-2xl z-50"
            onEscapeKeyDown={(e) => e.preventDefault()}
            onPointerDownOutside={(e) => e.preventDefault()}
            onInteractOutside={(e) => e.preventDefault()}
          >
            <DialogHeader className="space-y-3 pb-4 border-b">
              <div className="flex items-center gap-3">
                <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center">
                  <Lock className="h-5 w-5 text-primary" />
                </div>
                <DialogTitle className="text-xl font-bold tracking-tight">
                  🔐 CODE DE VÉRIFICATION
                </DialogTitle>
              </div>
            </DialogHeader>

            <div className="space-y-6 pt-4">
              <div className="space-y-2">
                <p className="text-sm font-medium text-slate-700">
                  {useBackup
                    ? "Saisissez l'un de vos codes de secours à usage unique."
                    : "Saisissez le code à 6 chiffres affiché dans votre application d'authentification."}
                </p>
              </div>

              <div className="space-y-4">
                <div className="relative">
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
                    placeholder={useBackup ? "XXXXXXXXXX" : "[ _ _ _ _ _ _ ]"}
                    className={`h-14 text-center text-2xl font-bold tracking-[0.5em] placeholder:tracking-normal ${
                      useBackup ? "tracking-widest" : ""
                    }`}
                  />
                </div>

                {error && (
                  <Alert variant="destructive" className="py-2">
                    <AlertCircle className="h-4 w-4" />
                    <AlertDescription className="text-xs">{error}</AlertDescription>
                  </Alert>
                )}

                <Button
                  onClick={onSubmit}
                  disabled={busy || code.length < 6}
                  className="w-full h-12 text-lg font-bold bg-primary hover:bg-primary/90"
                >
                  {busy ? (
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  ) : (
                    <ShieldCheck className="mr-2 h-5 w-5" />
                  )}
                  VALIDER
                </Button>
              </div>

              <div className="pt-2 text-center">
                <button
                  type="button"
                  className="text-xs font-medium text-primary hover:underline"
                  onClick={() => {
                    setUseBackup((b) => !b);
                    setCode("");
                    setError(null);
                  }}
                >
                  {useBackup ? "Utiliser mon application" : "Problème avec votre application ? Utilisez un code de secours"}
                </button>
              </div>
            </div>
          </DialogContent>
        </Dialog>
      </>
    );
  }


  return <>{children}</>;
}