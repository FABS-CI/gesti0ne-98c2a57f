// API + cache des préférences globales d'apparence PDF (table document_settings).
// Port de la collection MongoDB `document_settings` de ERP-FABS V10 :
// selected_template, template_per_type, logo_url.
import { getCurrentUser } from "@/lib/current-user";
import { supabase } from "@/integrations/supabase/client";
import {
  setActiveTemplate as setActiveTemplateLocal,
  type PdfTemplateId,
} from "@/lib/pdf/pdfConfig";

export type DocType =
  | "facture"
  | "proforma"
  | "bon_commande"
  | "bon_livraison"
  | "bon_retour"
  | "avoir"
  | "recu"
  | "etat_compte"
  | "bulletin";

export type DocumentSettings = {
  selected_template: PdfTemplateId;
  template_per_type: Partial<Record<DocType, PdfTemplateId>>;
  logo_url: string | null;
};

const DEFAULTS: DocumentSettings = {
  selected_template: "classique",
  template_per_type: {},
  logo_url: null,
};

function normalizeLogoUrl(url: string | null | undefined): string | null {
  if (!url || url.includes("/__l5e/assets-v1/")) return null;
  return url;
}

let CACHE: DocumentSettings = { ...DEFAULTS };

export function getDocumentSettingsSync(): DocumentSettings {
  return CACHE;
}

/** Template à utiliser pour un type donné (template_per_type prioritaire). */
export function getTemplateForType(type?: DocType | null): PdfTemplateId {
  if (type && CACHE.template_per_type[type]) return CACHE.template_per_type[type] as string;
  return CACHE.selected_template;
}

export async function loadDocumentSettings(): Promise<DocumentSettings> {
  const { data, error } = await supabase
    .from("document_settings")
    .select("selected_template, template_per_type, logo_url")
    .maybeSingle();
  if (error) throw error;
  CACHE = {
    selected_template: (data?.selected_template ?? DEFAULTS.selected_template) as PdfTemplateId,
    template_per_type: (data?.template_per_type as DocumentSettings["template_per_type"]) ?? {},
    logo_url: normalizeLogoUrl(data?.logo_url),
  };
  setActiveTemplateLocal(CACHE.selected_template);
  return CACHE;
}

export async function saveDocumentSettings(
  patch: Partial<DocumentSettings>,
): Promise<DocumentSettings> {
  const { data: u } = await getCurrentUser();
  const uid = u.user?.id;
  if (!uid) throw new Error("Non authentifié");
  const next = { ...CACHE, ...patch, logo_url: normalizeLogoUrl(patch.logo_url ?? CACHE.logo_url) };
  const { error } = await supabase.from("document_settings").upsert({
    user_id: uid,
    selected_template: next.selected_template,
    template_per_type: next.template_per_type,
    logo_url: next.logo_url,
    updated_at: new Date().toISOString(),
  });
  if (error) throw error;
  CACHE = next;
  setActiveTemplateLocal(CACHE.selected_template);
  return CACHE;
}
