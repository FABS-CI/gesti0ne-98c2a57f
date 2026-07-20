import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "@tanstack/react-router";
import { toast } from "sonner";

import {
  createConge,
  updateConge,
  TYPES_CONGE,
  STATUTS_CONGE,
  type CongeInput,
} from "@/lib/rh-api";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { EmployeeSearchSelect } from "@/components/search/EmployeeSearchSelect";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { RhPageHeader } from "@/components/rh/RhPageHeader";
import { useSaveHotkey } from "@/hooks/use-save-hotkey";
import { friendlyError } from "@/lib/friendly-error";

const emptyForm: CongeInput = {
  employe_id: "",
  type: "annuel",
  date_debut: new Date().toISOString().slice(0, 10),
  date_fin: new Date().toISOString().slice(0, 10),
  motif: "",
  statut: "en_attente",
};

type Props =
  | { mode: "create"; initial?: undefined; id?: undefined }
  | { mode: "edit"; initial: CongeInput; id: string };

export function CongeForm(props: Props) {
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [form, setForm] = useState<CongeInput>(props.mode === "edit" ? props.initial : emptyForm);
  const [continueAfter, setContinueAfter] = useState(false);

  const saveMutation = useMutation({
    mutationFn: async (input: CongeInput) => {
      if (props.mode === "edit") return updateConge(props.id, input);
      return createConge(input);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["conges"] });
      toast.success(props.mode === "edit" ? "Congé mis à jour" : "Demande enregistrée");
      if (continueAfter && props.mode === "create") {
        setForm(emptyForm);
        setContinueAfter(false);
      } else {
        navigate({ to: "/conges" });
      }
    },
    onError: (e: unknown) => toast.error(friendlyError(e, "Erreur")),
  });

  function submit(continueFlag = false) {
    if (!form.employe_id) {
      toast.error("Sélectionnez un employé");
      return;
    }
    setContinueAfter(continueFlag);
    saveMutation.mutate(form);
  }

  useSaveHotkey(() => submit(false), {
    onSaveAndContinue: props.mode === "create" ? () => submit(true) : undefined,
    enabled: !saveMutation.isPending,
  });

  return (
    <div className="space-y-4 pb-24">
      <RhPageHeader
        backTo="/conges"
        title={props.mode === "edit" ? "Modifier la demande" : "Nouvelle demande de congé"}
        subtitle={
          props.mode === "edit"
            ? "Mettre à jour les informations"
            : "Enregistrer une nouvelle absence planifiée"
        }
        crumbs={[
          { label: "Congés", to: "/conges" },
          { label: props.mode === "edit" ? "Modifier" : "Nouveau" },
        ]}
      />

      <Card>
        <CardHeader>
          <CardTitle>Informations</CardTitle>
        </CardHeader>
        <CardContent className="grid gap-4 sm:grid-cols-2">
          <div className="space-y-1.5 sm:col-span-2">
            <Label>Employé</Label>
            <EmployeeSearchSelect
              value={form.employe_id || null}
              onChange={(id) => setForm((f) => ({ ...f, employe_id: id ?? "" }))}
            />
          </div>
          <div className="space-y-1.5 sm:col-span-2">
            <Label>Type</Label>
            <Select value={form.type} onValueChange={(v) => setForm((f) => ({ ...f, type: v }))}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {TYPES_CONGE.map((t) => (
                  <SelectItem key={t.value} value={t.value}>
                    {t.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-1.5">
            <Label>Date de début</Label>
            <Input
              type="date"
              value={form.date_debut}
              onChange={(e) => setForm((f) => ({ ...f, date_debut: e.target.value }))}
            />
          </div>
          <div className="space-y-1.5">
            <Label>Date de fin</Label>
            <Input
              type="date"
              value={form.date_fin}
              onChange={(e) => setForm((f) => ({ ...f, date_fin: e.target.value }))}
            />
          </div>
          <div className="space-y-1.5 sm:col-span-2">
            <Label>Statut</Label>
            <Select
              value={form.statut}
              onValueChange={(v) => setForm((f) => ({ ...f, statut: v }))}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {STATUTS_CONGE.map((s) => (
                  <SelectItem key={s.value} value={s.value}>
                    {s.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-1.5 sm:col-span-2">
            <Label>Motif</Label>
            <Textarea
              value={form.motif ?? ""}
              onChange={(e) => setForm((f) => ({ ...f, motif: e.target.value }))}
              rows={3}
            />
          </div>
        </CardContent>
      </Card>

      <div className="flex flex-wrap justify-end gap-2">
        <Button variant="outline" onClick={() => navigate({ to: "/conges" })}>
          Annuler
        </Button>
        {props.mode === "create" && (
          <Button
            variant="secondary"
            onClick={() => submit(true)}
            disabled={saveMutation.isPending}
          >
            Enregistrer et nouveau
          </Button>
        )}
        <Button onClick={() => submit(false)} disabled={saveMutation.isPending}>
          {props.mode === "edit" ? "Enregistrer les modifications" : "Enregistrer"}
        </Button>
      </div>
    </div>
  );
}
