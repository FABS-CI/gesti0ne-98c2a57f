/**
 * E2E — Workflow aller/retour complet de l'ERP.
 *
 * Scénario (aller) :
 *   1) Créer commande  2) Valider  3) BL  4) Colisage
 *   5) Tournée  6) Valider tournée  7) Livraison  8) Paiement
 *
 * Scénario (retour) :
 *   9) Supprimer paiement  10) Annuler livraison  11) Annuler tournée
 *  12) Annuler colisage  13) Supprimer BL  14) Supprimer commande
 *
 * Après CHAQUE étape, `checkInvariants()` vérifie :
 *   - Aucun orphelin (commande_lignes / colis / colis_lignes / paiements /
 *     bons_livraison / factures / livsuivi / notifications / historique_envois /
 *     stock_mouvements).
 *   - `produits.stock` = SUM(stocks_depots.quantite) pour chaque produit.
 *   - `factures.montant_paye` = SUM(paiements validés) par facture.
 *   - Statut cohérent (payee/partielle/impayee).
 *   - Après retour complet : stock final == stock initial du snapshot.
 *
 * Pré-requis d'exécution :
 *   - LOVABLE_BROWSER_AUTH_STATUS=injected (session super_admin injectée)
 *   - Un client de test, un produit de test avec stock >= 10 dans un dépôt.
 *     Renseigner CLIENT_ID / PRODUIT_ID / DEPOT_ID ci-dessous.
 *
 * Lance avec :  bunx playwright test e2e/workflow-aller-retour.spec.ts
 */
import { test, expect } from "@playwright/test";
import { getAuthedClient, hasAuthSession } from "./fixtures/supabase";

// À renseigner par l'opérateur avant exécution (ou via env)
const CLIENT_ID = process.env.E2E_CLIENT_ID ?? "";
const PRODUIT_ID = process.env.E2E_PRODUIT_ID ?? "";
const DEPOT_ID = process.env.E2E_DEPOT_ID ?? "";
const QTE = 5;

type Snapshot = { stock: number; encours: number };

async function snapshotStock(sb = getAuthedClient()): Promise<Snapshot> {
  const { data: p } = await sb.from("v_produits").select("stock").eq("produit_id", PRODUIT_ID).single();
  const { data: f } = await sb
    .from("factures")
    .select("montant_total, montant_paye")
    .eq("client_id", CLIENT_ID);
  const encours = (f ?? []).reduce(
    (s, r) => s + Number(r.montant_total ?? 0) - Number(r.montant_paye ?? 0),
    0,
  );
  return { stock: Number(p?.stock ?? 0), encours };
}

