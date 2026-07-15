import { Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { ExerciceStatut } from "@/contexts/ExerciceContext";
import { STATUT_LABEL, type EditingExercice } from "./exercices-shared";

type Props = {
  editing: EditingExercice | null;
  setEditing: (e: EditingExercice | null) => void;
  onSave: () => void;
  saving: boolean;
};

export function EditExerciceDialog({ editing, setEditing, onSave, saving }: Props) {
  return (
    <Dialog open={!!editing} onOpenChange={(o) => !o && setEditing(null)}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Modifier l'exercice</DialogTitle>
          <DialogDescription>
            Ajustez le code, les dates ou le statut. Réservé au super admin.
          </DialogDescription>
        </DialogHeader>
        {editing && (
          <div className="space-y-3">
            <div>
              <Label>Code</Label>
              <Input
                value={editing.code}
                onChange={(e) => setEditing({ ...editing, code: e.target.value })}
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <Label>Date début</Label>
                <Input
                  type="date"
                  value={editing.date_debut}
                  onChange={(e) => setEditing({ ...editing, date_debut: e.target.value })}
                />
              </div>
              <div>
                <Label>Date fin</Label>
                <Input
                  type="date"
                  value={editing.date_fin}
                  onChange={(e) => setEditing({ ...editing, date_fin: e.target.value })}
                />
              </div>
            </div>
            <div>
              <Label>Statut</Label>
              <Select
                value={editing.statut}
                onValueChange={(v) => setEditing({ ...editing, statut: v as ExerciceStatut })}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {(Object.keys(STATUT_LABEL) as ExerciceStatut[]).map((s) => (
                    <SelectItem key={s} value={s}>
                      {STATUT_LABEL[s]}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
        )}
        <DialogFooter>
          <Button variant="outline" onClick={() => setEditing(null)}>
            Annuler
          </Button>
          <Button disabled={saving || !editing} onClick={onSave}>
            {saving && <Loader2 className="mr-1 h-4 w-4 animate-spin" />}
            Enregistrer
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
