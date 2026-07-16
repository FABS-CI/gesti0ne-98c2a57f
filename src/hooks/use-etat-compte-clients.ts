import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { computeSoldeClient, type SoldeDebug } from "@/lib/pdf/etat-compte-solde";

export type EtatCompteClient = {
  client_id: string;
  reference: string;
  nom: string;
  telephone: string | null;
  representant: string | null;
  plafond_credit: number;
  solde: number;
};

export type EtatCompteData = {
  rows: EtatCompteClient[];
  debugByClient: Map<string, SoldeDebug>;
  dateDebut: string | null;
  dateFin: string | null;
};

export function useEtatCompteClients(q: string, exerciceId: string | null | undefined) {
  return useQuery<EtatCompteData>({
    queryKey: ["etat-compte", q, exerciceId],
    queryFn: async () => {
      // PostgREST plafonne à 1000 lignes/req → pagination explicite.
      const PAGE = 1000;
      const base: Omit<EtatCompteClient, "solde">[] = [];
      for (let from = 0; ; from += PAGE) {
        let query = supabase
          .from("clients")
          .select("client_id, reference, nom, telephone, representant, plafond_credit");
        if (q) query = query.or(`nom.ilike.%${q}%,reference.ilike.%${q}%`);
        const { data, error } = await query
          .order("nom", { ascending: true })
          .range(from, from + PAGE - 1);
        if (error) throw error;
        const page = (data ?? []) as Omit<EtatCompteClient, "solde">[];
        base.push(...page);
        if (page.length < PAGE) break;
      }
      if (base.length === 0)
        return {
          rows: [],
          debugByClient: new Map(),
          dateDebut: null,
          dateFin: null,
        };
      const ids = base.map((c) => c.client_id);

      let dateDebut: string | null = null;
      let dateFin: string | null = null;
      // Volontairement pas de filtre de période ici : l'état de compte agrège
      // TOUTES les factures/paiements/avoirs du client pour éviter que des
      // factures antérieures à l'exercice actif disparaissent du solde.
      // (Le report d'ouverture reste géré via soldes_ouverture_clients.)

      const CHUNK = 100;
      const chunks: string[][] = [];
      for (let i = 0; i < ids.length; i += CHUNK) chunks.push(ids.slice(i, i + CHUNK));

      const runBatched = async <T>(
        fn: (batch: string[]) => PromiseLike<{ data: T[] | null; error: unknown }>,
      ): Promise<T[]> => {
        const out: T[] = [];
        for (const batch of chunks) {
          const { data, error } = await fn(batch);
          if (error) throw error;
          if (data) out.push(...data);
        }
        return out;
      };

      type FactureRow = {
        client_id: string | null;
        montant_total: number | null;
        date_facture: string;
      };
      type PaiementRow = {
        montant: number;
        date_paiement: string;
        statut: string | null;
        factures: { client_id: string | null } | { client_id: string | null }[] | null;
      };
      type AvoirRow = {
        client_id: string | null;
        montant: number;
        date_retour: string;
        statut: string | null;
      };
      type OuvertureRow = { client_id: string; montant: number };

      const [facturesData, paiementsData, avoirsData, ouverturesData] = await Promise.all([
        runBatched<FactureRow>((batch) =>
          supabase
            .from("factures")
            .select("client_id, montant_total, date_facture")
            .in("client_id", batch),
        ),
        runBatched<PaiementRow>((batch) =>
          supabase
            .from("paiements")
            .select("montant, date_paiement, statut, factures!inner(client_id)")
            .in("factures.client_id", batch),
        ),
        runBatched<AvoirRow>((batch) =>
          supabase
            .from("bons_retour")
            .select("client_id, montant, date_retour, statut")
            .in("client_id", batch),
        ),
        exerciceId
          ? runBatched<OuvertureRow>((batch) =>
              supabase
                .from("soldes_ouverture_clients")
                .select("client_id, montant")
                .eq("exercice_id", exerciceId)
                .in("client_id", batch),
            ).catch(() => [] as OuvertureRow[])
          : Promise.resolve([] as OuvertureRow[]),
      ]);


      const byClient = new Map<
        string,
        {
          factures: Array<{ date_facture: string; montant_total: number | null }>;
          paiements: Array<{
            date_paiement: string;
            montant: number | null;
            statut: string | null;
          }>;
          avoirs: Array<{ date_retour: string; montant: number | null; statut: string | null }>;
          soldeOuvertureRow: number;
        }
      >();
      const bucket = (id: string) => {
        let b = byClient.get(id);
        if (!b) {
          b = { factures: [], paiements: [], avoirs: [], soldeOuvertureRow: 0 };
          byClient.set(id, b);
        }
        return b;
      };
      for (const o of ouverturesData) {
        bucket(o.client_id).soldeOuvertureRow = Number(o.montant ?? 0);
      }
      for (const f of facturesData) {
        if (!f.client_id) continue;
        bucket(f.client_id).factures.push({
          date_facture: f.date_facture as string,
          montant_total: Number(f.montant_total ?? 0),
        });
      }
      for (const p of paiementsData) {
        const cid = Array.isArray(p.factures) ? p.factures[0]?.client_id : p.factures?.client_id;
        if (!cid) continue;
        bucket(cid).paiements.push({
          date_paiement: p.date_paiement,
          montant: Number(p.montant ?? 0),
          statut: p.statut ?? null,
        });
      }
      for (const a of avoirsData) {
        if (!a.client_id) continue;
        bucket(a.client_id).avoirs.push({
          date_retour: a.date_retour,
          montant: Number(a.montant ?? 0),
          statut: a.statut ?? null,
        });
      }

      const debugByClient = new Map<string, SoldeDebug>();
      const rows: EtatCompteClient[] = base.map((c) => {
        const b = byClient.get(c.client_id) ?? {
          factures: [],
          paiements: [],
          avoirs: [],
          soldeOuvertureRow: 0,
        };
        const r = computeSoldeClient({
          clientId: c.client_id,
          dateDebut,
          dateFin,
          soldeOuvertureRow: b.soldeOuvertureRow,
          factures: b.factures,
          paiements: b.paiements,
          avoirs: b.avoirs,
        });
        debugByClient.set(c.client_id, r.debug);
        return { ...c, solde: r.solde };
      });
      rows.sort((a, b) => Number(b.solde) - Number(a.solde));
      return { rows, debugByClient, dateDebut, dateFin };
    },
  });
}