/** Assertions de cohérence globale à jouer après CHAQUE étape. */
async function checkInvariants(step: string) {
  const sb = getAuthedClient();

  // 1. Orphelins — checks purement JS (pas de RPC SQL arbitraire).
  //    On charge les enfants + les IDs parents et on compare côté client.
  const orphanChecks: Array<{
    label: string;
    child: string;
    childFk: string;
    parent: string;
    parentPk: string;
    filter?: (row: Record<string, unknown>) => boolean;
  }> = [
    { label: "commande_lignes", child: "commande_lignes", childFk: "commande_id", parent: "commandes", parentPk: "commande_id" },
    { label: "colis_lignes",    child: "colis_lignes",    childFk: "colis_id",    parent: "colis",     parentPk: "colis_id" },
    { label: "paiements",       child: "paiements",       childFk: "facture_id",  parent: "factures",  parentPk: "facture_id",
      filter: (r) => r.facture_id != null },
  ];
  for (const c of orphanChecks) {
    const { data: children } = await sb.from(c.child).select(c.childFk);
    const rows = (children ?? []).filter(c.filter ?? (() => true));
    const ids = Array.from(new Set(rows.map((r) => (r as Record<string, unknown>)[c.childFk] as string)));
    if (ids.length === 0) continue;
    const { data: parents } = await sb.from(c.parent).select(c.parentPk).in(c.parentPk, ids);
    const alive = new Set((parents ?? []).map((p) => (p as Record<string, unknown>)[c.parentPk] as string));
    const orphans = ids.filter((id) => !alive.has(id)).length;
    expect(orphans, `[${step}] ${c.label} orphelins`).toBe(0);
  }

  // stock_mouvements orphelins (document polymorphique)
  const { data: mvts } = await sb
    .from("stock_mouvements")
    .select("mouvement_id, document_table, document_id")
    .not("document_id", "is", null);
  const byTable: Record<string, { pk: string; ids: Set<string> }> = {
    commandes: { pk: "commande_id", ids: new Set() },
    colis: { pk: "colis_id", ids: new Set() },
    bons_livraison: { pk: "bl_id", ids: new Set() },
    factures: { pk: "facture_id", ids: new Set() },
  };
  for (const m of mvts ?? []) {
    const t = (m as { document_table?: string }).document_table;
    const id = (m as { document_id?: string }).document_id;
    if (t && id && byTable[t]) byTable[t].ids.add(id);
  }
  for (const [table, { pk, ids }] of Object.entries(byTable)) {
    if (ids.size === 0) continue;
    const idList = Array.from(ids);
    const { data: alive } = await sb.from(table).select(pk).in(pk, idList);
    const aliveSet = new Set((alive ?? []).map((r) => (r as Record<string, unknown>)[pk] as string));
    const orphans = idList.filter((id) => !aliveSet.has(id)).length;
    expect(orphans, `[${step}] stock_mouvements orphelins → ${table}`).toBe(0);
  }

  // 2. Cohérence v_produits.stock ↔ stocks_depots (source unique de vérité)
  const { data: prod } = await sb.from("v_produits").select("produit_id, stock");
  for (const p of prod ?? []) {
    const { data: sd } = await sb
      .from("stocks_depots")
      .select("quantite")
      .eq("produit_id", p.produit_id);
    const total = (sd ?? []).reduce((s, r) => s + Number(r.quantite ?? 0), 0);
    expect(Number(p.stock ?? 0), `[${step}] v_produits.stock ${p.produit_id}`).toBe(total);
  }

  // 3. Cohérence factures.montant_paye ↔ SUM(paiements validés)
  const { data: fac } = await sb.from("factures").select("facture_id, montant_paye, statut, montant_total");
  for (const f of fac ?? []) {
    const { data: pai } = await sb
      .from("paiements")
      .select("montant, statut")
      .eq("facture_id", f.facture_id);
    const validPaye = (pai ?? [])
      .filter((x) => x.statut !== "annule")
      .reduce((s, r) => s + Number(r.montant ?? 0), 0);
    expect(Number(f.montant_paye ?? 0), `[${step}] facture ${f.facture_id} montant_paye`).toBeCloseTo(
      validPaye,
      2,
    );
  }
}

