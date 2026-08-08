import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Combobox } from "@/components/ui/combobox";
import { VILLES_CI, COMMUNES_ABIDJAN } from "@/lib/ci-locations";
import { Plus, RefreshCw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useQueryClient } from "@tanstack/react-query";

import type { Livreur } from "./colisage-form-types";
import type { ColisageFieldErrors } from "./colisage-validation";


function FieldError({ msg }: { msg?: string }) {
  if (!msg) return null;
  return <p className="mt-1 text-xs text-destructive">{msg}</p>;
}

export function ColisageLivraisonFields(props: {
  quartier: string;
  setQuartier: (v: string) => void;
  commune: string;
  setCommune: (v: string) => void;
  villeLivraison: string;
  setVilleLivraison: (v: string) => void;
  errors?: ColisageFieldErrors;
}) {
  const {
    quartier,
    setQuartier,
    commune,
    setCommune,
    villeLivraison,
    setVilleLivraison,
    errors = {},
  } = props;
  const qc = useQueryClient();

  return (
    <>
      <div
        className="md:col-span-3 -mb-2 mt-2 rounded-md px-3 py-2 font-semibold"
        style={{ backgroundColor: "#F97316", color: "#000" }}
      >
        Livraison
      </div>
      <div className="hidden">
        {/* Informations de livraison masquées car gérées dans les Tournées */}
      </div>
      <div>
        <Label>Quartier</Label>
        <Input
          value={quartier}
          onChange={(e) => setQuartier(e.target.value)}
          placeholder="Quartier"
        />
      </div>
      <div>
        <Label>
          Commune <span className="text-destructive">*</span>
        </Label>
        <Combobox
          value={commune}
          onChange={(v) => setCommune(v ?? "")}
          options={COMMUNES_ABIDJAN}
          placeholder="Sélectionner une commune"
        />
        <FieldError msg={errors.commune} />
      </div>
      <div>
        <Label>
          Ville <span className="text-destructive">*</span>
        </Label>
        <Input
          value={villeLivraison}
          onChange={(e) => setVilleLivraison(e.target.value.toUpperCase())}
          placeholder="ABIDJAN"
        />
        <FieldError msg={errors.villeLivraison} />
      </div>
    </>
  );
}

export function ColisageExpeditionFields(props: {
  gareDepart: string;
  setGareDepart: (v: string) => void;
  villeDest: string;
  setVilleDest: (v: string) => void;
  gareResp: string;
  setGareResp: (v: string) => void;
  gareTel: string;
  setGareTel: (v: string) => void;
  errors?: ColisageFieldErrors;
}) {
  const {
    gareDepart,
    setGareDepart,
    villeDest,
    setVilleDest,
    gareResp,
    setGareResp,
    gareTel,
    setGareTel,
    errors = {},
  } = props;
  return (
    <>
      <div>
        <Label>
          Gare de départ
        </Label>
        <Input value={gareDepart} onChange={(e) => setGareDepart(e.target.value)} />
        <FieldError msg={errors.gareDepart} />
      </div>
      <div>
        <Label>
          Ville de destination <span className="text-destructive">*</span>
        </Label>
        <Combobox
          value={villeDest}
          onChange={(v) => setVilleDest(v ?? "")}
          options={VILLES_CI}
          placeholder="Sélectionner une ville"
        />
        <FieldError msg={errors.villeDest} />
      </div>
      <div>
        <Label>
          Responsable de la gare
        </Label>
        <div className="flex gap-2">
          <div className="flex-1">
            <Input value={gareResp} onChange={(e) => setGareResp(e.target.value)} />
          </div>
          <Button
            type="button"
            variant="outline"
            size="icon"
            onClick={() => window.open("/colisage/responsables?new=true", "_blank")}
            title="Créer un nouveau responsable"
          >
            <Plus className="h-4 w-4" />
          </Button>
        </div>
        <FieldError msg={errors.gareResp} />
      </div>
      <div>
        <Label>
          Téléphone du responsable
        </Label>
        <Input value={gareTel} onChange={(e) => setGareTel(e.target.value)} />
        <FieldError msg={errors.gareTel} />
      </div>

    </>
  );
}
