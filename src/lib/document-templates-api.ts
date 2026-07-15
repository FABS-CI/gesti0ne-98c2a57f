import { getCurrentUser } from "@/lib/current-user";
import { supabase } from "@/integrations/supabase/client";
import {
  BUILTIN_TEMPLATES,
  DEFAULT_TEMPLATE,
  setCustomTemplatesCache,
  setActiveTemplate as setActiveTemplateLocal,
  type PdfTemplate,
  type PdfTemplateId,
} from "@/lib/pdf/pdfConfig";

/** Forme JSONB stockée pour un modèle personnalisé (sans id/custom). */
type StoredConfig = Omit<PdfTemplate, "id" | "custom">;

type TemplateRow = {
  template_id: string;
  label: string;
  description: string | null;
  config: StoredConfig;
};

function rowToTemplate(row: TemplateRow): PdfTemplate {
  return {
    ...row.config,
    id: row.template_id,
    label: row.label,
    description: row.description ?? row.config.description ?? "",
    custom: true,
  };
}

/** Charge les modèles personnalisés de l'utilisateur et hydrate le cache local. */
export async function loadCustomTemplates(): Promise<PdfTemplate[]> {
  const { data, error } = await supabase
    .from("document_templates")
    .select("template_id, label, description, config")
    .order("created_at", { ascending: true });
  if (error) throw error;
  const list = (data ?? []).map((r) => rowToTemplate(r as unknown as TemplateRow));
  setCustomTemplatesCache(list);
  return list;
}

/** Crée un modèle personnalisé. */
export async function createCustomTemplate(
  template: Omit<PdfTemplate, "id" | "custom">,
): Promise<PdfTemplate> {
  const { data: userData } = await getCurrentUser();
  const userId = userData.user?.id;
  if (!userId) throw new Error("Non authentifié");
  const { label, description, ...config } = template;
  const { data, error } = await supabase
    .from("document_templates")
    .insert({ user_id: userId, label, description, config: { ...config, description } })
    .select("template_id, label, description, config")
    .single();
  if (error) throw error;
  await loadCustomTemplates();
  return rowToTemplate(data as unknown as TemplateRow);
}

/** Met à jour un modèle personnalisé existant. */
export async function updateCustomTemplate(
  id: string,
  template: Omit<PdfTemplate, "id" | "custom">,
): Promise<void> {
  const { label, description, ...config } = template;
  const { error } = await supabase
    .from("document_templates")
    .update({ label, description, config: { ...config, description } })
    .eq("template_id", id);
  if (error) throw error;
  await loadCustomTemplates();
}

/** Supprime un modèle personnalisé. */
export async function deleteCustomTemplate(id: string): Promise<void> {
  const { error } = await supabase.from("document_templates").delete().eq("template_id", id);
  if (error) throw error;
  await loadCustomTemplates();
}

/** Récupère la préférence de modèle actif de l'utilisateur et hydrate le cache local. */
export async function loadActiveTemplatePref(): Promise<PdfTemplateId> {
  const { data, error } = await supabase
    .from("document_template_prefs")
    .select("active_template_id")
    .maybeSingle();
  if (error) throw error;
  const id = data?.active_template_id ?? DEFAULT_TEMPLATE.id;
  setActiveTemplateLocal(id);
  return id;
}

/** Définit la préférence de modèle actif (persistée par utilisateur + cache local). */
export async function setActiveTemplatePref(id: PdfTemplateId): Promise<void> {
  setActiveTemplateLocal(id);
  const { data: userData } = await getCurrentUser();
  const userId = userData.user?.id;
  if (!userId) throw new Error("Non authentifié");
  const { error } = await supabase
    .from("document_template_prefs")
    .upsert({ user_id: userId, active_template_id: id, updated_at: new Date().toISOString() });
  if (error) throw error;
}

/** Synchronise modèles + préférence au démarrage. Renvoie tous les modèles. */
export async function syncDocumentTemplates(): Promise<{
  templates: PdfTemplate[];
  activeId: PdfTemplateId;
}> {
  const [custom, activeId] = await Promise.all([loadCustomTemplates(), loadActiveTemplatePref()]);
  return { templates: [...BUILTIN_TEMPLATES, ...custom], activeId };
}
