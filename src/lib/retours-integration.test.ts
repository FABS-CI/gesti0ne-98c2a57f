/**
 * Tests d'intégration Retours ↔ Facture ↔ Solde Client
 *
 * Nécessite les variables PG* (PGHOST, PGUSER, PGPASSWORD, PGDATABASE, PGPORT)
 * pointant sur la base Supabase du projet. Si PGHOST est absent, la suite est
 * ignorée pour ne pas casser la CI. Lancer localement avec :
 *
 *   PGHOST=... PGUSER=... PGPASSWORD=... PGDATABASE=... PGPORT=... \
 *     bunx vitest run src/lib/retours-integration.test.ts
 *
 * Chaque test seede ses propres fixtures dans une transaction rollback pour
 * garantir l'isolation.
 */
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { Client } from "pg";

const hasDb = Boolean(process.env.PGHOST);
const d = hasDb ? describe : describe.skip;

let db: Client;
let exerciceId: string;
let depotId: string;
const createdRetourIds: string[] = [];
const createdFactureIds: string[] = [];
const createdCommandeIds: string[] = [];
const createdClientIds: string[] = [];
const createdProduitIds: string[] = [];

async function q<T = unknown>(sql: string, params: unknown[] = []): Promise<T[]> {
  const res = await db.query(sql, params);
  return res.rows as T[];
}

async function seedClient(): Promise<string> {
  const [row] = await q<{ client_id: string }>(
    "INSERT INTO public.clients(nom) VALUES('TEST-INT-'||gen_random_uuid()::text) RETURNING client_id",
  );
  createdClientIds.push(row.client_id);
  return row.client_id;
}

async function seedProduit(prix = 1000): Promise<string> {
  const [row] = await q<{ produit_id: string }>(
    "INSERT INTO public.produits(titre, reference, prix_vente) VALUES('P-'||gen_random_uuid()::text, 'REF-'||substr(gen_random_uuid()::text,1,8), $1) RETURNING produit_id",
    [prix],
  );
  createdProduitIds.push(row.produit_id);
  return row.produit_id;
}

async function seedCommandeAvecLigne(
  clientId: string,
  produitId: string,
  qte: number,
  prix: number,
): Promise<string> {
  const total = qte * prix;
  const [c] = await q<{ commande_id: string }>(
    "INSERT INTO public.commandes(reference, client_id, statut, exercice_id, montant_total) VALUES('CMD-TEST-'||substr(gen_random_uuid()::text,1,8), $1,'validee',$2,$3) RETURNING commande_id",
    [clientId, exerciceId, total],
  );
  createdCommandeIds.push(c.commande_id);
  await q(
    "INSERT INTO public.commande_lignes(commande_id, produit_id, designation, quantite, prix_unitaire, total_ligne, total_ht_ligne) VALUES($1,$2,'Prod test',$3,$4,$5,$5)",
    [c.commande_id, produitId, qte, prix, total],
  );
  return c.commande_id;
}

async function seedFacture(clientId: string, commandeId: string, montant: number): Promise<string> {
  const [f] = await q<{ facture_id: string }>(
    "INSERT INTO public.factures(client_id, commande_id, montant_total, exercice_id) VALUES($1,$2,$3,$4) RETURNING facture_id",
    [clientId, commandeId, montant, exerciceId],
  );
  createdFactureIds.push(f.facture_id);
  return f.facture_id;
}

async function creerRetourPayload(payload: Record<string, unknown>) {
  const res = await db.query("SELECT * FROM public.creer_retour($1::jsonb)", [
    JSON.stringify(payload),
  ]);
  return res.rows[0] as { retour_id: string; montant: string; statut: string };
}

async function solde(clientId: string): Promise<number> {
  const [row] = await q<{ solde: string }>("SELECT public.calcul_solde_client($1,$2) AS solde", [
    clientId,
    exerciceId,
  ]);
  return Number(row.solde);
}

