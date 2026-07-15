import { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { toast } from "sonner";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { createProduit, type Produit } from "@/lib/produits-api";

type Props = {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  onCreated: (p: Produit) => void;
};

export function QuickCreateProduitDialog({ open, onOpenChange, onCreated }: Props) {
  const [titre, setTitre] = useState("");
  const [categorie, setCategorie] = useState("manuel");
  const [isbn, setIsbn] = useState("");
  const [niveau, setNiveau] = useState("");
  const [matiere, setMatiere] = useState("");
  const [auteur, setAuteur] = useState("");
  const [editeur, setEditeur] = useState("");
  const [prixAchat, setPrixAchat] = useState(0);
  const [prixVente, setPrixVente] = useState(0);
  const [seuil, setSeuil] = useState(10);

  function reset() {
    setTitre("");
    setCategorie("manuel");
    setIsbn("");
    setNiveau("");
    setMatiere("");
    setAuteur("");
    setEditeur("");
    setPrixAchat(0);
    setPrixVente(0);
    setSeuil(10);
  }

  const mutation = useMutation({
    mutationFn: () =>
      createProduit({
        titre: titre.trim(),
        categorie,
        isbn: isbn || null,
        niveau: niveau || null,
        matiere: matiere || null,
        auteur: auteur || null,
        editeur: editeur || null,
        prix_achat: prixAchat,
        prix_vente: prixVente,
        seuil_alerte: seuil,
      }),
    onSuccess: (p) => {
      toast.success("Produit créé");
      reset();
      onCreated(p);
    },
    onError: (e: Error) => toast.error(e.message),
  });

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-xl">
        <DialogHeader>
          <DialogTitle>Nouveau produit</DialogTitle>
        </DialogHeader>
        <div className="grid gap-3 sm:grid-cols-2">
          <div className="sm:col-span-2">
            <Label>Désignation *</Label>
            <Input value={titre} onChange={(e) => setTitre(e.target.value)} />
          </div>
          <div>
            <Label>Catégorie</Label>
            <Select value={categorie} onValueChange={setCategorie}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="manuel">Manuel</SelectItem>
                <SelectItem value="cahier">Cahier</SelectItem>
                <SelectItem value="fourniture">Fourniture</SelectItem>
                <SelectItem value="autre">Autre</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div>
            <Label>ISBN</Label>
            <Input value={isbn} onChange={(e) => setIsbn(e.target.value)} />
          </div>
          <div>
            <Label>Niveau</Label>
            <Input value={niveau} onChange={(e) => setNiveau(e.target.value)} />
          </div>
          <div>
            <Label>Matière</Label>
            <Input value={matiere} onChange={(e) => setMatiere(e.target.value)} />
          </div>
          <div>
            <Label>Auteur</Label>
            <Input value={auteur} onChange={(e) => setAuteur(e.target.value)} />
          </div>
          <div>
            <Label>Éditeur</Label>
            <Input value={editeur} onChange={(e) => setEditeur(e.target.value)} />
          </div>
          <div>
            <Label>Prix achat</Label>
            <Input
              type="number"
              min={0}
              value={prixAchat}
              onChange={(e) => setPrixAchat(Number(e.target.value) || 0)}
            />
          </div>
          <div>
            <Label>Prix vente</Label>
            <Input
              type="number"
              min={0}
              value={prixVente}
              onChange={(e) => setPrixVente(Number(e.target.value) || 0)}
            />
          </div>
          <div>
            <Label>Seuil alerte</Label>
            <Input
              type="number"
              min={0}
              value={seuil}
              onChange={(e) => setSeuil(Number(e.target.value) || 0)}
            />
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Annuler
          </Button>
          <Button
            onClick={() => {
              if (!titre.trim()) {
                toast.error("La désignation est requise");
                return;
              }
              mutation.mutate();
            }}
            disabled={mutation.isPending}
          >
            Créer le produit
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
