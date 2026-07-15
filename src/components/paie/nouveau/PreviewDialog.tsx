import { FileDown } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";

interface Props {
  previewUrl: string | null;
  employeName?: string;
  onClose: () => void;
  onDownload: () => void;
}

export function PreviewDialog({ previewUrl, employeName, onClose, onDownload }: Props) {
  return (
    <Dialog open={!!previewUrl} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-w-5xl h-[85vh] flex flex-col">
        <DialogHeader>
          <DialogTitle>Aperçu bulletin de paie — {employeName}</DialogTitle>
        </DialogHeader>
        {previewUrl && (
          <iframe
            title="Aperçu PDF bulletin"
            src={previewUrl}
            className="flex-1 w-full rounded-md border"
          />
        )}
        <div className="flex justify-end gap-2">
          <Button variant="outline" onClick={onClose}>
            Fermer
          </Button>
          <Button onClick={onDownload}>
            <FileDown className="mr-2 h-4 w-4" /> Télécharger
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
