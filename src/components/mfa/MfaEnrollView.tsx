import { useEffect, useMemo, useState } from "react";
import { useServerFn } from "@tanstack/react-start";
import { useNavigate } from "@tanstack/react-router";
import QRCode from "qrcode";
import { 
  Loader2, 
  ShieldCheck, 
  AlertTriangle, 
  Copy, 
  Download, 
  Printer, 
  Lock, 
  AlertCircle, 
  Check 
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { toast } from "sonner";
import { mfaEnrollStart, mfaEnrollConfirm } from "@/lib/mfa.functions";


export function MfaEnrollView({ targetUserId, targetUserLabel, onSuccess }: { targetUserId?: string, targetUserLabel?: string, onSuccess?: () => void }) {
  const start = useServerFn(mfaEnrollStart);
  const confirm = useServerFn(mfaEnrollConfirm);
  const navigate = useNavigate();
  const [step, setStep] = useState<"loading" | "scan" | "done">("loading");
  const [otpauth, setOtpauth] = useState("");
  const [secret, setSecret] = useState("");
  const [qr, setQr] = useState("");
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [backup, setBackup] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    setError(null);
    setStep("loading");
    
    console.log("DEBUG: MFA Start for", targetUserId);
    start({ data: { targetUserId } })
      .then(async (r) => {
        if (!active) return;
        console.log("DEBUG: MFA Start Success", r.secret);
        setOtpauth(r.otpauthUrl);
        setSecret(r.secret);
        setQr(await QRCode.toDataURL(r.otpauthUrl, { width: 240, margin: 1 }));
        setStep("scan");
      })
      .catch((e) => {
        if (!active) return;
        console.error("DEBUG: MFA Start Error:", e);
        setError(String(e?.message ?? "Erreur lors de la génération du MFA"));
        setStep("scan");
      });

    return () => { active = false; };
  }, [start, targetUserId]);

  const backupText = useMemo(() => backup.join("\n"), [backup]);

  async function onConfirm() {
    setBusy(true);
    setError(null);
    try {
      const r = await confirm({ data: { code, targetUserId } });
      setBackup(r.backupCodes);
      setStep("done");
      toast.success("MFA activé");
    } catch (e: any) {
      console.error("MFA Confirm Error:", e);
      let errorMsg = "Code de vérification incorrect";
      
      // Extraction du message d'erreur pour TanStack ServerFn
      if (e?.message) {
        try {
          const parsed = JSON.parse(e.message);
          if (Array.isArray(parsed) && parsed[0]?.message) {
            errorMsg = parsed[0].message;
          } else {
            errorMsg = e.message;
          }
        } catch {
          errorMsg = e.message;
        }
      }
      
      setError(errorMsg);
    } finally {
      setBusy(false);
    }
  }



  function downloadCodes() {
    const blob = new Blob(
      [`Codes de secours ERP FABS-CI\nGénérés le ${new Date().toLocaleString()}\n\n${backupText}\n`],
      { type: "text/plain" },
    );
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "codes-secours-mfa.txt";
    a.click();
  }

  if (step === "done") {
    return (
      <Card className="max-w-xl mx-auto shadow-lg border-green-200 h-auto sm:max-h-[85vh] flex flex-col overflow-hidden">
        <CardHeader className="bg-green-50/50 border-b shrink-0 py-4">
          <CardTitle className="text-green-800 flex items-center gap-2 text-lg">
            <ShieldCheck className="h-6 w-6 shrink-0" />
            <span>🟢 MFA ACTIVÉ AVEC SUCCÈS</span>
          </CardTitle>
          <div className="mt-1">
            <p className="text-sm font-medium text-slate-700">Utilisateur : {targetUserLabel || targetUserId || "Vous"}</p>
          </div>
        </CardHeader>
        
        <CardContent className="flex-1 overflow-y-auto p-4 md:p-6 space-y-6">
          <div className="space-y-2">
            <h3 className="font-bold text-lg"># CODES DE RÉCUPÉRATION</h3>
            <p className="text-sm text-muted-foreground">
              Conservez ces codes dans un endroit sûr. Ils sont à usage unique et vous permettent
              d'accéder à votre compte si vous perdez votre appareil.
            </p>
          </div>

          <Alert className="bg-orange-50 border-orange-200">
            <AlertTriangle className="h-4 w-4 text-orange-600" />
            <AlertDescription className="text-orange-800 text-xs font-medium">
              Une fois ces codes utilisés ou si vous quittez cette page, vous ne pourrez plus les voir.
              Téléchargez-les ou imprimez-les maintenant.
            </AlertDescription>
          </Alert>

          <div className="grid grid-cols-2 gap-3 p-4 bg-slate-50 rounded-lg border font-mono text-sm">
            {backup.map((c) => (
              <div key={c} className="flex items-center justify-between group">
                <span className="font-bold tracking-wider">{c}</span>
                <Button 
                  variant="ghost" 
                  size="icon" 
                  className="h-6 w-6 opacity-0 group-hover:opacity-100"
                  onClick={() => {
                    navigator.clipboard.writeText(c);
                    toast.success("Code copié");
                  }}
                >
                  <Copy className="h-3 w-3" />
                </Button>
              </div>
            ))}
          </div>

          <div className="flex flex-wrap items-center gap-3 justify-center pt-2">
            <Button onClick={downloadCodes} className="flex-1 min-w-[140px]">
              <Download className="mr-2 h-4 w-4" /> Télécharger (.txt)
            </Button>
            <Button variant="outline" onClick={() => window.print()} className="flex-1 min-w-[140px]">
              <Printer className="mr-2 h-4 w-4" /> Imprimer
            </Button>
          </div>
        </CardContent>
        
        <div className="p-4 bg-slate-50 border-t shrink-0">
          <Button variant="default" className="w-full h-12 text-lg font-bold" onClick={() => onSuccess ? onSuccess() : navigate({ to: "/" })}>
            J'AI ENREGISTRÉ MES CODES
          </Button>
        </div>
      </Card>
    );
  }

  return (
    <Card className="max-w-xl mx-auto shadow-md border-primary/20 h-auto sm:max-h-[85vh] flex flex-col overflow-hidden">
      <CardHeader className="bg-primary/5 border-b shrink-0 py-4">
        <CardTitle className="flex items-center gap-2 text-primary text-lg">
          <Lock className="h-5 w-5 shrink-0" />
          <span>🔐 CONFIGURATION DE L'AUTHENTIFICATION</span>
        </CardTitle>
        <div className="mt-1 flex flex-col gap-1">
          <p className="text-sm font-medium text-slate-700">Utilisateur : {targetUserLabel || targetUserId || "Vous"}</p>
          {targetUserId && (
            <Alert className="bg-blue-50 border-blue-200 py-2">
              <AlertCircle className="h-3.5 w-3.5 text-blue-600" />
              <AlertDescription className="text-blue-800 text-xs font-medium">
                Configuration du MFA pour un autre utilisateur. L'utilisateur devra scanner ce code.
              </AlertDescription>
            </Alert>
          )}
        </div>
      </CardHeader>
      
      <CardContent className="flex-1 overflow-y-auto p-4 md:p-6 space-y-8">
        <div className="space-y-6">
          <div className="space-y-4">
            <h3 className="font-bold flex items-center gap-2 text-lg">
              <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground text-xs">
                1
              </span>
              ÉTAPE 1
            </h3>
            <p className="text-sm text-muted-foreground">
              Scannez ce QR Code avec votre application d'authentification (Google Authenticator, Microsoft Authenticator, Authy, etc.).
            </p>
            
            {qr ? (
              <div className="flex flex-col items-center gap-4 py-4 bg-white rounded-xl border border-dashed p-6 max-w-sm mx-auto w-full">
                <img src={qr} alt="QR code MFA" className="w-48 h-48 object-contain" />
                {secret && (
                  <div className="w-full space-y-2">
                    <p className="text-[10px] uppercase font-bold text-center text-muted-foreground tracking-widest">
                      Clé de configuration
                    </p>
                    <div className="flex items-center justify-center gap-2 p-2 bg-slate-50 rounded border">
                      <code className="font-mono text-xs font-bold tracking-widest overflow-hidden text-ellipsis whitespace-nowrap">{secret}</code>
                      <Button
                        type="button"
                        size="icon"
                        variant="ghost"
                        className="h-6 w-6 shrink-0"
                        onClick={() => {
                          navigator.clipboard.writeText(secret);
                          toast.success("Clé copiée");
                        }}
                      >
                        <Copy className="h-3 w-3" />
                      </Button>
                    </div>
                  </div>
                )}
              </div>
            ) : (
              <div className="h-48 flex items-center justify-center border rounded-xl bg-slate-50 max-w-sm mx-auto w-full">
                <Loader2 className="h-8 w-8 animate-spin text-primary/30" />
              </div>
            )}

            {otpauth && (
              <div className="flex flex-col items-center gap-2 sm:hidden">
                <a href={otpauth} className="w-full">
                  <Button type="button" variant="outline" className="w-full border-primary text-primary h-12">
                    📱 Configurer automatiquement
                  </Button>
                </a>
              </div>
            )}
          </div>

          <div className="space-y-4">
            <h3 className="font-bold flex items-center gap-2 text-lg">
              <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground text-xs">
                2
              </span>
              ÉTAPE 2
            </h3>
            <p className="text-sm text-muted-foreground">
              Saisissez le code à 6 chiffres généré par votre application.
            </p>

            <div className="space-y-4 max-w-sm mx-auto">
              <div className="relative">
                <Input
                  id="code"
                  inputMode="numeric"
                  pattern="\d{6}"
                  maxLength={6}
                  value={code}
                  onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
                  placeholder="[ _ _ _ _ _ _ ]"
                  className="h-14 text-center text-2xl font-bold tracking-[0.5em] placeholder:tracking-normal"
                />
              </div>

              {error && (
                <Alert variant="destructive">
                  <AlertCircle className="h-4 w-4 shrink-0" />
                  <AlertDescription className="text-xs">{error}</AlertDescription>
                </Alert>
              )}
            </div>
          </div>
        </div>
        
        <p className="text-[10px] text-center text-muted-foreground uppercase tracking-widest border-t pt-4 pb-2">
          Sécurité ERP FABS-CI — TOTP Authentification
        </p>
      </CardContent>

      <div className="p-4 bg-slate-50 border-t shrink-0 flex flex-col gap-3">
        <Button 
          onClick={onConfirm} 
          disabled={busy || code.length < 6} 
          className="w-full h-12 text-lg font-bold bg-green-600 hover:bg-green-700"
        >
          {busy ? (
            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
          ) : (
            <Check className="mr-2 h-5 w-5" />
          )}
          VÉRIFIER ET ACTIVER
        </Button>
      </div>
    </Card>
  );
}
