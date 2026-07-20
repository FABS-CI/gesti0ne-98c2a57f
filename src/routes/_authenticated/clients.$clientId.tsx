import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { useQueryClient, useSuspenseQuery } from "@tanstack/react-query";
import { ArrowLeft, FileDown, FileText, Mail, MessageCircle, Pencil, PlusCircle, Wallet, Eye } from "lucide-react";
import { toast } from "sonner";

import { TYPE_COLOR } from "@/lib/company";
import { formatFCFA } from "@/lib/format";
import { downloadBlob, fileNameFor } from "@/lib/pdf/fabsTemplates";
import { buildEtatCompteClientPDF } from "@/lib/pdf/etat-compte-builder";
import { buildClientHistoriquePDF } from "@/lib/pdf/client-historique-builder";
import { ClientSoldeDialog } from "@/components/clients/detail/ClientSoldeDialog";

import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { usePermissions } from "@/hooks/use-permissions";
import { ClientEditSheet } from "@/components/clients/ClientEditSheet";
import { Kpi, ReportANouveauKpi } from "@/components/clients/detail/shared";
import { ClientInfosTab } from "@/components/clients/detail/ClientInfosTab";
import { ClientCommandesTab } from "@/components/clients/detail/ClientCommandesTab";
import { ClientFacturesTab } from "@/components/clients/detail/ClientFacturesTab";
import { ClientPaiementsTab } from "@/components/clients/detail/ClientPaiementsTab";
import { ClientStatsTab } from "@/components/clients/detail/ClientStatsTab";
import { ClientAuditTab } from "@/components/clients/detail/ClientAuditTab";
import {
  ClientProformasTab,
  ClientBLTab,
  ClientAvoirsTab,
  ClientLivraisonsTab,
} from "@/components/clients/detail/ClientSimpleTabs";
import { Section } from "@/components/ui/section";
import { SkeletonTable, SkeletonKpiRow } from "@/components/ui/skeletons";
import {
  clientQO,
  clientCountsQO,
  clientCommandesQO,
  clientFacturesQO,
  clientProformasQO,
  clientBLQO,
  clientAvoirsQO,
  clientPaiementsQO,
  clientLivraisonsQO,
} from "@/lib/client-detail-queries";
import { useIdlePrefetch } from "@/hooks/use-idle-prefetch";

export const Route = createFileRoute("/_authenticated/clients/$clientId")({
  component: ClientDetailPage,
});

function ClientDetailPage() {
  const { clientId } = Route.useParams();
  return (
    <Section fallback={<div className="py-16 text-center text-muted-foreground">Chargement…</div>}>
      <ClientDetailInner clientId={clientId} />
    </Section>
  );
}