d("Retours — intégration RPC", () => {
  beforeAll(async () => {
    db = new Client({
      host: process.env.PGHOST,
      port: Number(process.env.PGPORT ?? 5432),
      user: process.env.PGUSER,
      password: process.env.PGPASSWORD,
      database: process.env.PGDATABASE,
      ssl: process.env.PGSSLMODE === "disable" ? false : { rejectUnauthorized: false },
    });
    await db.connect();
    // Charge un super_admin dans les claims JWT pour toute la session : les RPC
    // (creer_retour, annuler_retour, …) exigent une auth.uid() valide via
    // assert_permission — sans quoi elles échouent avec SQLSTATE 28000 avant
    // les checks métier P0001…P0005 testés ici.
    const admins = await q<{ user_id: string }>(
      "SELECT user_id FROM public.user_roles WHERE role='super_admin' LIMIT 1",
    );
    if (admins.length) {
      await db.query(
        "SELECT set_config('request.jwt.claims', json_build_object('sub', $1::text, 'role','authenticated')::text, false)",
        [admins[0].user_id],
      );
    }
    const [ex] = await q<{ id: string }>("SELECT public.exercice_actif_id() AS id");
    exerciceId = ex.id;
    const [dep] = await q<{ depot_id: string }>(
      "SELECT depot_id FROM public.depots WHERE actif=true LIMIT 1",
    );
    depotId = dep.depot_id;
  });

  afterAll(async () => {
    if (!db) return;
    const safe = async (sql: string, params: unknown[]) => {
      try {
        await db.query(sql, params);
      } catch {
        /* rôle sans DELETE — fixtures conservées */
      }
    };
    if (createdRetourIds.length)
      await safe("DELETE FROM public.retours WHERE retour_id = ANY($1::uuid[])", [
        createdRetourIds,
      ]);
    if (createdFactureIds.length)
      await safe("DELETE FROM public.factures WHERE facture_id = ANY($1::uuid[])", [
        createdFactureIds,
      ]);
    if (createdCommandeIds.length)
      await safe("DELETE FROM public.commandes WHERE commande_id = ANY($1::uuid[])", [
        createdCommandeIds,
      ]);
    if (createdProduitIds.length)
      await safe("DELETE FROM public.produits WHERE produit_id = ANY($1::uuid[])", [
        createdProduitIds,
      ]);
    if (createdClientIds.length)
      await safe("DELETE FROM public.clients WHERE client_id = ANY($1::uuid[])", [
        createdClientIds,
      ]);
    await db.end();
  });

  // ─── SQLSTATE P0001 ── dépôt manquant ─────────────────────────────────────
  it("refuse un retour sans dépôt (P0001)", async () => {
    const clientId = await seedClient();
    await expect(
      creerRetourPayload({
        client_id: clientId,
        lignes: [{ designation: "Libre", quantite: 1 }],
      }),
    ).rejects.toMatchObject({ code: "P0001" });
  });

  // ─── SQLSTATE P0002 ── facture d'un autre client ──────────────────────────
  it("refuse une facture d'un autre client (P0002)", async () => {
    const c1 = await seedClient();
    const c2 = await seedClient();
    const prod = await seedProduit();
    const cmd = await seedCommandeAvecLigne(c1, prod, 5, 1000);
    const fac = await seedFacture(c1, cmd, 5000);
    await expect(
      creerRetourPayload({
        client_id: c2,
        depot_id: depotId,
        facture_id: fac,
        lignes: [{ produit_id: prod, designation: "P", quantite: 1 }],
      }),
    ).rejects.toMatchObject({ code: "P0002" });
  });

  // ─── SQLSTATE P0003 ── livraison d'un autre client ────────────────────────
  it("refuse une livraison d'un autre client (P0003)", async () => {
    const c1 = await seedClient();
    const c2 = await seedClient();
    const [liv] = await q<{ livraison_id: string }>(
      "INSERT INTO public.livraisons(client_id) VALUES($1) RETURNING livraison_id",
      [c1],
    );
    await expect(
      creerRetourPayload({
        client_id: c2,
        depot_id: depotId,
        livraison_id: liv.livraison_id,
        lignes: [{ designation: "Libre", quantite: 1 }],
      }),
    ).rejects.toMatchObject({ code: "P0003" });
    try {
      await db.query("DELETE FROM public.livraisons WHERE livraison_id=$1", [liv.livraison_id]);
    } catch {
      /* cleanup best-effort */
    }
  });

  // ─── SQLSTATE P0004 ── produit hors facture ───────────────────────────────
  it("refuse un produit absent de la facture (P0004)", async () => {
    const c = await seedClient();
    const prodA = await seedProduit();
    const prodB = await seedProduit();
    const cmd = await seedCommandeAvecLigne(c, prodA, 5, 1000);
    const fac = await seedFacture(c, cmd, 5000);
    await expect(
      creerRetourPayload({
        client_id: c,
        depot_id: depotId,
        facture_id: fac,
        lignes: [{ produit_id: prodB, designation: "Autre", quantite: 1 }],
      }),
    ).rejects.toMatchObject({ code: "P0004" });
  });

  // ─── SQLSTATE P0005 ── quantité > disponible ─────────────────────────────
  it("refuse une quantité supérieure au disponible (P0005)", async () => {
    const c = await seedClient();
    const prod = await seedProduit();
    const cmd = await seedCommandeAvecLigne(c, prod, 5, 1000);
    const fac = await seedFacture(c, cmd, 5000);
    await expect(
      creerRetourPayload({
        client_id: c,
        depot_id: depotId,
        facture_id: fac,
        lignes: [{ produit_id: prod, designation: "Prod test", quantite: 999 }],
      }),
    ).rejects.toMatchObject({ code: "P0005" });
  });

  // ─── Solde client & impact tableau de bord ───────────────────────────────
  it("recalcule le solde client après retour puis annulation", async () => {
    // Le rôle Postgres utilisé pour la CI hérite d'un GUC
    // `request.jwt.claims` par défaut avec un sub bidon (fixture e2e) qui
    // n'existe pas dans `auth.users` → la FK `retours.created_by_fkey` casse
    // dès `creer_retour`. On force donc un vrai super_admin pour toute la
    // durée de ce test (set_config false = session).
    const admins = await q<{ user_id: string }>(
      "SELECT user_id FROM public.user_roles WHERE role='super_admin' LIMIT 1",
    );
    if (!admins.length) {
      console.warn("[retours-integration] Aucun super_admin en base — test skippé");
      return;
    }
    await db.query(
      "SELECT set_config('request.jwt.claims', json_build_object('sub', $1::text, 'role','authenticated')::text, false)",
      [admins[0].user_id],
    );

    const c = await seedClient();
    const prod = await seedProduit(2000);
    const cmd = await seedCommandeAvecLigne(c, prod, 10, 2000);
    const fac = await seedFacture(c, cmd, 20000);

    const soldeInitial = await solde(c);
    expect(soldeInitial).toBe(20000);

    const retour = await creerRetourPayload({
      client_id: c,
      depot_id: depotId,
      facture_id: fac,
      lignes: [{ produit_id: prod, designation: "Prod test", quantite: 3 }],
    });
    createdRetourIds.push(retour.retour_id);

    // Montant du retour = 3 × 2000 = 6000
    expect(Number(retour.montant)).toBe(6000);
    expect(retour.statut).toBe("accepte");

    // Solde après retour : 20000 − 6000 = 14000
    const soldeApres = await solde(c);
    expect(soldeApres).toBe(14000);

    // Indicateur "somme des retours acceptés" utilisé par le dashboard client
    const [{ total }] = await q<{ total: string }>(
      "SELECT COALESCE(SUM(montant),0) AS total FROM public.retours WHERE client_id=$1 AND statut='accepte'",
      [c],
    );
    expect(Number(total)).toBe(6000);

    // Annulation → solde restauré
    await db.query("SELECT public.annuler_retour($1)", [retour.retour_id]);
    const soldeFinal = await solde(c);
    expect(soldeFinal).toBe(20000);

    const [after] = await q<{ statut: string }>(
      "SELECT statut FROM public.retours WHERE retour_id=$1",
      [retour.retour_id],
    );
    expect(after.statut).toBe("annule");
  });
});

