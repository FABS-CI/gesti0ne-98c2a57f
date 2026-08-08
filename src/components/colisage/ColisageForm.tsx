import { useEffect, useMemo, useRef, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Link } from "@tanstack/react-router";
import { CheckCircle2, Loader2, PackageCheck, Plus, RefreshCw } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { SectionHeader } from "@/components/ui/section-header";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { supabase } from "@/integrations/supabase/client";
import {
  creerColisageManuel,
  type BLDetail,
  type ColisagePayload,
  type CartonManuel,
  type ModeAcheminement,
} from "@/lib/colisage-api";
import { invalidateColisage } from "@/lib/cache-invalidation";
import { keyForLigne, detectMode, type ZonesDirectes } from "@/lib/colisage-helpers";
import { ColisageModeSection } from "./form/ColisageModeSection";
import {
  ColisageLivraisonFields,
  ColisageExpeditionFields,
} from "./form/ColisageAcheminementFields";
import { ColisageCartonsSection } from "./form/ColisageCartonsSection";
import type { CartonState, Responsable, ClientInfo } from "./form/colisage-form-types";
import { friendlyError } from "@/lib/friendly-error";
import {
  livraisonSchema,
  expeditionSchema,
  zodToErrors,
  type ColisageFieldErrors,
} from "./form/colisage-validation";

interface ColisageFormProps {
  blId: string;
  bl: BLDetail;
  clientInfo: ClientInfo;
  zonesDirectes?: ZonesDirectes;
  responsablesList: Responsable[];
  modifiable: boolean;
  hasColis: boolean;
}

