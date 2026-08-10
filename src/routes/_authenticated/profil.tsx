import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useRef, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { Loader2, Save, KeyRound, Camera, ShieldCheck, ShieldAlert, Shield } from "lucide-react";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { useAvatarUrl } from "@/hooks/use-avatar-url";

import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/use-auth";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";

import { toast } from "sonner";
import { RouteError, RouteNotFound } from "@/components/route-boundaries";
import { friendlyError } from "@/lib/friendly-error";
import { mfaStatus } from "@/lib/mfa.functions";
import { useNavigate } from "@tanstack/react-router";


export const Route = createFileRoute("/_authenticated/profil")({
  component: Profil,
  errorComponent: RouteError,
  notFoundComponent: RouteNotFound,
});

function Profil() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const statusFn = useServerFn(mfaStatus);
  const [nom, setNom] = useState("");
  const [saving, setSaving] = useState(false);
  const [pwd, setPwd] = useState("");
  const [pwdSaving, setPwdSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  const { data: mfa } = useQuery({
    queryKey: ["mfa-status"],
    queryFn: () => statusFn(),
  });


  const { data: profile, refetch } = useQuery({
    queryKey: ["my-profile", user?.id],
    enabled: !!user?.id,
    queryFn: async () => {
      const { data } = await supabase.from("profiles").select("*").eq("id", user!.id).maybeSingle();
      return data as {
        nom_complet: string | null;
        email: string | null;
        avatar_url: string | null;
      } | null;
    },
  });

  const { data: avatarUrl } = useAvatarUrl(profile?.avatar_url);

  useEffect(() => {
    if (profile?.nom_complet) setNom(profile.nom_complet);
  }, [profile?.nom_complet]);

  const onPickFile = () => fileRef.current?.click();

  const onFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file || !user?.id) return;
    if (!file.type.startsWith("image/")) {
      toast.error("Veuillez choisir une image");
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      toast.error("Image trop volumineuse (max 5 Mo)");
      return;
    }
    setUploading(true);
    const ext = file.name.split(".").pop() || "jpg";
    const path = `${user.id}/avatar-${Date.now()}.${ext}`;
    const { error: upErr } = await supabase.storage
      .from("avatars")
      .upload(path, file, { upsert: true, contentType: file.type });
    if (upErr) {
      setUploading(false);
      toast.error(friendlyError(upErr));
      return;
    }
    const { error: updErr } = await supabase
      .from("profiles")
      .update({ avatar_url: path })
      .eq("id", user.id);
    setUploading(false);
    if (updErr) toast.error(friendlyError(updErr));
    else {
      toast.success("Photo mise à jour");
      await queryClient.invalidateQueries({ queryKey: ["my-profile"] });
      await queryClient.invalidateQueries({ queryKey: ["avatar-signed-url"] });
      refetch();
    }
  };

  const saveProfile = async () => {
    if (!user?.id) return;
    setSaving(true);
    const { error } = await supabase
      .from("profiles")
      .update({ nom_complet: nom.trim() })
      .eq("id", user.id);
    setSaving(false);
    if (error) toast.error(friendlyError(error));
    else {
      toast.success("Profil mis à jour");
      await queryClient.invalidateQueries({ queryKey: ["my-profile"] });
      refetch();
    }
  };

  const savePassword = async () => {
    if (pwd.length < 6) {
      toast.error("Le mot de passe doit contenir au moins 6 caractères");
      return;
    }
    setPwdSaving(true);
    const { error } = await supabase.auth.updateUser({ password: pwd });
    setPwdSaving(false);
    if (error) toast.error(friendlyError(error));
    else {
      toast.success("Mot de passe modifié");
      setPwd("");
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Mon profil</h1>
        <p className="text-sm text-muted-foreground">Gérez vos informations personnelles</p>
      </div>

      <Card className="max-w-xl">
        <CardHeader>
          <CardTitle className="text-base">Informations</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center gap-4">
            <Avatar className="h-20 w-20">
              {avatarUrl ? <AvatarImage src={avatarUrl} alt="Photo de profil" /> : null}
              <AvatarFallback className="bg-primary text-lg text-primary-foreground">
                {(nom || user?.email || "?").slice(0, 2).toUpperCase()}
              </AvatarFallback>
            </Avatar>
            <div>
              <input ref={fileRef} type="file" accept="image/*" hidden onChange={onFileChange} />
              <Button type="button" variant="outline" onClick={onPickFile} disabled={uploading}>
                {uploading ? (
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                ) : (
                  <Camera className="mr-2 h-4 w-4" />
                )}
                {profile?.avatar_url ? "Changer la photo" : "Ajouter une photo"}
              </Button>
              <p className="mt-1 text-xs text-muted-foreground">JPG/PNG, 5 Mo max.</p>
            </div>
          </div>
          <div className="space-y-2">
            <Label>Email</Label>
            <Input value={profile?.email ?? user?.email ?? ""} disabled />
          </div>
          <div className="space-y-2">
            <Label htmlFor="nom">Nom complet</Label>
            <Input id="nom" value={nom} onChange={(e) => setNom(e.target.value)} />
          </div>
          <Button onClick={saveProfile} disabled={saving}>
            {saving ? (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            ) : (
              <Save className="mr-2 h-4 w-4" />
            )}
            Enregistrer
          </Button>
        </CardContent>
      </Card>

      <Card className="max-w-xl">
        <CardHeader>
          <CardTitle className="text-base">Sécurité</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="pwd">Nouveau mot de passe</Label>
            <Input
              id="pwd"
              type="password"
              value={pwd}
              onChange={(e) => setPwd(e.target.value)}
              placeholder="••••••••"
            />
          </div>
          <Button variant="outline" onClick={savePassword} disabled={pwdSaving}>
            {pwdSaving ? (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            ) : (
              <KeyRound className="mr-2 h-4 w-4" />
            )}
            Enregistrer le mot de passe
          </Button>
        </CardContent>
      </Card>

      <Card className="max-w-xl border-orange-200">
        <CardHeader>
          <div className="flex items-center justify-between">
            <div className="space-y-1">
              <CardTitle className="text-base flex items-center gap-2">
                <Shield className="h-4 w-4 text-orange-600" />
                Authentification multifacteur (MFA)
              </CardTitle>
              <CardDescription className="whitespace-pre-line text-xs">
                🔴 ORDRE D'EXÉCUTION — AUDIT FINAL OBLIGATOIRE GESTI-ONE AVANT PRODUCTION{"\n\n"}
                RÔLE{"\n\n"}
                Tu es responsable de la mise en production de GESTI-ONE.{"\n\n"}
                Tu n'es pas ici pour donner des conseils généraux.{"\n\n"}
                Tu dois :{"\n\n"}
                INSPECTER → MESURER → TESTER → CORRIGER → RE-TESTER → VALIDER{"\n\n"}
                Tu dois travailler directement sur le projet existant.{"\n\n"}
                🚨 INTERDICTION DE RÉPONDRE SANS AGIR{"\n\n"}
                Tu ne dois PAS répondre :{"\n\n"}
                « il faudrait vérifier » ;{"\n"}
                « je recommande de » ;{"\n"}
                « cela semble correct » ;{"\n"}
                « probablement » ;{"\n"}
                « le système devrait fonctionner » ;{"\n"}
                « prêt pour production » sans preuve.{"\n\n"}
                Tu dois inspecter le code réel et exécuter les vérifications disponibles.{"\n\n"}
                Si tu détectes un problème et qu'il peut être corrigé, corrige-le directement.{"\n\n"}
                Après chaque correction importante, relance les tests.{"\n\n"}
                🚨 INTERDICTION DE DÉCLARER GO TROP TÔT{"\n\n"}
                Tu n'as PAS le droit de déclarer :{"\n\n"}
                🟢 GO PRODUCTION{"\n\n"}
                tant que les contrôles critiques ne sont pas terminés.{"\n\n"}
                Si tu ne peux pas vérifier un élément critique, le résultat doit être :{"\n\n"}
                🔴 NO-GO — VÉRIFICATION NON EFFECTUÉE{"\n\n"}
                L'absence de preuve doit être considérée comme un problème.{"\n\n"}
                PHASE 1 — CARTOGRAPHIE DU PROJET{"\n\n"}
                Commence immédiatement par inspecter le repository.{"\n\n"}
                Identifie : Frontend, Backend, API, Database, PostgreSQL, Supabase, Authentication, MFA, RBAC, Ventes, Achats, Stock, Facturation, Paiements, Livraisons, Colisage, Comptabilité, RH, Rapports, PDF, PWA, Realtime, Storage, Migrations, Variables d'environnement.{"\n\n"}
                Ne suppose rien. Utilise le code réellement présent.{"\n\n"}
                PHASE 2 — DÉTECTER LES ARCHITECTURES DOUBLONS{"\n\n"}
                Rechercher immédiatement : MongoDB, PostgreSQL, Supabase, Firebase, localStorage, IndexedDB, anciens endpoints, anciens services, anciens modèles.{"\n\n"}
                Objectif : détecter les anciennes architectures ou fonctionnalités qui pourraient encore être utilisées accidentellement.{"\n\n"}
                PHASE 3 — 🔴 MFA{"\n\n"}
                Le problème MFA actuel est : ❌ Code invalide — MFA et 🟠 Non configuré.{"\n\n"}
                Tu dois traiter ce problème comme BLOQUANT PRODUCTION.{"\n"}
                Ne masque pas le problème. Ne désactive pas le MFA. Ne crée pas de code universel. Ne contourne pas TOTP.{"\n"}
                Inspecte : génération secret, QR Code, stockage secret, mfa_enabled, validation TOTP, authenticator, user_id, session, API, frontend.{"\n"}
                Vérifie impérativement : SECRET DU QR CODE = SECRET EN BASE = SECRET UTILISÉ PAR LA VALIDATION.{"\n"}
                Teste réellement : Code TOTP valide → ACCEPTÉ ; Code TOTP invalide → REFUSÉ ; Code expiré → REFUSÉ.{"\n"}
                Après configuration : 🟢 Configuré doit rester après : refresh, logout, login, nouvelle session, PWA.{"\n"}
                Si le problème MFA n'est pas entièrement résolu : 🔴 NO-GO PRODUCTION.{"\n\n"}
                PHASE 4 — 🔴 AUTHENTIFICATION{"\n\n"}
                Tester : login valide, mauvais mot de passe, session expirée, logout, route protégée, token invalide, session invalide.{"\n"}
                Vérifier que les routes sensibles sont protégées côté serveur.{"\n\n"}
                PHASE 5 — 🔴 RBAC{"\n\n"}
                Inspecter tous les rôles et permissions.{"\n"}
                Tester réellement : lecture, création, modification, suppression, validation, paiement, export, administration.{"\n"}
                Vérifier que l'autorisation est contrôlée côté backend/API. Un bouton caché n'est PAS une sécurité.{"\n\n"}
                PHASE 6 — 🔴 ISOLATION DES DONNÉES{"\n\n"}
                Tester qu'un utilisateur ne peut jamais récupérer les données d'un autre utilisateur/tenant.{"\n"}
                Contrôler : clients, produits, ventes, factures, paiements, stock, livraisons, utilisateurs, documents, rapports.{"\n\n"}
                PHASE 7 — 🔴 BASE DE DONNÉES{"\n\n"}
                Auditer : tables, relations, foreign keys, constraints, indexes, migrations, transactions, RLS, policies.{"\n"}
                Rechercher les SELECT * et requêtes inutiles.{"\n\n"}
                PHASE 8 — 🔴 INTÉGRITÉ FINANCIÈRE{"\n\n"}
                Tester obligatoirement : Facture → Débit → Paiement → Crédit → Solde.{"\n"}
                Tester également : paiement total, partiel, annulation, avoir, relevé client. Aucun écart ne doit être accepté.{"\n\n"}
                PHASE 9 — 🔴 STOCK{"\n\n"}
                Tester : Achat (entrée), Vente (sortie), Retour client (entrée), Retour fournisseur (sortie), Annulation (contre-mouvement), Inventaire (ajustement).{"\n"}
                Comparer les stocks affichés avec les mouvements réels.{"\n\n"}
                PHASE 10 — 🔴 VENTES{"\n\n"}
                Tester : Proforma → Commande → BL → Facture → Paiement.{"\n"}
                Vérifier : quantités, prix, remises, totaux, références, numérotation, dates, statuts, client, stock.{"\n\n"}
                PHASE 11 — 🔴 DOCUMENTS PDF{"\n\n"}
                Générer réellement : Proforma, Facture, BC, BL, BR, Relevé.{"\n"}
                Contrôler : mise en page, totaux, QR, logo, pagination, impression A4.{"\n\n"}
                PHASE 12 — 🔴 LIVRAISONS{"\n\n"}
                Tester : Commande → Colisage → Préparation → Livreur → Tournée → Livraison → Preuve → Statut final.{"\n\n"}
                PHASE 13 — 🔴 PERFORMANCE{"\n\n"}
                Tu dois MESURER : Login, Dashboard, Clients, Produits, Ventes, Factures, Stock, Livraisons, Recherche, Rapports, PDF.{"\n"}
                Identifier : N+1 queries, SQL lentes, indexes manquants, API lentes, bundle lourd.{"\n\n"}
                PHASE 14 — OPTIMISATION{"\n\n"}
                Corriger en priorité : requêtes SQL lentes, N+1, absence de pagination, appels API répétés, gros payloads.{"\n\n"}
                PHASE 15 — PAGINATION{"\n\n"}
                Vérifier que les grandes listes ne chargent pas toutes les données. Pagination côté serveur.{"\n\n"}
                PHASE 16 — PWA{"\n\n"}
                Tester : installation, lancement, cache, mise à jour, login, MFA, service worker.{"\n\n"}
                PHASE 17 — BACKUP{"\n\n"}
                Vérifier : backup automatique, disponibilité, test de restauration. Un backup non testé = NON VALIDÉ.{"\n\n"}
                PHASE 18 — SÉCURITÉ{"\n\n"}
                Rechercher : secrets exposés, tokens dans logs, SQL injection, XSS, IDOR, routes API non protégées.{"\n\n"}
                PHASE 19 — TEST DE RÉGRESSION{"\n\n"}
                Exécuter une matrice de 110 TESTS couvrant tous les modules critiques.{"\n\n"}
                PHASE 20 — CORRECTION OBLIGATOIRE{"\n\n"}
                Identifier la cause, corriger, et relancer le test pour chaque FAIL.{"\n\n"}
                PHASE 21 — PREUVE AVANT GO{"\n\n"}
                Fournir la matrice complète (Auth, MFA, RBAC, DB, Finance, Stock, Perf, Backup, etc.).{"\n\n"}
                🚨 RÈGLE DE BLOCAGE AUTOMATIQUE{"\n\n"}
                Si l'un des éléments critiques (MFA, Auth, RBAC, Finance, Stock, Backup) est FAIL : 🔴 NO-GO PRODUCTION.{"\n\n"}
                PHASE 22 — RAPPORT FINAL{"\n\n"}
                Produire le rapport formaté avec décision GO/NO-GO et justification complète.{"\n\n"}
                🔥 ORDRE FINAL{"\n\n"}
                COMMENCE MAINTENANT. Ne demande pas, n'attends pas. Inspecte, trouve, corrige, teste et donne le verdict. Pas de GO sans preuves réelles.
              </CardDescription>
            </div>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center justify-between p-3 rounded-lg bg-muted/50 border">
            <div className="space-y-0.5">
              <Label className="text-sm font-semibold">Statut actuel</Label>
              <div className="flex items-center gap-2 mt-1">
                {mfa?.isSuperAdmin ? (
                  <Badge variant="secondary" className="bg-slate-100 text-slate-500 border-slate-200">
                    ⚪ EXEMPTÉ
                  </Badge>
                ) : mfa?.enrolled ? (
                  <Badge variant="default" className="bg-green-100 text-green-700 hover:bg-green-100 border-green-200">
                    🟢 Configuré
                  </Badge>
                ) : (
                  <Badge variant="outline" className="text-orange-600 border-orange-200 bg-orange-50">
                    🟠 Non configuré
                  </Badge>
                )}
              </div>
            </div>

            {!mfa?.isSuperAdmin && !mfa?.enrolled && (
              <Button onClick={() => navigate({ to: "/mfa/enroll" })}>
                Activer le MFA
              </Button>
            )}

            {mfa?.enrolled && (
              <div className="flex gap-2">
                <Button variant="outline" size="sm" onClick={() => navigate({ to: "/mfa/backup-codes" })}>
                  Codes de secours
                </Button>
                <Badge variant="outline" className="text-green-600 border-green-200">
                  <ShieldCheck className="h-3 w-3 mr-1" />
                  Sécurisé
                </Badge>
              </div>
            )}
          </div>

          {mfa?.isSuperAdmin && (
            <Alert className="bg-slate-50 border-slate-200">
              <ShieldAlert className="h-4 w-4 text-slate-500" />
              <AlertDescription className="text-slate-600 text-xs">
                En tant que Super Administrateur, vous êtes exempté de la validation MFA.
              </AlertDescription>
            </Alert>
          )}

          {!mfa?.enrolled && !mfa?.isSuperAdmin && (
            <p className="text-xs text-muted-foreground italic">
              Il est fortement recommandé d'activer le MFA pour sécuriser vos accès.
            </p>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
