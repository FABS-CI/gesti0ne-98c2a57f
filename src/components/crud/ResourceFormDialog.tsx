import type { Dispatch, SetStateAction } from "react";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";

import type { ResourceConfig, Row } from "./resource-manager-types";
import { ResourceFormBody } from "./ResourceFormBody";

type Props = {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  config: ResourceConfig;
  editing: Row | null;
  form: Row;
  setForm: Dispatch<SetStateAction<Row>>;
  lookupData: Record<string, Row[]>;
  defaultSources: Record<string, string>;
  validationErrors: string[];
  isPending: boolean;
  onSubmit: (keepOpen: boolean) => void;
};

export function ResourceFormDialog({
  open,
  onOpenChange,
  config,
  editing,
  form,
  setForm,
  lookupData,
  defaultSources,
  validationErrors,
  isPending,
  onSubmit,
}: Props) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>{editing ? `Modifier ${config.entityLabel}` : config.newLabel}</DialogTitle>
        </DialogHeader>
        <ResourceFormBody
          config={config}
          editing={editing}
          form={form}
          setForm={setForm}
          lookupData={lookupData}
          defaultSources={defaultSources}
          validationErrors={validationErrors}
        />
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Annuler
          </Button>
          {!editing && (
            <Button variant="secondary" onClick={() => onSubmit(true)} disabled={isPending}>
              Enregistrer et nouveau
            </Button>
          )}
          <Button onClick={() => onSubmit(false)} disabled={isPending}>
            {editing ? "Enregistrer" : "Créer"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
