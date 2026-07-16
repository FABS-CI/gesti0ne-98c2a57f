import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { ArrowLeft, FileDown, FileText, Mail, MessageCircle, Pencil, PlusCircle, Wallet, Eye } from "lucide-react";
import { toast } from "sonner";

import { useClientDetail } from "@/hooks/use-client-detail";
import { buildEtatCompteLignes } from "@/lib/client-detail-helpers";
import { TYPE_COLOR } from "@/lib/company";
import { formatFCFA } from "@/lib/format";
import { generateEtatCompteClientPDF, downloadBlob, fileNameFor } from "@/lib/pdf/fabsTemplates";
import { buildClientHistoriquePDF } from "@/lib/pdf/client-historique-builder";
import { ClientSoldeDialog } from "@/components/clients/detail/ClientSoldeDialog";

import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { usePermissions } from "@/hooks/use-permissions";
import { ClientEditSheet } from "@/components/clients/ClientEditSheet";
import { ClientHistoriqueTab } from "@/components/clients/ClientHistoriqueTab";
import { Kpi, ReportANouveauKpi } from "@/components/clients/detail/shared";
import { ClientInfosTab } from "@/components/clients/detail/ClientInfosTab";
import { ClientCommandesTab } from "@/components/clients/detail/ClientCommandesTab";
import { ClientFacturesTab } from "@/components/clients/detail/ClientFacturesTab";
import { ClientPaiementsTab } from "@/components/clients/detail/ClientPaiementsTab";
import { ClientCompteTab } from "@/components/clients/detail/ClientCompteTab";
import { ClientStatsTab } from "@/components/clients/detail/ClientStatsTab";
import { ClientAuditTab } from "@/components/clients/detail/ClientAuditTab";
import {
  ClientProformasTab,
  ClientBLTab,
  ClientAvoirsTab,
  ClientLivraisonsTab,
} from "@/components/clients/detail/ClientSimpleTabs";

export const Route = createFileRoute("/_authenticated/clients/$clientId")({
  component: ClientDetailPage,
});