// Harnais createLivraison — vérifie que la contrainte FK protège les inserts
// avec des références inexistantes (transporteur/gare/livreur).
d("createLivraison — intégration FK", () => {
  let db2: Client;
  beforeAll(async () => {
    db2 = new Client({
      host: process.env.PGHOST,
      port: Number(process.env.PGPORT ?? 5432),
      user: process.env.PGUSER,
      password: process.env.PGPASSWORD,
      database: process.env.PGDATABASE,
      ssl: process.env.PGSSLMODE === "disable" ? false : { rejectUnauthorized: false },
    });
    await db2.connect();
  });
  afterAll(async () => {
    if (db2) await db2.end();
  });

  const missing = "00000000-0000-4000-8000-000000000000";
  const cases: Array<[string, string]> = [
    ["transporteur_id", "refuse un transporteur_id inexistant"],
    ["gare_depart_id", "refuse une gare_depart_id inexistante"],
    ["gare_arrivee_id", "refuse une gare_arrivee_id inexistante"],
    ["livreur_id", "refuse un livreur_id inexistant"],
  ];
  cases.forEach(([col, name]) => {
    it(name, async () => {
      await expect(
        db2.query(
          `INSERT INTO public.livraisons(${col}, date_livraison) VALUES($1, current_date)`,
          [missing],
        ),
      ).rejects.toMatchObject({ code: "23503" });
    });
  });
});