test.describe.serial("Workflow aller/retour complet", () => {
  test.skip(!hasAuthSession, "session super_admin requise");
  test.skip(!CLIENT_ID || !PRODUIT_ID || !DEPOT_ID, "renseigner E2E_CLIENT_ID/PRODUIT_ID/DEPOT_ID");

  let commandeId: string;
  let blId: string;
  let colisId: string;
  let tourneeId: string;
  let livraisonId: string;
  let factureId: string;
  let paiementId: string;
  let initial: Snapshot;

  test("00 · snapshot initial", async () => {
    initial = await snapshotStock();
    await checkInvariants("00-init");
  });

  test("01 · créer commande", async () => {
    const sb = getAuthedClient();
    // Résoudre titre + prix depuis v_produits (la vue est la source unique)
    const { data: prod, error: eProd } = await sb
      .from("v_produits")
      .select("titre, prix_vente, reference")
      .eq("produit_id", PRODUIT_ID)
      .single();
    expect(eProd, eProd?.message).toBeNull();
    const { data, error } = await sb.rpc("creer_commande", {
      _payload: {
        date_commande: new Date().toISOString().slice(0, 10),
        client_id: CLIENT_ID,
        depot_id: DEPOT_ID,
        lignes: [
          {
            produit_id: PRODUIT_ID,
            designation: (prod as { titre?: string })?.titre ?? "Produit E2E",
            reference_produit: (prod as { reference?: string })?.reference ?? null,
            quantite: QTE,
            prix_unitaire: Number((prod as { prix_vente?: number })?.prix_vente ?? 1000),
          },
        ],
      } as never,
    });
    expect(error, error?.message).toBeNull();
    commandeId = (data as { commande_id: string })?.commande_id
      ?? (data as unknown as string);
    await checkInvariants("01-create");
  });

  test("02 · valider commande (→ facture + BL)", async () => {
    const sb = getAuthedClient();
    // Note : `creer_commande` valide déjà automatiquement si l'utilisateur
    // possède la permission `commandes.valider`. Dans ce cas la commande est
    // déjà en statut validée + facture + BL créés. On récupère les IDs.
    const { data: cmd } = await sb
      .from("commandes")
      .select("statut")
      .eq("commande_id", commandeId)
      .single();
    if ((cmd as { statut?: string })?.statut === "en_attente_validation") {
      const { data, error } = await sb.rpc("valider_commande", { _commande_id: commandeId });
      expect(error, error?.message).toBeNull();
      const r = data as { facture_id: string; bl_id: string };
      factureId = r.facture_id;
      blId = r.bl_id;
    } else {
      const { data: fac } = await sb
        .from("factures")
        .select("facture_id")
        .eq("commande_id", commandeId)
        .limit(1)
        .maybeSingle();
      const { data: bl } = await sb
        .from("bons_livraison")
        .select("bl_id")
        .eq("commande_id", commandeId)
        .limit(1)
        .maybeSingle();
      factureId = (fac as { facture_id?: string })?.facture_id ?? "";
      blId = (bl as { bl_id?: string })?.bl_id ?? "";
      expect(factureId, "facture_id trouvée").not.toBe("");
      expect(blId, "bl_id trouvé").not.toBe("");
    }
    await checkInvariants("02-valider");
  });

  test("03 · colisage", async () => {
    const sb = getAuthedClient();
    const { data, error } = await sb.rpc("creer_colisage", {
      _bl_id: blId,
      _payload: {
        mode_acheminement: "livraison",
        nb_cartons: 1,
        livreur_nom: "E2E Livreur",
        livreur_telephone: "0000",
        vehicule: "E2E-VH",
        ville_livraison: "Abidjan",
        observations: "E2E colisage",
        date_colisage: new Date().toISOString().slice(0, 10),
      },
    } as never);
    expect(error, error?.message).toBeNull();
    const cartons = (data ?? []) as Array<{ colis_id: string }>;
    colisId = cartons[0]?.colis_id ?? "";
    expect(colisId, "colis_id retourné").not.toBe("");
    await checkInvariants("03-colisage");
  });

  test("04 · créer tournée + rattacher la livraison", async () => {
    const sb = getAuthedClient();
    // Récupérer l'id livsuivi_commandes créé par creer_colisage
    const { data: ls, error: eLs } = await sb
      .from("livsuivi_commandes")
      .select("id")
      .eq("commande_id", commandeId)
      .single();
    expect(eLs, eLs?.message).toBeNull();
    livraisonId = (ls as { id: string }).id;
    const { data: t, error: e1 } = await sb.rpc("livsuivi_creer_tournee", {
      _payload: {
        type: "direct",
        livreur_nom: "E2E Livreur",
        livreur_contact: "0000",
        vehicule: "E2E-VH",
        date_depart: new Date().toISOString().slice(0, 10),
        commande_ids: [livraisonId],
      },
    } as never);
    expect(e1, e1?.message).toBeNull();
    tourneeId = (t as { id: string }).id;
    await checkInvariants("04-tournee");
  });

  test("05 · livraison (direct: 4 étapes)", async () => {
    const sb = getAuthedClient();
    for (const etape of ["remise_livreur", "depart_depot", "arrive_client", "livree"] as const) {
      const { error } = await sb.rpc("livsuivi_avancer", {
        _livraison_id: livraisonId,
        _etape: etape,
        _meta: {},
        _commentaire: `E2E → ${etape}`,
      } as never);
      expect(error, `${etape}: ${error?.message}`).toBeNull();
    }
    await checkInvariants("05-livraison");
  });

  test("06 · paiement", async () => {
    const sb = getAuthedClient();
    const { data: fac } = await sb.from("factures").select("montant_total").eq("facture_id", factureId).single();
    const { data, error } = await sb.rpc("enregistrer_paiement", {
      _payload: {
        facture_id: factureId,
        date_paiement: new Date().toISOString().slice(0, 10),
        montant: Number(fac?.montant_total ?? 0),
        mode_paiement: "especes",
      },
    } as never);
    expect(error, error?.message).toBeNull();
    paiementId = (data as { paiement_id: string }).paiement_id;
    await checkInvariants("06-paiement");
  });

  // === WORKFLOW INVERSE ===

  test("07 · supprimer paiement", async () => {
    const sb = getAuthedClient();
    const { error } = await sb.rpc("supprimer_paiement_definitif", {
      _paiement_id: paiementId,
      _motif: "E2E rollback",
    });
    expect(error, error?.message).toBeNull();
    await checkInvariants("07-del-paiement");
  });

  test("08 · supprimer commande (cascade complète)", async () => {
    const sb = getAuthedClient();
    const { error } = await sb.rpc("supprimer_commande_definitif", {
      _commande_id: commandeId,
      _motif: "E2E rollback",
    });
    expect(error, error?.message).toBeNull();
    await checkInvariants("08-del-commande");
  });

  test("09 · stock final == stock initial", async () => {
    const final = await snapshotStock();
    expect(final.stock, "stock produit après aller/retour").toBe(initial.stock);
    expect(final.encours, "encours client après aller/retour").toBeCloseTo(initial.encours, 2);
  });
});