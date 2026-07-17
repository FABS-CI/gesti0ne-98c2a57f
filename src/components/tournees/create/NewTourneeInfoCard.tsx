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
import { Field } from "@/components/tournees/edit/parts";
import type { DepotRow, TourneeFormState, Vehicule } from "./types";

export function NewTourneeInfoCard({
  form,
  setForm,
  depots,
  vehicules,
}: {
  form: TourneeFormState;
  setForm: (updater: (f: TourneeFormState) => TourneeFormState) => void;
  depots: DepotRow[];
  vehicules: Vehicule[];
}) {
  const patch = (p: Partial<TourneeFormState>) => setForm((f) => ({ ...f, ...p }));
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm">Informations tournée</CardTitle>
      </CardHeader>
      <CardContent className="space-y-2">
        <Field label="Référence *">
          <Input value={form.reference} onChange={(e) => patch({ reference: e.target.value })} />
        </Field>
        <Field label="Date">
          <Input
            type="date"
            value={form.date_tournee}
            onChange={(e) => patch({ date_tournee: e.target.value })}
          />
        </Field>
        <Field label="Heure de départ *">
          <Input
            type="time"
            value={form.heure_depart}
            onChange={(e) => patch({ heure_depart: e.target.value })}
          />
        </Field>
        <Field label="Dépôt de départ *">
          <Select
            value={form.depot_depart_id || "__none"}
            onValueChange={(v) => patch({ depot_depart_id: v === "__none" ? "" : v })}
          >
            <SelectTrigger>
              <SelectValue placeholder="Sélectionner…" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="__none">— Sélectionner —</SelectItem>
              {depots.map((d) => (
                <SelectItem key={d.depot_id} value={d.depot_id}>
                  {d.nom ?? d.depot_id}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </Field>
        <Field label="Responsable logistique">
          <Input
            value={form.responsable_nom}
            onChange={(e) => patch({ responsable_nom: e.target.value })}
          />
        </Field>
        <Field label="Chauffeur *">
          <Input
            value={form.chauffeur_nom}
            onChange={(e) => patch({ chauffeur_nom: e.target.value })}
          />
        </Field>
        <Field label="Véhicule *">
          <Select
            value={form.vehicule_id || "__none"}
            onValueChange={(v) => patch({ vehicule_id: v === "__none" ? "" : v })}
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
        <Field label="Type de tournée">
          <Select value={form.type_tournee} onValueChange={(v) => patch({ type_tournee: v })}>
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
            value={form.notes}
            onChange={(e) => patch({ notes: e.target.value })}
          />
        </Field>
      </CardContent>
    </Card>
  );
}