function ClientDetailInner({ clientId }: { clientId: string }) {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [editOpen, setEditOpen] = useState(false);
  const [generating, setGenerating] = useState(false);
  const [historiqueBusy, setHistoriqueBusy] = useState(false);
  const [soldeOpen, setSoldeOpen] = useState(false);
  const { has } = usePermissions();
  const canSeeSolde = has("clients.voir_ca");

  const { data: client } = useSuspenseQuery(clientQO(clientId));
  const { data: factures } = useSuspenseQuery(clientFacturesQO(clientId));
  const { data: counts } = useSuspenseQuery(clientCountsQO(clientId));
  // Précharge en idle les onglets les plus consultés
  useEffect(() => {
    const w = window as Window & {
      requestIdleCallback?: (cb: () => void, opts?: { timeout: number }) => number;
      cancelIdleCallback?: (id: number) => void;
    };
    const run = () => {
      queryClient.prefetchQuery(clientCommandesQO(clientId));
      queryClient.prefetchQuery(clientPaiementsQO(clientId));
      queryClient.prefetchQuery(clientProformasQO(clientId));
    };
    if (typeof w.requestIdleCallback === "function") {
      const id = w.requestIdleCallback(run, { timeout: 2000 });
      return () => w.cancelIdleCallback?.(id);
    }
    const id = window.setTimeout(run, 400);
    return () => window.clearTimeout(id);
  }, [clientId, queryClient]);

  const prefetchOnHover = (fn: () => void) => ({ onMouseEnter: fn, onFocus: fn });

  const type = TYPE_COLOR[client.type_client];
  const encoursFactures = factures.reduce((s, f) => {
    if (f.statut === "annulee" || f.statut === "avoir") return s;
    const solde = Number(f.montant_total) - Number(f.montant_paye);
    return solde > 0 ? s + solde : s;
  }, 0);
  const soldeClient = Number(client.solde) || 0;
  const encours = Math.max(encoursFactures, soldeClient > 0 ? soldeClient : 0);

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
    setGenerating(true);
    try {
      const blob = await buildEtatCompteClientPDF({
        clientId: client.client_id,
        clientNom: client.nom,
        clientTel: client.telephone,
        representant: client.representant,
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
    setHistoriqueBusy(true);
    try {
      // Historique PDF a besoin des relations complètes — récupère à la volée
      const [commandes, paiements, proformas, bl, avoirs, livraisons] = await Promise.all([
        queryClient.ensureQueryData(clientCommandesQO(clientId)),
        queryClient.ensureQueryData(clientPaiementsQO(clientId)),
        queryClient.ensureQueryData(clientProformasQO(clientId)),
        queryClient.ensureQueryData(clientBLQO(clientId)),
        queryClient.ensureQueryData(clientAvoirsQO(clientId)),
        queryClient.ensureQueryData(clientLivraisonsQO(clientId)),
      ]);
      const blob = await buildClientHistoriquePDF(client, {
        commandes,
        factures,
        paiements,
        proformas,
        bons_livraison: bl,
        avoirs,
        livraisons,
      });
      downloadBlob(blob, fileNameFor(`HISTORIQUE_${client.reference}`, client.nom));
      toast.success("Historique généré");
    } catch (e) {
      toast.error("Échec de la génération de l'historique");
      console.error(e);
    } finally {
      setHistoriqueBusy(false);
    }
  }

  const rel = { factures, commandes: [], paiements: [], bons_livraison: [] };

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
          <Button variant="outline" onClick={() => setSoldeOpen(true)}>
            <Eye className="mr-2 h-4 w-4" /> Consulter le solde
          </Button>
          <Button
            variant="secondary"
            onClick={() =>
              navigate({ to: "/paiements/nouveau", search: { clientId: client.client_id } })
            }
          >
            <Wallet className="mr-2 h-4 w-4" /> Imputer un paiement
          </Button>
          <Button variant="outline" onClick={handleEtatCompte} disabled={generating}>
            <FileDown className="mr-2 h-4 w-4" />
            {generating ? "Génération…" : "État de compte (PDF)"}
          </Button>
          <Button variant="outline" onClick={handleHistoriquePdf} disabled={historiqueBusy}>
            <FileText className="mr-2 h-4 w-4" />
            {historiqueBusy ? "Génération…" : "Historique PDF"}
          </Button>
          <Badge style={{ backgroundColor: type?.bg ?? "#CFD8DC", color: type?.color ?? "#0A2540" }}>
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
      <ClientSoldeDialog open={soldeOpen} onOpenChange={setSoldeOpen} client={client} rel={rel as never} />

      {/* KPIs */}
      <Section fallback={<SkeletonKpiRow count={canSeeSolde ? 8 : 4} />}>
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
          <Kpi label="Commandes" value={String(counts.commandes)} />
          <Kpi label="Factures" value={String(factures.length)} />
          <Kpi label="Bons de livraison" value={String(counts.bl)} />
        </div>
      </Section>

      {/* Tabs */}
      <Tabs defaultValue="infos">
        <TabsList className="flex-wrap">
          <TabsTrigger value="infos">Informations</TabsTrigger>
          <TabsTrigger
            value="commandes"
            {...prefetchOnHover(() => queryClient.prefetchQuery(clientCommandesQO(clientId)))}
          >
            Commandes ({counts.commandes})
          </TabsTrigger>
          <TabsTrigger
            value="proformas"
            {...prefetchOnHover(() => queryClient.prefetchQuery(clientProformasQO(clientId)))}
          >
            Proformas ({counts.proformas})
          </TabsTrigger>
          <TabsTrigger value="factures">Factures ({factures.length})</TabsTrigger>
          <TabsTrigger
            value="bl"
            {...prefetchOnHover(() => queryClient.prefetchQuery(clientBLQO(clientId)))}
          >
            BL ({counts.bl})
          </TabsTrigger>
          <TabsTrigger
            value="paiements"
            {...prefetchOnHover(() => queryClient.prefetchQuery(clientPaiementsQO(clientId)))}
          >
            Paiements
          </TabsTrigger>
          <TabsTrigger
            value="livraisons"
            {...prefetchOnHover(() => queryClient.prefetchQuery(clientLivraisonsQO(clientId)))}
          >
            Livraisons
          </TabsTrigger>
          <TabsTrigger
            value="avoirs"
            {...prefetchOnHover(() => queryClient.prefetchQuery(clientAvoirsQO(clientId)))}
          >
            Avoirs ({counts.avoirs})
          </TabsTrigger>
          <TabsTrigger value="stats">Statistiques</TabsTrigger>
          <TabsTrigger value="audit">Audit</TabsTrigger>
        </TabsList>

        <TabsContent value="infos" className="space-y-4" data-testid="client-readonly-card">
          <ClientInfosTab client={client} typeLabel={type?.label ?? client.type_client} />
        </TabsContent>

        <TabsContent value="commandes">
          <Section fallback={<SkeletonTable rows={6} cols={5} />}>
            <LazyCommandesTab clientId={clientId} />
          </Section>
        </TabsContent>

        <TabsContent value="proformas">
          <Section fallback={<SkeletonTable rows={6} cols={5} />}>
            <LazyProformasTab clientId={clientId} />
          </Section>
        </TabsContent>

        <TabsContent value="factures">
          <ClientFacturesTab factures={factures} />
        </TabsContent>

        <TabsContent value="bl">
          <Section fallback={<SkeletonTable rows={6} cols={6} />}>
            <LazyBLTab clientId={clientId} />
          </Section>
        </TabsContent>

        <TabsContent value="paiements">
          <Section fallback={<SkeletonTable rows={6} cols={5} />}>
            <LazyPaiementsTab clientId={clientId} />
          </Section>
        </TabsContent>

        <TabsContent value="livraisons">
          <Section fallback={<SkeletonTable rows={6} cols={5} />}>
            <LazyLivraisonsTab clientId={clientId} />
          </Section>
        </TabsContent>

        <TabsContent value="avoirs">
          <Section fallback={<SkeletonTable rows={6} cols={5} />}>
            <LazyAvoirsTab clientId={clientId} />
          </Section>
        </TabsContent>

        <TabsContent value="stats" className="space-y-4">
          <ClientStatsTab factures={factures} commandesCount={counts.commandes} />
        </TabsContent>

        <TabsContent value="audit" className="space-y-3">
          <ClientAuditTab clientId={clientId} />
        </TabsContent>
      </Tabs>
    </div>
  );
}

/* ---------- Lazy tab wrappers (Suspense-ready) ---------- */

function LazyCommandesTab({ clientId }: { clientId: string }) {
  const { data } = useSuspenseQuery(clientCommandesQO(clientId));
  return <ClientCommandesTab commandes={data} />;
}
function LazyProformasTab({ clientId }: { clientId: string }) {
  const { data } = useSuspenseQuery(clientProformasQO(clientId));
  return <ClientProformasTab proformas={data} />;
}
function LazyBLTab({ clientId }: { clientId: string }) {
  const { data } = useSuspenseQuery(clientBLQO(clientId));
  return <ClientBLTab bons_livraison={data} />;
}
function LazyPaiementsTab({ clientId }: { clientId: string }) {
  const { data } = useSuspenseQuery(clientPaiementsQO(clientId));
  return <ClientPaiementsTab paiements={data} />;
}
function LazyLivraisonsTab({ clientId }: { clientId: string }) {
  const { data } = useSuspenseQuery(clientLivraisonsQO(clientId));
  return <ClientLivraisonsTab livraisons={data} />;
}
function LazyAvoirsTab({ clientId }: { clientId: string }) {
  const { data } = useSuspenseQuery(clientAvoirsQO(clientId));
  return <ClientAvoirsTab avoirs={data} />;
}