export function ColisageForm({
  blId,
  bl,
  clientInfo,
  zonesDirectes,
  responsablesList,
  modifiable,
  hasColis,
}: ColisageFormProps) {
  const qc = useQueryClient();

  const [responsable, setResponsable] = useState("");
  const responsableTriggerRef = useRef<HTMLButtonElement>(null);
  const [observations, setObservations] = useState("");
  const [mode, setMode] = useState<ModeAcheminement>("livraison");
  const [modeManuel, setModeManuel] = useState(false);

  const [quartier, setQuartier] = useState("");
  const [commune, setCommune] = useState("");
  const [villeLivraison, setVilleLivraison] = useState("");

  const [gareDepart, setGareDepart] = useState("");
  const [villeDest, setVilleDest] = useState("");
  const [gareResp, setGareResp] = useState("");
  const [gareTel, setGareTel] = useState("");

  const [cartons, setCartons] = useState<CartonState[]>([
    { poids: "", observations: "", lignes: [{ produit_id: "", quantite: "" }] },
  ]);
  const nbCartons = cartons.length;

  const [fieldErrors, setFieldErrors] = useState<ColisageFieldErrors>({});
  const clearFieldError = (k: string) =>
    setFieldErrors((p) => (p[k] === undefined ? p : { ...p, [k]: undefined }));

  // — Préremplissage client —
  const prefilledRef = useRef(false);
  useEffect(() => {
    if (prefilledRef.current) return;
    if (!clientInfo) return;
    let touched = false;
    if (!villeLivraison && clientInfo.ville) {
      setVilleLivraison(clientInfo.ville);
      touched = true;
    }
    if (!commune && clientInfo.commune) {
      setCommune(clientInfo.commune);
      touched = true;
    }
    if (!quartier && clientInfo.quartier) {
      setQuartier(clientInfo.quartier);
      touched = true;
    }
    if (!villeDest && clientInfo.ville) {
      setVilleDest(clientInfo.ville);
      touched = true;
    }
    if (touched) prefilledRef.current = true;
  }, [clientInfo, villeLivraison, commune, quartier, villeDest]);

  // — Auto-détection du mode —
  const villeEff = villeLivraison || villeDest || clientInfo?.ville || "";
  const communeEff = commune || clientInfo?.commune || "";
  const detection = useMemo(
    () => detectMode(villeEff, communeEff, zonesDirectes),
    [villeEff, communeEff, zonesDirectes],
  );
  const { autoMode } = detection;

  useEffect(() => {
    setModeManuel(false);
  }, [villeLivraison, villeDest, commune]);
  useEffect(() => {
    if (modeManuel) return;
    if (autoMode && autoMode !== mode) setMode(autoMode);
  }, [autoMode, mode, modeManuel]);

  // — Carton helpers —
  const lignesCommande = bl.lignes;
  const attendu = useMemo(() => {
    const m = new Map<string, number>();
    for (const l of lignesCommande)
      m.set(keyForLigne(l), (m.get(keyForLigne(l)) ?? 0) + l.quantite);
    return m;
  }, [lignesCommande]);
  const reparti = useMemo(() => {
    const m = new Map<string, number>();
    for (const c of cartons)
      for (const li of c.lignes) {
        if (!li.produit_id) continue;
        m.set(li.produit_id, (m.get(li.produit_id) ?? 0) + (parseInt(li.quantite || "0", 10) || 0));
      }
    return m;
  }, [cartons]);
  const ecarts = useMemo(() => {
    return lignesCommande.map((l) => {
      const k = keyForLigne(l);
      const r = reparti.get(k) ?? 0;
      return {
        key: k,
        designation: l.designation ?? "—",
        commande: l.quantite,
        reparti: r,
        reste: l.quantite - r,
      };
    });
  }, [lignesCommande, reparti]);
  const compositionValide =
    ecarts.length > 0 &&
    ecarts.every((r) => r.reste === 0) &&
    cartons.every((c) =>
      c.lignes.some((li) => li.produit_id && parseInt(li.quantite || "0", 10) > 0),
    );

  const addCarton = () =>
    setCartons((p) => [
      ...p,
      { poids: "", observations: "", lignes: [{ produit_id: "", quantite: "" }] },
    ]);
  const removeCarton = (i: number) =>
    setCartons((p) => (p.length > 1 ? p.filter((_, j) => j !== i) : p));
  const addLigne = (ci: number) =>
    setCartons((p) =>
      p.map((c, i) =>
        i === ci ? { ...c, lignes: [...c.lignes, { produit_id: "", quantite: "" }] } : c,
      ),
    );
  const removeLigne = (ci: number, li: number) => {
    setCartons((p) =>
      p.map((c, i) => (i === ci ? { ...c, lignes: c.lignes.filter((_, j) => j !== li) } : c)),
    );
  };
  const updateLigne = (
    ci: number,
    li: number,
    patch: Partial<{ produit_id: string; quantite: string }>,
  ) =>
    setCartons((p) =>
      p.map((c, i) =>
        i === ci
          ? { ...c, lignes: c.lignes.map((l, j) => (j === li ? { ...l, ...patch } : l)) }
          : c,
      ),
    );
  const updateCarton = (ci: number, patch: Partial<CartonState>) =>
    setCartons((p) => p.map((c, i) => (i === ci ? { ...c, ...patch } : c)));

  const mutation = useMutation({
    mutationFn: (args: { payload: ColisagePayload; cartons: CartonManuel[] }) =>
      creerColisageManuel(blId, args.payload, args.cartons),
    onSuccess: async () => {
      toast.success("Colisage généré");
      invalidateColisage(qc, { blId, clientId: bl.client_id ?? undefined });
      if (bl.client_id && clientInfo) {
        const patch: { ville?: string; commune?: string; quartier?: string } = {};
        const villeCandidate = mode === "livraison" ? villeLivraison : villeDest;
        if (!clientInfo.ville && villeCandidate) patch.ville = villeCandidate;
        if (mode === "livraison") {
          if (!clientInfo.commune && commune) patch.commune = commune;
          if (!clientInfo.quartier && quartier) patch.quartier = quartier;
        }
        if (Object.keys(patch).length > 0) {
          const { error } = await supabase
            .from("clients")
            .update(patch)
            .eq("client_id", bl.client_id!);
          if (!error) {
            toast.success("Fiche client complétée automatiquement");
            qc.invalidateQueries({ queryKey: ["colisage-client-info", bl.client_id] });
          }
        }
      }
    },
    onError: (e: Error) => toast.error(friendlyError(e)),
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (nbCartons < 1) return toast.error("Au moins 1 carton");
    if (!responsable) {
      setFieldErrors((p) => ({ ...p, responsable: "Responsable du colisage requis" }));
      toast.error("Champ requis : « Responsable du colisage ». Merci de le sélectionner.");
      requestAnimationFrame(() => responsableTriggerRef.current?.focus());
      return;
    }
    const parsed =
      mode === "livraison"
        ? livraisonSchema.safeParse({})
        : expeditionSchema.safeParse({ gareDepart, villeDest, gareResp, gareTel });
    if (!parsed.success) {
      const errs = zodToErrors(parsed.error);
      setFieldErrors(errs);
      toast.error("Corrigez les champs signalés en rouge.");
      return;
    }
    setFieldErrors({});
    if (!compositionValide)
      return toast.error("La répartition des articles n'est pas complète ou est incorrecte.");

    const payload: ColisagePayload = {
      nb_cartons: nbCartons,
      responsable_nom: responsable || null,
      observations: observations || null,
      date_colisage: new Date().toISOString(),
      mode_acheminement: mode,
      quartier: mode === "livraison" ? quartier || null : null,
      commune: mode === "livraison" ? commune || null : null,
      ville_livraison: mode === "livraison" ? villeLivraison || null : null,
      gare_depart: mode === "expedition" ? gareDepart || null : null,
      ville_destination: mode === "expedition" ? villeDest || null : null,
      gare_responsable: mode === "expedition" ? gareResp || null : null,
      gare_telephone: mode === "expedition" ? gareTel || null : null,
    };
    const cartonsPayload: CartonManuel[] = cartons.map((c, idx) => ({
      numero: idx + 1,
      poids: c.poids ? Number(c.poids) : null,
      observations: c.observations || null,
      lignes: c.lignes
        .filter((li) => li.produit_id && parseInt(li.quantite || "0", 10) > 0)
        .map((li) => {
          const cmdLigne = lignesCommande.find((x) => keyForLigne(x) === li.produit_id);
          return {
            produit_id: li.produit_id,
            designation: cmdLigne?.designation ?? null,
            reference_produit: cmdLigne?.reference_produit ?? null,
            quantite: parseInt(li.quantite, 10),
          };
        }),
    }));
    mutation.mutate({ payload, cartons: cartonsPayload });
  };

  return (
    <Card className="print:hidden">
      <SectionHeader
        icon={PackageCheck}
        title={hasColis ? "Refaire le colisage" : "Créer le colisage"}
        color="#3B82F6"
      />
      <CardContent className="pl-5 sm:pl-6">
        <fieldset disabled={!modifiable} className="contents">
          <form onSubmit={handleSubmit} className="grid gap-4 md:grid-cols-3">
            <div>
              <Label>
                Responsable du colisage <span className="text-destructive">*</span>
              </Label>
              <div className="flex gap-2">
                <div className="flex-1">
                  <Select
                    value={responsable}
                    onValueChange={(v) => {
                      setResponsable(v);
                      setFieldErrors((p) => ({ ...p, responsable: undefined }));
                    }}
                  >
                    <SelectTrigger
                      ref={responsableTriggerRef}
                      aria-label="Responsable du colisage"
                      className={fieldErrors.responsable ? "border-destructive" : undefined}
                      aria-invalid={!!fieldErrors.responsable}
                    >
                      <SelectValue
                        placeholder={
                          responsablesList.length === 0
                            ? "Aucun responsable disponible"
                            : "Sélectionner un responsable"
                        }
                      />
                    </SelectTrigger>
                    <SelectContent>
                      {responsablesList.length === 0 ? (
                        <div className="p-2 text-xs text-muted-foreground text-center">
                          Aucun responsable trouvé
                        </div>
                      ) : (
                        responsablesList.map((r) => (
                          <SelectItem key={r.preparateur_id} value={r.nom}>
                            {r.nom}
                            {r.poste ? ` — ${r.poste}` : ""}
                          </SelectItem>
                        ))
                      )}
                    </SelectContent>
                  </Select>
                </div>
                <div className="flex gap-1">
                  <Button
                    type="button"
                    variant="outline"
                    size="icon"
                    onClick={() => window.open("/colisage/responsables?new=true", "_blank")}
                    title="Créer un nouveau responsable"
                  >
                    <Plus className="h-4 w-4" />
                  </Button>
                  <Button
                    type="button"
                    variant="ghost"
                    size="icon"
                    onClick={() => qc.invalidateQueries({ queryKey: ["preparateurs-colisage-actifs"] })}
                    title="Rafraîchir la liste"
                  >
                    <RefreshCw className="h-4 w-4" />
                  </Button>
                </div>
              </div>
              {fieldErrors.responsable && (
                <p className="mt-1 text-xs text-destructive">{fieldErrors.responsable}</p>
              )}
              {responsablesList.length === 0 && (
                <p className="mt-1 text-xs text-muted-foreground">
                  Aucun responsable actif.{" "}
                  <Link to="/colisage/responsables" className="underline">
                    Gérer les responsables
                  </Link>
                </p>
              )}

            </div>
            <div>
              <Label>Date / heure</Label>
              <Input value={new Date().toLocaleString("fr-FR")} disabled />
            </div>
            <div>
              <Label>Nombre total de cartons</Label>
              <Input value={`${nbCartons} carton${nbCartons > 1 ? "s" : ""}`} disabled />
            </div>

            <div className="md:col-span-3">
              <Label>Observations</Label>
              <Textarea value={observations} onChange={(e) => setObservations(e.target.value)} />
            </div>

            <ColisageModeSection
              mode={mode}
              onModeChange={(v) => {
                setModeManuel(true);
                setMode(v);
              }}
              detection={detection}
              modeManuel={modeManuel}
            />

            {mode === "livraison" ? null : (
              <ColisageExpeditionFields
                gareDepart={gareDepart}
                setGareDepart={(v) => {
                  setGareDepart(v);
                  clearFieldError("gareDepart");
                }}
                villeDest={villeDest}
                setVilleDest={(v) => {
                  setVilleDest(v);
                  clearFieldError("villeDest");
                }}
                gareResp={gareResp}
                setGareResp={(v) => {
                  setGareResp(v);
                  clearFieldError("gareResp");
                }}
                gareTel={gareTel}
                setGareTel={(v) => {
                  setGareTel(v);
                  clearFieldError("gareTel");
                }}
                errors={fieldErrors}
              />
            )}

            <div className="md:col-span-3 flex justify-end">
              <Button
                type="submit"
                disabled={mutation.isPending || !modifiable || !compositionValide}
              >
                {mutation.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                <CheckCircle2 className="mr-2 h-4 w-4" />
                {hasColis
                  ? `Regénérer le colisage (${nbCartons} carton${nbCartons > 1 ? "s" : ""})`
                  : `Valider — Colisage terminé (${nbCartons} carton${nbCartons > 1 ? "s" : ""})`}
              </Button>
            </div>
          </form>
        </fieldset>

        <ColisageCartonsSection
          cartons={cartons}
          ecarts={ecarts}
          compositionValide={compositionValide}
          lignesCommande={lignesCommande}
          attendu={attendu}
          reparti={reparti}
          addCarton={addCarton}
          removeCarton={removeCarton}
          addLigne={addLigne}
          removeLigne={removeLigne}
          updateLigne={updateLigne}
          updateCarton={updateCarton}
        />
      </CardContent>
    </Card>
  );
}
