import { Eye, FileDown, Loader2, Save, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import type { PdfProgress } from "@/hooks/use-pdf-progress";

interface Props {
  pdfProgress: PdfProgress | null;
  onCancelPdf: () => void;
  onCancel: () => void;
  onPreview: () => void;
  onDownload: () => void;
  onSave: () => void;
  canAct: boolean;
  saving: boolean;
}

export function ActionsBar(p: Props) {
  return (
    <div className="fixed inset-x-0 bottom-[calc(56px+env(safe-area-inset-bottom))] md:bottom-0 z-40 flex justify-end gap-2 border-t bg-background/95 p-3 backdrop-blur">
      {p.pdfProgress && (
        <div className="mr-auto flex flex-1 items-center gap-3">
          <div className="min-w-0 flex-1">
            <div className="mb-1 flex justify-between text-xs text-muted-foreground">
              <span className="truncate">{p.pdfProgress.label}</span>
              <span>{p.pdfProgress.pct}%</span>
            </div>
            <Progress value={p.pdfProgress.pct} />
          </div>
          <Button size="sm" variant="destructive" onClick={p.onCancelPdf}>
            <X className="mr-1 h-3 w-3" /> Annuler
          </Button>
        </div>
      )}
      <Button variant="outline" onClick={p.onCancel}>
        <X className="mr-2 h-4 w-4" /> Annuler
      </Button>
      <Button variant="outline" disabled={!p.canAct || !!p.pdfProgress} onClick={p.onPreview}>
        <Eye className="mr-2 h-4 w-4" /> Aperçu PDF
      </Button>
      <Button variant="outline" disabled={!p.canAct || !!p.pdfProgress} onClick={p.onDownload}>
        {p.pdfProgress ? (
          <Loader2 className="mr-2 h-4 w-4 animate-spin" />
        ) : (
          <FileDown className="mr-2 h-4 w-4" />
        )}
        Télécharger PDF
      </Button>
      <Button disabled={!p.canAct || p.saving} onClick={p.onSave}>
        {p.saving ? (
          <Loader2 className="mr-2 h-4 w-4 animate-spin" />
        ) : (
          <Save className="mr-2 h-4 w-4" />
        )}
        Enregistrer
      </Button>
    </div>
  );
}
