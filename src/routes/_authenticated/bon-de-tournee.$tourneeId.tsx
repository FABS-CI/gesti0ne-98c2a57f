import { createFileRoute, Link, useParams } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { ArrowLeft, FileDown, Printer } from "lucide-react";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
const STATUT_META: Record<string, { label: string }> = {
  en_attente: { label: "En attente" },
  assignee: { label: "Assignée" },
  chargee: { label: "Chargée" },
  en_route: { label: "En route" },
  livree: { label: "Livrée" },
  deposee_gare: { label: "Déposée gare" },
  arrivee_destination: { label: "Arrivée destination" },
  retiree_client: { label: "Retirée client" },
  anomalie: { label: "Anomalie" },
  retour: { label: "Retour" },
  annulee: { label: "Annulée" },
};
import { exportListePDF } from "@/lib/pdf/exportListe";
import { useIsEmbed } from "@/hooks/use-is-embed";
import {
  BonDocumentHeader,
  BonDocumentFooter,
  BonDocumentPage,
} from "@/components/pdf/BonDocumentChrome";

export const Route = createFileRoute("/_authenticated/bon-de-tournee/$tourneeId")({
  component: FeuilleTourneePage,
});

type TourneeInfo = {
  tournee_id: string;
  reference: string;
  date_tournee: string | null;
  responsable_nom: string | null;
  chauffeur_nom: string | null;
  statut: string;
  notes: string | null;
  vehicule_id: string | null;
};

type LigneFeuille = {
  livraison_id: string;
  commande_reference: string | null;
  client_nom: string | null;
  ville_livraison: string | null;
  gare_nom: string | null;
  type_livraison: string | null;
  nb_cartons: number;
  quantite_commandee: number;
  statut: string;
  livreur_nom: string | null;
};

type ColisLigne = {
  colis_id: string;
  reference: string | null;
  destinataire: string | null;
  client_nom: string | null;
  ville_livraison: string | null;
  quartier: string | null;
  nb_cartons: number;
  livreur_nom: string | null;
};

async function fetchFeuille(tourneeId: string): Promise<{
  t: TourneeInfo | null;
  vehicule: string;
  lignes: LigneFeuille[];
  colis: ColisLigne[];
}> {
  const { data: t } = await supabase
    .from("tournees")
    .select(
      "tournee_id, reference, date_tournee, responsable_nom, chauffeur_nom, statut, notes, vehicule_id",
    )
    .eq("tournee_id", tourneeId)
    .maybeSingle();

  let vehicule = "—";
  if (t?.vehicule_id) {
    const { data: v } = await supabase
      .from("vehicules")
      .select("immatriculation, marque, modele")
      .eq("vehicule_id", t.vehicule_id)
      .maybeSingle();
    if (v)
      vehicule = `${v.immatriculation ?? ""} ${v.marque ?? ""} ${v.modele ?? ""}`.trim() || "—";
  }

  const { data: rows } = await supabase
    .from("livraisons_commande")
    .select(
      "livraison_id, statut, type_livraison, gare_nom, ville_livraison, nb_cartons, quantite_commandee, commandes:commande_id(reference, client_nom), livreurs:livreur_id(nom)",
    )
    .eq("tournee_id", tourneeId)
    .order("ville_livraison", { ascending: true });

  const lignes: LigneFeuille[] = (
    (rows ?? []) as unknown as Array<{
      livraison_id: string;
      statut: string;
      type_livraison: string | null;
      gare_nom: string | null;
      ville_livraison: string | null;
      nb_cartons: number;
      quantite_commandee: number;
      commandes: { reference: string | null; client_nom: string | null } | null;
      livreurs: { nom: string | null } | null;
    }>
  ).map((r) => ({
    livraison_id: r.livraison_id,
    commande_reference: r.commandes?.reference ?? null,
    client_nom: r.commandes?.client_nom ?? null,
    ville_livraison: r.ville_livraison,
    gare_nom: r.gare_nom,
    type_livraison: r.type_livraison,
    nb_cartons: r.nb_cartons,
    quantite_commandee: r.quantite_commandee,
    statut: r.statut,
    livreur_nom: r.livreurs?.nom ?? null,
  }));

  // Colis affectés à la tournée (avec client via commande)
  const { data: colisRows } = await supabase
    .from("colis")
    .select(
      "colis_id, reference, destinataire, ville_livraison, quartier, nb_cartons, livreur_nom, commandes:commande_id(client_nom)",
    )
    .eq("tournee_id" as never, tourneeId as never)
    .order("ville_livraison", { ascending: true });

  const colis: ColisLigne[] = (
    (colisRows ?? []) as unknown as Array<{
      colis_id: string;
      reference: string | null;
      destinataire: string | null;
      ville_livraison: string | null;
      quartier: string | null;
      nb_cartons: number | null;
      livreur_nom: string | null;
      commandes: { client_nom: string | null } | null;
    }>
  ).map((r) => ({
    colis_id: r.colis_id,
    reference: r.reference,
    destinataire: r.destinataire,
    client_nom: r.commandes?.client_nom ?? null,
    ville_livraison: r.ville_livraison,
    quartier: r.quartier,
    nb_cartons: r.nb_cartons ?? 0,
    livreur_nom: r.livreur_nom,
  }));

  return { t: t as TourneeInfo | null, vehicule, lignes, colis };
}

