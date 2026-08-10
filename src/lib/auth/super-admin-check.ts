import { supabase } from "@/integrations/supabase/client";

/**
 * RÈGLE ABSOLUE — ACTIONS DU SUPER ADMIN
 * Avant toute création d'événement, notification ou entrée d'audit, 
 * le système doit vérifier l'identité et le rôle de l'utilisateur.
 * Si l'utilisateur est SUPER_ADMIN, l'action ne doit pas être notifiée ni auditée.
 */
export async function isSuperAdminAction(): Promise<boolean> {
  try {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session?.user) return false;
    
    // Extraction du rôle depuis les claims du JWT
    const userRole = session.user.app_metadata?.user_role || session.user.user_metadata?.role;
    if (userRole === "super_admin") return true;

    // Fallback sur rbac3_user_roles si non présent dans le token (sécurité accrue)
    const { data: roles } = await supabase
      .from("rbac3_user_roles")
      .select("role_code")
      .eq("user_id", session.user.id)
      .eq("role_code", "super_admin")
      .maybeSingle();
      
    return !!roles;
  } catch {
    return false;
  }
}
