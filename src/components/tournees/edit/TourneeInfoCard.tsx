import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Field } from "./parts";
import { STATUTS, type Tournee, type Vehicule } from "./types";

export function TourneeInfoCard({
  form,
  setField,
  vehicules,
}: {
  form: Tournee;
  setField: <K extends keyof Tournee>(k: K, v: Tournee[K]) => void;
  vehicules: Vehicule[];
}) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm">Informations tournée</CardTitle>
      </CardHeader>
      <CardContent className="space-y-2">
        <Field label="Référence">
          <Input value={form.reference} onChange={(e) => setField("reference", e.target.value)} />
        </Field>
        <Field label="Date">
          <Input
            type="date"
            value={form.date_tournee ?? ""}
            onChange={(e) => setField("date_tournee", e.target.value || null)}
          />
        </Field>
        <Field label="Responsable">
          <Input
            value={form.responsable_nom ?? ""}
            onChange={(e) => setField("responsable_nom", e.target.value)}
          />
        </Field>
        <Field label="Chauffeur">
          <Input
            value={form.chauffeur_nom ?? ""}
            onChange={(e) => setField("chauffeur_nom", e.target.value)}
          />
        </Field>
        <Field label="Véhicule">
          <Select
            value={form.vehicule_id || "__none"}
            onValueChange={(v) => setField("vehicule_id", v === "__none" ? null : v)}
          >
            <SelectTrigger>
              <SelectValue placeholder="Sélectionner…" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="__none">— Aucun —</SelectItem>
              {vehicules.map((v) => (
                <SelectItem key={v.vehicule_id} value={v.vehicule_id}>
                  {v.immatriculation ?? v.vehicule_id}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </Field>
        <Field label="Statut">
          <Select value={form.statut} onValueChange={(v) => setField("statut", v)}>
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {STATUTS.map((s) => (
                <SelectItem key={s.value} value={s.value}>
                  {s.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </Field>
        <Field label="Type de tournée">
          <Select
            value={form.type_tournee ?? "livraison"}
            onValueChange={(v) => setField("type_tournee", v)}
          >
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="livraison">Livraison</SelectItem>
              <SelectItem value="expedition">Expédition</SelectItem>
              <SelectItem value="mixte">Mixte</SelectItem>
            </SelectContent>
          </Select>
        </Field>
        <Field label="Notes">
          <Textarea
            rows={2}
            value={form.notes ?? ""}
            onChange={(e) => setField("notes", e.target.value)}
          />
        </Field>
      </CardContent>
    </Card>
  );
}