function FeuilleTourneePage() {
  const { tourneeId } = useParams({ from: "/_authenticated/bon-de-tournee/$tourneeId" });
  const isEmbed = useIsEmbed();
  const { data, isLoading } = useQuery({
    queryKey: ["feuille-tournee", tourneeId],
    queryFn: () => fetchFeuille(tourneeId),
  });

  if (isLoading || !data)
    return <div className="p-8 text-sm text-muted-foreground">Chargement…</div>;
  const { t, vehicule, lignes, colis } = data;
  if (!t) return <div className="p-8 text-sm text-muted-foreground">Tournée introuvable.</div>;

  // Règle métier : 1 référence de colis = 1 carton physique.
  const totalCartons = lignes.length;
  const totalQte = lignes.reduce((s, l) => s + (l.quantite_commandee || 0), 0);
  const totalCartonsColis = colis.length;

  const handlePdf = () => {
    exportListePDF({
      titre: `Bon de tournée ${t.reference}`,
      filtres: [
        `Date : ${t.date_tournee ?? "—"}`,
        `Responsable : ${t.responsable_nom ?? "—"}`,
        `Chauffeur : ${t.chauffeur_nom ?? "—"}`,
        `Véhicule : ${vehicule}`,
      ],
      colonnes: [
        "N° Cmd",
        "Client",
        "Ville",
        "Gare",
        "Type",
        "Cartons",
        "Qté",
        "Statut",
        "Livreur",
        "Émargement",
      ],
      lignes: lignes.map((l) => [
        l.commande_reference ?? "—",
        l.client_nom ?? "—",
        l.ville_livraison ?? "—",
        l.gare_nom ?? "—",
        l.type_livraison ?? "—",
        1,
        l.quantite_commandee,
        STATUT_META[l.statut]?.label ?? l.statut,
        l.livreur_nom ?? "—",
        "",
      ]),
      filename: `bon-tournee-${t.reference}`,
    });
  };

  return (
    <div className="min-h-dvh bg-background">
      {!isEmbed && (
        <div className="print:hidden flex items-center justify-between border-b p-4">
          <Button asChild variant="ghost" size="sm">
            <Link to="/tournees">
              <ArrowLeft className="h-4 w-4 mr-1" /> Retour
            </Link>
          </Button>
          <div className="flex gap-2">
            <Button variant="outline" size="sm" onClick={() => window.print()}>
              <Printer className="h-4 w-4 mr-2" /> Imprimer
            </Button>
            <Button size="sm" onClick={handlePdf}>
              <FileDown className="h-4 w-4 mr-2" /> PDF
            </Button>
          </div>
        </div>
      )}

      <BonDocumentPage>
        <BonDocumentHeader
          title="Bon de tournée"
          reference={t.reference}
          date={t.date_tournee ?? ""}
        />

        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4 text-xs">
          <div>
            <span className="text-muted-foreground">Responsable :</span>
            <br />
            <b>{t.responsable_nom ?? "—"}</b>
          </div>
          <div>
            <span className="text-muted-foreground">Chauffeur :</span>
            <br />
            <b>{t.chauffeur_nom ?? "—"}</b>
          </div>
          <div>
            <span className="text-muted-foreground">Véhicule :</span>
            <br />
            <b>{vehicule}</b>
          </div>
          <div>
            <span className="text-muted-foreground">Statut :</span>
            <br />
            <b>{t.statut}</b>
          </div>
        </div>

        <table className="w-full border-collapse text-xs">
          <thead>
            <tr className="bg-slate-100">
              <th className="border p-1 text-left">N° Cmd</th>
              <th className="border p-1 text-left">Client</th>
              <th className="border p-1 text-left">Ville</th>
              <th className="border p-1 text-left">Gare</th>
              <th className="border p-1 text-left">Type</th>
              <th className="border p-1 text-right">Cartons</th>
              <th className="border p-1 text-right">Qté</th>
              <th className="border p-1 text-left">Statut</th>
              <th className="border p-1 text-left w-32">Émargement</th>
            </tr>
          </thead>
          <tbody>
            {lignes.length === 0 ? (
              <tr>
                <td colSpan={9} className="border p-3 text-center text-muted-foreground">
                  Aucune livraison
                </td>
              </tr>
            ) : (
              lignes.map((l) => (
                <tr key={l.livraison_id}>
                  <td className="border p-1 font-mono">{l.commande_reference ?? "—"}</td>
                  <td className="border p-1">{l.client_nom ?? "—"}</td>
                  <td className="border p-1">{l.ville_livraison ?? "—"}</td>
                  <td className="border p-1">{l.gare_nom ?? "—"}</td>
                  <td className="border p-1">{l.type_livraison ?? "—"}</td>
                  <td className="border p-1 text-right">1</td>
                  <td className="border p-1 text-right">{l.quantite_commandee}</td>
                  <td className="border p-1">{STATUT_META[l.statut]?.label ?? l.statut}</td>
                  <td className="border p-1">&nbsp;</td>
                </tr>
              ))
            )}
          </tbody>
          <tfoot>
            <tr className="bg-slate-50 font-semibold">
              <td className="border p-1" colSpan={5}>
                Total ({lignes.length} livraison{lignes.length > 1 ? "s" : ""})
              </td>
              <td className="border p-1 text-right">{totalCartons}</td>
              <td className="border p-1 text-right">{totalQte}</td>
              <td className="border p-1" colSpan={2}></td>
            </tr>
          </tfoot>
        </table>

        {t.notes && (
          <div className="mt-4 text-xs">
            <b>Notes :</b>
            <p className="whitespace-pre-wrap">{t.notes}</p>
          </div>
        )}

        {colis.length > 0 && (
          <div className="mt-6">
            <div className="flex items-baseline justify-between mb-1">
              <h3 className="text-sm font-semibold">Colis affectés ({colis.length})</h3>
              <span className="text-xs text-muted-foreground">
                Total cartons : <b>{totalCartonsColis}</b>
              </span>
            </div>
            <table className="w-full border-collapse text-xs">
              <thead>
                <tr className="bg-slate-100">
                  <th className="border p-1 text-left">Réf. colis</th>
                  <th className="border p-1 text-left">Client</th>
                  <th className="border p-1 text-left">Destinataire</th>
                  <th className="border p-1 text-left">Ville / Quartier</th>
                  <th className="border p-1 text-left">Livreur</th>
                  <th className="border p-1 text-right">Cartons</th>
                  <th className="border p-1 text-left w-24">Émargement</th>
                </tr>
              </thead>
              <tbody>
                {colis.map((c) => (
                  <tr key={c.colis_id}>
                    <td className="border p-1 font-mono">{c.reference ?? "—"}</td>
                    <td className="border p-1">{c.client_nom ?? "—"}</td>
                    <td className="border p-1">{c.destinataire ?? "—"}</td>
                    <td className="border p-1">
                      {[c.ville_livraison, c.quartier].filter(Boolean).join(" · ") || "—"}
                    </td>
                    <td className="border p-1">{c.livreur_nom ?? "—"}</td>
                    <td className="border p-1 text-right">1</td>
                    <td className="border p-1">&nbsp;</td>
                  </tr>
                ))}
              </tbody>
              <tfoot>
                <tr className="bg-slate-50 font-semibold">
                  <td className="border p-1" colSpan={5}>
                    Total ({colis.length} colis)
                  </td>
                  <td className="border p-1 text-right">{totalCartonsColis}</td>
                  <td className="border p-1"></td>
                </tr>
              </tfoot>
            </table>
          </div>
        )}

        <div className="grid grid-cols-2 gap-8 mt-12 text-xs">
          <div>
            <p className="text-muted-foreground">Signature Responsable</p>
            <div className="border-t mt-16"></div>
          </div>
          <div>
            <p className="text-muted-foreground">Signature Chauffeur</p>
            <div className="border-t mt-16"></div>
          </div>
        </div>
        <BonDocumentFooter documentType="Bon de tournée" />
      </BonDocumentPage>
    </div>
  );
}
