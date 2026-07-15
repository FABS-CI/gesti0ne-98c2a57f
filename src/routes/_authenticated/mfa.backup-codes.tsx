import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { useServerFn } from "@tanstack/react-start";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { toast } from "sonner";
import { mfaRegenerateBackupCodes } from "@/lib/mfa.functions";

function Page() {
  const regen = useServerFn(mfaRegenerateBackupCodes);
  const [codes, setCodes] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  async function onGen() {
    if (!confirm("Régénérer 10 nouveaux codes ? Les anciens seront invalidés.")) return;
    setBusy(true);
    try {
      const r = await regen();
      setCodes(r.backupCodes);
      toast.success("Nouveaux codes générés");
    } catch (e) {
      toast.error(String((e as Error).message ?? e));
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="p-6">
      <Card className="max-w-xl mx-auto">
        <CardHeader>
          <CardTitle>Codes de secours MFA</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <Alert>
            <AlertDescription>
              Régénérez vos 10 codes de secours. Les codes précédents seront immédiatement
              invalidés.
            </AlertDescription>
          </Alert>
          <Button onClick={onGen} disabled={busy}>
            {busy ? "Génération…" : "Régénérer 10 codes"}
          </Button>
          {codes.length > 0 && (
            <pre className="bg-muted p-4 rounded font-mono text-sm grid grid-cols-2 gap-2">
              {codes.map((c) => (
                <span key={c}>{c}</span>
              ))}
            </pre>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

export const Route = createFileRoute("/_authenticated/mfa/backup-codes")({
  component: Page,
});