import { useEffect, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ResponsiveDialog } from "@/components/ui/responsive-dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  avancerEtape,
  etapeInputs,
  nextEtape,
  STATUT_COLOR,
  STATUT_LABEL,
  type LivStatut,
  type LivSuiviCommande,
} from "@/lib/livraison-suivi-api";

type Props = {
  target: LivSuiviCommande | null;
  onClose: () => void;
  defaults?: Record<string, string | null | undefined>;
};

export function AvancerEtapeDialog({ target, onClose, defaults }: Props) {
  const qc = useQueryClient();
  const [meta, setMeta] = useState<Record<string, string>>({});
  const [commentaire, setCommentaire] = useState("");
  const [choix, setChoix] = useState<LivStatut | null>(null);

  useEffect(() => {
    setMeta({});
    setCommentaire("");
    setChoix(null);
  }, [target?.id]);

  const next = target ? nextEtape(target.type_livraison, target.statut) : null;
  const options: LivStatut[] =
    target && target.statut === "arrivee_gare" && target.type_livraison === "expedition"
      ? ["retiree_client", "livree_locale"]
      : next
        ? [next]
        : [];
  const etape = choix ?? options[0] ?? null;
  const inputs = etape ? etapeInputs(etape) : [];

  useEffect(() => {
    if (!etape || !defaults) return;
    setMeta((prev) => {
      const nextMeta = { ...prev };
      for (const f of inputs) {
        if (!nextMeta[f.key] && defaults[f.key]) nextMeta[f.key] = String(defaults[f.key]);
      }
      return nextMeta;
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [etape, target?.id]);

  const mut = useMutation({
    mutationFn: () => {
      if (!target || !etape) throw new Error("Étape indisponible");
      const missing = inputs.find((i) => i.required && !meta[i.key]);
      if (missing) throw new Error(`Le champ « ${missing.label} » est obligatoire`);
      return avancerEtape(target.id, etape, meta, commentaire || undefined);
    },
    onSuccess: () => {
      toast.success("Étape validée");
      qc.invalidateQueries({ queryKey: ["livsuivi"] });
      onClose();
    },
    onError: (e: Error) => toast.error(e.message),
  });

  return (
    <ResponsiveDialog
      open={!!target}
      onOpenChange={(o) => !o && onClose()}
      title={`${target?.commande?.reference ?? ""} — Avancer d'une étape`}
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            Annuler
          </Button>
          <Button onClick={() => mut.mutate()} disabled={mut.isPending || !etape}>
            {mut.isPending ? "Validation…" : "Valider l'étape"}
          </Button>
        </>
      }
    >
      {target && (
        <div className="space-y-3">
          <div className="text-sm">
            Statut actuel :{" "}
            <Badge style={{ backgroundColor: STATUT_COLOR[target.statut], color: "white" }}>
              {STATUT_LABEL[target.statut]}
            </Badge>
          </div>
          {options.length > 1 && (
            <div>
              <Label>Prochaine étape</Label>
              <Select value={etape ?? ""} onValueChange={(v) => setChoix(v as LivStatut)}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {options.map((s) => (
                    <SelectItem key={s} value={s}>
                      {STATUT_LABEL[s]}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          )}
          {options.length === 1 && etape && (
            <div className="text-sm">
              → <strong>{STATUT_LABEL[etape]}</strong>
            </div>
          )}
          {inputs.map((f) => (
            <div key={f.key}>
              <Label>
                {f.label}
                {f.required && " *"}
              </Label>
              <Input
                value={meta[f.key] ?? ""}
                onChange={(e) => setMeta((m) => ({ ...m, [f.key]: e.target.value }))}
              />
            </div>
          ))}
          <div>
            <Label>Commentaire (optionnel)</Label>
            <Input value={commentaire} onChange={(e) => setCommentaire(e.target.value)} />
          </div>
        </div>
      )}
    </ResponsiveDialog>
  );
}
