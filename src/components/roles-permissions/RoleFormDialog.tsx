import { useMemo, useState } from "react";
import { Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useSaveRole } from "@/hooks/use-roles-permissions";
import type { RbacRole } from "@/lib/rbac-api";

interface Props {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  role?: RbacRole | null;
  roles: RbacRole[];
}

export function RoleFormDialog({ open, onOpenChange, role, roles }: Props) {
  const isEdit = !!role;
  const [code, setCode] = useState(role?.code ?? "");
  const [libelle, setLibelle] = useState(role?.libelle ?? "");
  const [description, setDescription] = useState(role?.description ?? "");
  const [hierite, setHierite] = useState<string>(role?.hierite_de ?? "none");

  useMemo(() => {
    if (open) {
      setCode(role?.code ?? "");
      setLibelle(role?.libelle ?? "");
      setDescription(role?.description ?? "");
      setHierite(role?.hierite_de ?? "none");
    }
  }, [open, role]);

  const save = useSaveRole(isEdit, role, () => onOpenChange(false));

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{isEdit ? `Éditer ${role?.libelle}` : "Nouveau rôle"}</DialogTitle>
        </DialogHeader>
        <div className="space-y-3">
          <div>
            <label className="text-sm font-medium">Libellé</label>
            <Input
              value={libelle}
              onChange={(e) => setLibelle(e.target.value)}
              placeholder="Ex : Chef de projet"
            />
          </div>
          {!isEdit && (
            <div>
              <label className="text-sm font-medium">Code (identifiant unique)</label>
              <Input
                value={code}
                onChange={(e) => setCode(e.target.value)}
                placeholder="ex: chef_projet"
              />
            </div>
          )}
          <div>
            <label className="text-sm font-medium">Description</label>
            <Textarea
              value={description ?? ""}
              onChange={(e) => setDescription(e.target.value)}
              rows={2}
            />
          </div>
          <div>
            <label className="text-sm font-medium">Hérite du rôle</label>
            <Select value={hierite} onValueChange={setHierite}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="none">— Aucun —</SelectItem>
                {roles
                  .filter((r) => r.role_id !== role?.role_id)
                  .map((r) => (
                    <SelectItem key={r.role_id} value={r.role_id}>
                      {r.libelle}
                    </SelectItem>
                  ))}
              </SelectContent>
            </Select>
            <p className="mt-1 text-xs text-muted-foreground">
              L'héritage cumule automatiquement les permissions du rôle parent.
            </p>
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Annuler
          </Button>
          <Button
            onClick={() =>
              save.mutate({
                code,
                libelle,
                description: description || null,
                hierite_de: hierite === "none" ? null : hierite,
              })
            }
            disabled={!libelle || (!isEdit && !code) || save.isPending}
          >
            {save.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
            {isEdit ? "Enregistrer" : "Créer"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
