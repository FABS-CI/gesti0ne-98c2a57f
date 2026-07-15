import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Loader2, Package, Phone, MapPin, User, Truck, Calendar } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";

/**
 * Page publique de consultation d'un carton via QR code.
 *
 * - Accessible sans authentification (RPC `get_carton_public` exposée à `anon`).
 * - Rendue hors du layout `_authenticated` : pas d'AppShell, pas de redirect vers /auth.
 * - N'affiche AUCUNE donnée financière (prix, remises, coûts, marges).
 */
export const Route = createFileRoute("/carton/$colisId")({
  ssr: false,
  component: CartonPublicPage,
  head: () => ({
    meta: [
      { title: "Suivi du carton — FABS-CI" },
      {
        name: "description",
        content: "Consultation publique des informations logistiques d'un carton.",
      },
      { name: "robots", content: "noindex, nofollow" },
    ],
  }),
});

type CartonPublic = {
  colis_id: string;
  reference_colis: string;
  numero_carton: number | null;
  nb_cartons: number | null;
  bl_reference: string | null;
  bl_statut: string | null;
  commande_reference: string | null;
  client_nom: string | null;
  etablissement: string | null;
  destinataire: string | null;
  telephone: string | null;
  adresse: string | null;
  ville: string | null;
  destination: string | null;
  mode_acheminement: "livraison" | "expedition" | null;
  statut_logistique: string | null;
  date_colisage: string | null;
  preparateur: string | null;
  observations: string | null;
  produits: { designation: string | null; quantite: number }[];
};

function CartonPublicPage() {
  const { colisId } = Route.useParams();
  const { data, isLoading, error } = useQuery({
    queryKey: ["carton-public", colisId],
    queryFn: async () => {
      const { data, error } = await supabase.rpc("get_carton_public", { _colis_id: colisId });
      if (error) throw error;
      return data as unknown as CartonPublic | null;
    },
  });

  if (isLoading) {
    return (
      <div className="flex min-h-dvh items-center justify-center bg-slate-50">
        <Loader2 className="h-8 w-8 animate-spin text-slate-400" />
      </div>
    );
  }

  if (error || !data) {
    return (
      <div className="flex min-h-dvh flex-col items-center justify-center gap-3 bg-slate-50 p-6 text-center">
        <Package className="h-12 w-12 text-slate-400" />
        <h1 className="text-xl font-semibold text-slate-800">Carton introuvable</h1>
        <p className="max-w-sm text-sm text-slate-500">
          Ce QR code ne correspond à aucun carton actif. Vérifiez que vous scannez bien un sticker
          imprimé par le service logistique.
        </p>
      </div>
    );
  }

  return (
    <div className="min-h-dvh bg-slate-50 pb-10">
      {/* En-tête coloré */}
      <div className="bg-slate-900 px-4 py-6 text-white">
        <div className="mx-auto max-w-2xl">
          <div className="flex items-center gap-3">
            <Package className="h-7 w-7" />
            <div>
              <h1 className="text-lg font-semibold">Suivi du carton</h1>
              <p className="text-sm text-slate-300">FABS-CI · Consultation logistique</p>
            </div>
          </div>
        </div>
      </div>

      <div className="mx-auto -mt-4 max-w-2xl space-y-4 px-4">
        {/* Bandeau carton X/Y */}
        <div className="rounded-xl border-2 border-slate-900 bg-white p-6 text-center shadow-sm">
          <div className="text-xs font-semibold uppercase tracking-widest text-slate-500">
            Carton
          </div>
          <div className="text-5xl font-black text-slate-900">
            {data.numero_carton ?? "?"} / {data.nb_cartons ?? "?"}
          </div>
          {data.statut_logistique && (
            <div className="mt-2 inline-block rounded-full bg-emerald-100 px-3 py-1 text-xs font-semibold uppercase text-emerald-800">
              {data.statut_logistique.replace(/_/g, " ")}
            </div>
          )}
        </div>

        <Section title="Informations de livraison">
          <Row label="Bon de livraison" value={data.bl_reference} mono />
          <Row label="Commande" value={data.commande_reference} mono />
          <Row label="Colisage" value={data.reference_colis} mono />
        </Section>

        <Section title="Client et destination">
          <Row
            label={<User className="h-4 w-4" />}
            value={data.etablissement ?? data.client_nom}
            strong
          />
          {data.destinataire && data.destinataire !== data.client_nom && (
            <Row label="Destinataire" value={data.destinataire} />
          )}
          {data.telephone && (
            <Row
              label={<Phone className="h-4 w-4" />}
              value={
                <a href={`tel:${data.telephone}`} className="text-blue-600 underline">
                  {data.telephone}
                </a>
              }
            />
          )}
          <Row
            label={<MapPin className="h-4 w-4" />}
            value={[data.adresse, data.ville].filter(Boolean).join(", ") || data.destination}
          />
          <Row
            label={<Truck className="h-4 w-4" />}
            value={data.mode_acheminement === "expedition" ? "Expédition" : "Livraison"}
          />
        </Section>

        <Section title={`Contenu du carton (${data.produits?.length ?? 0} article(s))`}>
          {(data.produits ?? []).length === 0 ? (
            <p className="p-3 text-sm text-slate-500">Aucun détail produit disponible.</p>
          ) : (
            <table className="w-full text-sm">
              <thead className="border-b bg-slate-50 text-left text-xs uppercase text-slate-500">
                <tr>
                  <th className="p-3">Désignation</th>
                  <th className="p-3 text-right">Qté</th>
                </tr>
              </thead>
              <tbody>
                {data.produits.map((p, i) => (
                  <tr key={i} className="border-b last:border-0">
                    <td className="p-3">{p.designation ?? "—"}</td>
                    <td className="p-3 text-right font-semibold">{p.quantite}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </Section>

        <Section title="Logistique">
          {data.date_colisage && (
            <Row
              label={<Calendar className="h-4 w-4" />}
              value={new Date(data.date_colisage).toLocaleString("fr-FR")}
            />
          )}
          {data.preparateur && <Row label="Préparateur" value={data.preparateur} />}
          {data.observations && <Row label="Observations" value={data.observations} />}
        </Section>

        <p className="px-2 pt-4 text-center text-xs text-slate-400">
          Consultation en lecture seule. Aucune donnée commerciale ni financière n'est exposée.
        </p>
      </div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="overflow-hidden rounded-xl border bg-white shadow-sm">
      <div className="border-b bg-slate-50 px-4 py-2 text-xs font-semibold uppercase tracking-wider text-slate-500">
        {title}
      </div>
      <div className="divide-y">{children}</div>
    </div>
  );
}

function Row({
  label,
  value,
  strong,
  mono,
}: {
  label: React.ReactNode;
  value: React.ReactNode;
  strong?: boolean;
  mono?: boolean;
}) {
  if (!value) return null;
  return (
    <div className="flex items-start gap-3 px-4 py-3 text-sm">
      <div className="flex min-w-[130px] items-center gap-1 text-slate-500">{label}</div>
      <div
        className={
          (strong ? "font-semibold text-slate-900 " : "text-slate-800 ") + (mono ? "font-mono" : "")
        }
      >
        {value}
      </div>
    </div>
  );
}