function ClientDetailPage() {
  const { clientId } = Route.useParams();
  const navigate = useNavigate();
  const [editOpen, setEditOpen] = useState(false);
  const [generating, setGenerating] = useState(false);
  const [historiqueBusy, setHistoriqueBusy] = useState(false);
  const [soldeOpen, setSoldeOpen] = useState(false);
  const { has } = usePermissions();
  const canSeeSolde = has("clients.voir_ca");

  const { client, rel, isLoading } = useClientDetail(clientId);

  if (isLoading) return <div className="py-16 text-center text-muted-foreground">Chargement…</div>;
  if (!client) {
    return (
      <div className="space-y-4 py-16 text-center">
        <p className="text-muted-foreground">Client introuvable.</p>
        <Button variant="outline" onClick={() => navigate({ to: "/clients" })}>
          Retour aux clients
        </Button>
      </div>
    );
  }

  const type = TYPE_COLOR[client.type_client];
  const factures = rel?.factures ?? [];
  const caFacture = factures.reduce((s, f) => s + Number(f.montant_total), 0);
  const totalPaye = (rel?.paiements ?? []).reduce((s, p) => s + Number(p.montant), 0);
  const encours = factures.reduce((s, f) => {
    if (f.statut === "annulee" || f.statut === "avoir") return s;
    const solde = Number(f.montant_total) - Number(f.montant_paye);
    return solde > 0 ? s + solde : s;
  }, 0);
  const plafond = Number(client.plafond_credit) || 0;
  const tauxCredit = plafond > 0 ? Math.min(100, Math.round((encours / plafond) * 100)) : 0;
  const facturesImpayees = factures.filter(
    (f) =>
      f.statut !== "annulee" &&
      f.statut !== "avoir" &&
      Number(f.montant_total) - Number(f.montant_paye) > 0,
  );
  const creditDisponible = Math.max(0, plafond - encours);

  const statutEnrichi = !client.actif
    ? { label: "Inactif", cls: "bg-muted text-muted-foreground" }
    : facturesImpayees.length > 0 && tauxCredit > 90
      ? { label: "Plafond critique", cls: "bg-red-500 text-white" }
      : tauxCredit > 70
        ? { label: "Encours élevé", cls: "bg-amber-500 text-white" }
        : facturesImpayees.length > 0
          ? { label: "Impayés", cls: "bg-orange-500 text-white" }
          : { label: "Actif", cls: "bg-emerald-500 text-white" };

  async function handleEtatCompte() {
    if (!client || !rel) return;
    setGenerating(true);
    try {
      const reference = `EC|${new Date().getFullYear()}|${client.reference}`;
      const blob = await generateEtatCompteClientPDF({
        reference,
        clientNom: client.nom,
        clientTel: client.telephone,
        representant: client.representant,
        lignes: buildEtatCompteLignes(rel),
      });
      downloadBlob(blob, fileNameFor(`ETAT_COMPTE_${client.reference}`, client.nom));
      toast.success("État de compte généré");
    } catch (e) {
      toast.error("Échec de la génération du PDF");
      console.error(e);
    } finally {
      setGenerating(false);
    }
  }

  async function handleHistoriquePdf() {
    if (!client || !rel) return;
    setHistoriqueBusy(true);
    try {
      const blob = await buildClientHistoriquePDF(client, rel);
      downloadBlob(blob, fileNameFor(`HISTORIQUE_${client.reference}`, client.nom));
      toast.success("Historique généré");
    } catch (e) {
      toast.error("Échec de la génération de l'historique");
      console.error(e);
    } finally {
      setHistoriqueBusy(false);
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <Button variant="ghost" size="icon" asChild>
            <Link to="/clients">
              <ArrowLeft className="h-5 w-5" />
            </Link>
          </Button>
          <div>
            <h1 className="text-2xl font-bold">{client.nom}</h1>
            <p className="font-mono text-xs text-muted-foreground">{client.reference}</p>
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Button
            onClick={() =>
              navigate({
                to: "/commandes",
                search: { q: "", statut: "all", clientId: client.client_id },
              })
            }
          >
            <PlusCircle className="mr-2 h-4 w-4" /> Commander
          </Button>
          <Button
            variant="secondary"
            onClick={() =>
              navigate({ to: "/paiements/nouveau", search: { clientId: client.client_id } })
            }
          >
            <Wallet className="mr-2 h-4 w-4" /> Imputer un paiement
          </Button>
          <Button variant="outline" onClick={handleEtatCompte} disabled={generating || !rel}>
            <FileDown className="mr-2 h-4 w-4" />
            {generating ? "Génération…" : "État de compte (PDF)"}
          </Button>
          <Badge
            style={{ backgroundColor: type?.bg ?? "#CFD8DC", color: type?.color ?? "#0A2540" }}
          >
            {type?.label ?? client.type_client}
          </Badge>
          <Badge className={statutEnrichi.cls}>{statutEnrichi.label}</Badge>
        </div>
      </div>

      {/* Actions rapides */}
      <div className="flex flex-wrap gap-2">
        {client.telephone &&
          (() => {
            const waMessage = `Bonjour ${client.nom},`;
            return (
              <Button variant="outline" size="sm" asChild>
                <a
                  href={`https://wa.me/${client.telephone.replace(/[^0-9]/g, "")}?text=${encodeURIComponent(waMessage)}`}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <MessageCircle className="mr-2 h-4 w-4" /> WhatsApp
                </a>
              </Button>
            );
          })()}
        {client.email && (
          <Button variant="outline" size="sm" asChild>
            <a href={`mailto:${client.email}`}>
              <Mail className="mr-2 h-4 w-4" /> Email
            </a>
          </Button>
        )}
        <Button
          size="sm"
          className="bg-orange-500 hover:bg-orange-600 text-white"
          onClick={() => setEditOpen(true)}
        >
          <Pencil className="mr-2 h-4 w-4" /> Modifier
        </Button>
      </div>

      <ClientEditSheet client={client} open={editOpen} onOpenChange={setEditOpen} />

      {/* KPIs */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {canSeeSolde && (
          <>
            <Kpi label="Encours" value={formatFCFA(encours)} accent="text-red-600" />
            <Kpi label="Plafond crédit" value={formatFCFA(plafond)} />
            <Kpi
              label="Utilisation crédit"
              value={
                <div>
                  <div className="text-xl font-bold">{tauxCredit}%</div>
                  <div className="mt-1 h-1.5 w-full rounded-full bg-muted">
                    <div
                      className={`h-1.5 rounded-full ${tauxCredit > 90 ? "bg-red-500" : tauxCredit > 70 ? "bg-amber-500" : "bg-emerald-500"}`}
                      style={{ width: `${tauxCredit}%` }}
                    />
                  </div>
                </div>
              }
            />
            <Kpi label="Solde" value={formatFCFA(client.solde)} />
            <Kpi label="Crédit disponible" value={formatFCFA(creditDisponible)} />
            <ReportANouveauKpi clientId={client.client_id} />
          </>
        )}
        <Kpi label="Commandes" value={String(rel?.commandes.length ?? 0)} />
        <Kpi label="Factures" value={String(rel?.factures.length ?? 0)} />
        <Kpi label="Paiements" value={String(rel?.paiements.length ?? 0)} />
        <Kpi label="Bons de livraison" value={String(rel?.bons_livraison.length ?? 0)} />
      </div>

      {/* Tabs */}
      <Tabs defaultValue="infos">
        <TabsList className="flex-wrap">
          <TabsTrigger value="infos">Informations</TabsTrigger>
          <TabsTrigger value="commandes">Commandes ({rel?.commandes.length ?? 0})</TabsTrigger>
          <TabsTrigger value="proformas">Proformas ({rel?.proformas.length ?? 0})</TabsTrigger>
          <TabsTrigger value="factures">Factures ({rel?.factures.length ?? 0})</TabsTrigger>
          <TabsTrigger value="bl">BL ({rel?.bons_livraison.length ?? 0})</TabsTrigger>
          <TabsTrigger value="paiements">Paiements ({rel?.paiements.length ?? 0})</TabsTrigger>
          <TabsTrigger value="livraisons">Livraisons ({rel?.livraisons.length ?? 0})</TabsTrigger>
          <TabsTrigger value="avoirs">Avoirs ({rel?.avoirs.length ?? 0})</TabsTrigger>
          <TabsTrigger value="stats">Statistiques</TabsTrigger>
          <TabsTrigger value="audit">Audit</TabsTrigger>
        </TabsList>

        <TabsContent value="infos" className="space-y-4" data-testid="client-readonly-card">
          <ClientInfosTab client={client} typeLabel={type?.label ?? client.type_client} />
        </TabsContent>
        <TabsContent value="commandes">
          <ClientCommandesTab commandes={rel?.commandes ?? []} />
        </TabsContent>
        <TabsContent value="proformas">
          <ClientProformasTab proformas={rel?.proformas ?? []} />
        </TabsContent>
        <TabsContent value="factures">
          <ClientFacturesTab factures={rel?.factures ?? []} />
        </TabsContent>
        <TabsContent value="bl">
          <ClientBLTab bons_livraison={rel?.bons_livraison ?? []} />
        </TabsContent>
        <TabsContent value="paiements">
          <ClientPaiementsTab paiements={rel?.paiements ?? []} />
        </TabsContent>
        <TabsContent value="livraisons">
          <ClientLivraisonsTab livraisons={rel?.livraisons ?? []} />
        </TabsContent>
        <TabsContent value="avoirs">
          <ClientAvoirsTab avoirs={rel?.avoirs ?? []} />
        </TabsContent>
        <TabsContent value="stats" className="space-y-4">
          <ClientStatsTab
            factures={rel?.factures ?? []}
            commandesCount={rel?.commandes.length ?? 0}
          />
        </TabsContent>
        <TabsContent value="audit" className="space-y-3">
          <ClientAuditTab clientId={clientId} />
        </TabsContent>
      </Tabs>
    </div>
  );
}
