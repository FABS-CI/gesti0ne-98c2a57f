import { useEffect, useMemo, useState } from "react";
import { useServerFn } from "@tanstack/react-start";
import { useNavigate } from "@tanstack/react-router";
import QRCode from "qrcode";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { toast } from "sonner";
import { mfaEnrollStart, mfaEnrollConfirm } from "@/lib/mfa.functions";

export function MfaEnrollView() {
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
    start()
      .then(async (r) => {
        setOtpauth(r.otpauthUrl);
        setSecret(r.secret);
        setQr(await QRCode.toDataURL(r.otpauthUrl, { width: 240, margin: 1 }));
        setStep("scan");
      })
      .catch((e) => setError(String(e?.message ?? e)));
  }, [start]);

  const backupText = useMemo(() => backup.join("\n"), [backup]);

  async function onConfirm() {
    setBusy(true);
    setError(null);
    try {
      const r = await confirm({ data: { code } });
      setBackup(r.backupCodes);
      setStep("done");
      toast.success("MFA activé");
    } catch (e) {
      setError(String((e as Error).message ?? e));
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
      <Card className="max-w-xl mx-auto">
        <CardHeader>
          <CardTitle>Codes de secours</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <Alert>
            <AlertDescription>
              Conservez ces codes en lieu sûr. Chaque code ne peut être utilisé qu'une seule fois.
              Ils vous permettent de vous connecter en cas de perte de votre téléphone.
            </AlertDescription>
          </Alert>
          <pre className="bg-muted p-4 rounded font-mono text-sm grid grid-cols-2 gap-2">
            {backup.map((c) => (
              <span key={c}>{c}</span>
            ))}
          </pre>
          <div className="flex gap-2">
            <Button onClick={downloadCodes}>Télécharger (.txt)</Button>
            <Button variant="outline" onClick={() => window.print()}>
              Imprimer
            </Button>
            <Button variant="secondary" onClick={() => navigate({ to: "/" })}>
              Continuer
            </Button>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="max-w-xl mx-auto">
      <CardHeader>
        <CardTitle>Activer l'authentification à deux facteurs</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <ol className="list-decimal ml-5 space-y-1 text-sm">
          <li>Installez <b>Google Authenticator</b> ou <b>Microsoft Authenticator</b>.</li>
          <li>Scannez le QR code ci-dessous depuis l'application.</li>
          <li>Saisissez le code à 6 chiffres affiché pour confirmer.</li>
        </ol>
        {qr ? (
          <div className="flex justify-center">
            <img src={qr} alt="QR code MFA" className="border rounded" />
          </div>
        ) : (
          <p className="text-sm text-muted-foreground text-center">Génération du QR…</p>
        )}
        {otpauth && (
          <div className="flex flex-col items-center gap-2">
            <a href={otpauth} className="sm:hidden">
              <Button type="button" variant="secondary">
                📱 Ouvrir dans mon app Authenticator
              </Button>
            </a>
            <p className="text-xs text-muted-foreground text-center sm:hidden">
              Sur téléphone : appuyez sur le bouton ci-dessus (Google / Microsoft Authenticator s'ouvre et enregistre le compte automatiquement).
            </p>
          </div>
        )}
        {secret && (
          <div className="text-xs text-muted-foreground text-center space-y-1">
            <p>Ou saisie manuelle de la clé :</p>
            <div className="flex items-center justify-center gap-2">
              <code className="font-mono break-all">{secret}</code>
              <Button
                type="button"
                size="sm"
                variant="ghost"
                onClick={() => {
                  navigator.clipboard.writeText(secret);
                  toast.success("Clé copiée");
                }}
              >
                Copier
              </Button>
            </div>
          </div>
        )}
        <div className="space-y-2">
          <Label htmlFor="code">Code à 6 chiffres</Label>
          <Input
            id="code"
            inputMode="numeric"
            pattern="\d{6}"
            maxLength={6}
            value={code}
            onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
            placeholder="123456"
          />
        </div>
        {error && <Alert variant="destructive"><AlertDescription>{error}</AlertDescription></Alert>}
        <Button onClick={onConfirm} disabled={busy || code.length !== 6} className="w-full">
          {busy ? "Vérification…" : "Activer"}
        </Button>
      </CardContent>
    </Card>
  );
}