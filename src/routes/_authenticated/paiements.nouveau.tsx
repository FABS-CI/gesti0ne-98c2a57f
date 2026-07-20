import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useEffect, useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { zodValidator, fallback } from "@tanstack/zod-adapter";
import { z } from "zod";
import { AlertCircle, ArrowLeft, CreditCard } from "lucide-react";
import { toast } from "sonner";
import { usePermissions } from "@/hooks/use-permissions";

import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ClientSearchSelect } from "@/components/search/ClientSearchSelect";
import { FacturesImpayeesCard } from "@/components/paiements/nouveau/FacturesImpayeesCard";
import { PaiementFormCard, type FormState } from "@/components/paiements/nouveau/PaiementFormCard";
import { RecapCard } from "@/components/paiements/nouveau/RecapCard";
import { formatFCFA } from "@/lib/format";
import { computeRecap } from "@/lib/paiement-recap";

import {
  enregistrerPaiement,
  listFacturesImpayeesClient,
  type EnregistrerPaiementInput,
} from "@/lib/paiements-api";
import { getClient } from "@/lib/clients-api";
import { validatePaiement } from "@/lib/paiement-recap";
import { invalidatePaiement } from "@/lib/cache-invalidation";

const searchSchema = z.object({
  clientId: fallback(z.string().optional(), undefined).default(undefined),
});

export const Route = createFileRoute("/_authenticated/paiements/nouveau")({
  validateSearch: zodValidator(searchSchema),
  component: NouveauPaiementPage,
});

function NouveauPaiementPage() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { clientId: presetClientId } = Route.useSearch();
  const { has } = usePermissions();
  const canValider = has("paiements.valider");

  const [clientId, setClientId] = useState<string | null>(presetClientId ?? null);
  const [clientNom, setClientNom] = useState<string>("");
  const [clientError, setClientError] = useState<string | null>(null);
  const [factureId, setFactureId] = useState<string | null>(null);
  const [mode, setMode] = useState<"draft" | "confirm">("draft");

  useEffect(() => {
    if (presetClientId && !clientNom) {
      getClient(presetClientId)
        .then((c) => {
          if (c) setClientNom(c.nom);
          else setClientError("Client introuvable pour cet identifiant.");
        })
        .catch(() => setClientError("Impossible de charger le client."));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [presetClientId]);

  const [form, setForm] = useState<FormState>(() => {
    const now = new Date();
    const pad = (n: number) => String(n).padStart(2, "0");
    const autoRef = `PAY-${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
    return {
      date_paiement: now.toISOString().slice(0, 10),
      montant: 0,
      mode_paiement: "especes",
      reference_paiement: autoRef,
      banque: "",
      num_transaction: "",
      observations: "",
    };
  });


  const { data: factures = [], isLoading: facLoading } = useQuery({
    queryKey: ["factures-impayees", clientId],
    queryFn: () => (clientId ? listFacturesImpayeesClient(clientId) : Promise.resolve([])),
    enabled: !!clientId,
  });

  const selectedFacture = useMemo(
    () => factures.find((f) => f.facture_id === factureId) ?? null,
    [factures, factureId],
  );

  useEffect(() => {
    if (!factureId && factures.length === 1) {
      const f = factures[0];
      setFactureId(f.facture_id);
      setForm((s) => ({ ...s, montant: Number(f.solde) }));
    }
  }, [factures, factureId]);

  const mutation = useMutation({
    mutationFn: (payload: EnregistrerPaiementInput) => enregistrerPaiement(payload),
    onSuccess: () => {
      toast.success(
        canValider
          ? "Paiement enregistré et validé"
          : "Paiement enregistré, en attente de validation comptable",
      );
      invalidatePaiement(queryClient, {
        factureId: factureId ?? undefined,
        clientId: clientId ?? undefined,
      });
      if (presetClientId)
        navigate({ to: "/clients/$clientId", params: { clientId: presetClientId } });
      else navigate({ to: "/paiements" });
    },
    onError: (e: unknown) => toast.error(e instanceof Error ? e.message : "Erreur"),
  });

  function validate() {
    if (!factureId) {
      toast.error("Veuillez sélectionner une facture");
      return false;
    }
    const r = validatePaiement({
      montant: Number(form.montant),
      mode_paiement: form.mode_paiement,
      reference_paiement: form.reference_paiement ?? "",
      solde: selectedFacture ? Number(selectedFacture.solde) : undefined,
    });
    if (!r.ok) {
      toast.error(r.message);
      return false;
    }
    return true;
  }

  const submit = () => {
    if (!validate() || !factureId) return;
    mutation.mutate({ ...form, facture_id: factureId });
  };

  const preview = () => {
    if (validate()) setMode("confirm");
  };

  if (clientError) {
    return (
      <div className="mx-auto max-w-xl space-y-4 py-10">
        <Alert variant="destructive">
          <AlertCircle className="h-4 w-4" />
          <AlertTitle>Client invalide</AlertTitle>
          <AlertDescription>{clientError}</AlertDescription>
        </Alert>
        <div className="flex gap-2">
          <Button asChild variant="outline">
            <Link to="/clients">Retour à la liste clients</Link>
          </Button>
          <Button asChild>
            <Link to="/paiements">Voir les paiements</Link>
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Button asChild variant="ghost" size="icon">
          <Link to="/paiements">
            <ArrowLeft className="h-4 w-4" />
          </Link>
        </Button>
        <CreditCard className="h-6 w-6 text-primary" />
        <div>
          <h1 className="text-2xl font-bold">Nouveau paiement</h1>
          <p className="text-sm text-muted-foreground">
            Enregistrement d'un règlement client à imputer sur une facture
          </p>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">1. Sélection du client</CardTitle>
        </CardHeader>
        <CardContent>
          <ClientSearchSelect
            value={clientId}
            onChange={(id, client) => {
              setClientId(id);
              setClientNom(client?.nom ?? "");
              setFactureId(null);
            }}
          />
        </CardContent>
      </Card>

      {clientId && (
        <FacturesImpayeesCard
          clientNom={clientNom}
          factures={factures}
          loading={facLoading}
          factureId={factureId}
          onSelect={(f) => {
            setFactureId(f.facture_id);
            setForm((s) => ({ ...s, montant: Number(f.solde) }));
          }}
        />
      )}

      {factureId && (
        <PaiementFormCard
          form={form}
          setForm={setForm}
          mode={mode}
          soldeRestant={selectedFacture ? Number(selectedFacture.solde) : undefined}
          onPreview={preview}
          onSubmit={submit}
          onEdit={() => setMode("draft")}
          submitting={mutation.isPending}
        />
      )}

      {factureId && selectedFacture && form.montant > 0 && (
        <RecapCard
          reference={selectedFacture.reference}
          solde={Number(selectedFacture.solde)}
          montant={Number(form.montant)}
          mode={mode}
        />
      )}
    </div>
  );
}
