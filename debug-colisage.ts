
import { supabase } from "./src/integrations/supabase/client";

async function checkColisageBug() {
  const blRef = 'BL-2026-00001';
  const blId = 'dc0e89de-3c83-47d9-9a99-815f34e22d35'; // From previous SQL check

  
  console.log("--- START AUDIT ---");
  
  // 1. Get BL
  const { data: bl, error: blErr } = await supabase
    .from('bons_livraison')
    .select('bl_id, reference, commande_id, statut')
    .eq('bl_id', blId)

    .single();
    
  if (blErr) {
    console.error("BL not found:", blErr);
    return;
  }
  
  console.log("BL found:", bl);
  
  if (!bl.commande_id) {
    console.error("BL has no commande_id");
    return;
  }
  
  // 2. Get lines
  const { data: lines, error: linesErr } = await supabase
    .from('commande_lignes')
    .select('ligne_id, produit_id, designation, reference_produit, quantite')
    .eq('commande_id', bl.commande_id);
    
  if (linesErr) {
    console.error("Error fetching lines:", linesErr);
    return;
  }
  
  console.log("Lines fetched from DB:", lines?.length);
  lines?.forEach(l => console.log(`- ${l.designation} (${l.quantite}) ID:${l.ligne_id} PROD:${l.produit_id}`));
  
  // 3. Simulate keyForLigne logic
  const keys = lines?.map(l => l.produit_id || l.ligne_id);
  console.log("Keys generated for frontend:", keys);
  
  // 4. Check for existing colis
  const { data: colis, error: colisErr } = await supabase
    .from('colis')
    .select('colis_id, colis_lignes(produit_id, quantite)')
    .eq('bl_id', bl.bl_id);
    
  if (colisErr) {
    console.error("Error fetching colis:", colisErr);
  } else {
    console.log("Existing Colis found:", colis?.length);
    colis?.forEach(c => {
      console.log(`Colis ${c.colis_id}:`, c.colis_lignes);
    });
  }
  
  console.log("--- END AUDIT ---");
}

checkColisageBug().catch(console.error);
