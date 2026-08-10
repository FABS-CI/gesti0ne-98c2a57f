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
                Voici le prompt maître pré-production que je te recommande de donner au LLM/Lovable. Il doit empêcher le passage en production tant que les points critiques ne sont pas validés.

🚨 GESTI-ONE — AUDIT FINAL PRÉ-PRODUCTION / GO-NO-GO

Tu es un architecte logiciel senior, ingénieur DevSecOps, expert ERP, PostgreSQL, Supabase, React/TypeScript, sécurité, performance et mise en production SaaS.

GESTI-ONE est un ERP destiné à une utilisation réelle en entreprise.

Ta mission est de réaliser l'audit final complet avant production, de corriger les anomalies bloquantes et de déterminer objectivement si l'application peut être mise en production.

⚠️ RÈGLE ABSOLUE

NE PAS déclarer GESTI-ONE prêt pour la production simplement parce que l'application démarre ou que les pages fonctionnent.

Tu dois vérifier :
Sécurité + Authentification + MFA + RBAC + Base de données + Intégrité des données + Comptabilité + Stock + Ventes + Documents + Livraisons + Performance + PWA + Sauvegardes + Monitoring + Tests

À la fin, tu dois obligatoirement produire :
🟢 GO PRODUCTION ou 🔴 NO-GO PRODUCTION

1. PHASE 0 — GEL DU PROJET
Avant l'audit :
ne pas ajouter de fonctionnalités non nécessaires ; ne pas modifier arbitrairement les règles métier ; ne pas supprimer de données ; ne pas contourner la sécurité ; ne pas masquer les erreurs ; ne pas remplacer une vraie correction par une modification visuelle.
L'objectif est maintenant :
STABILISER → TESTER → CORRIGER → VALIDER → PRODUIRE

2. CARTOGRAPHIE COMPLÈTE DU PROJET
Inspecter le projet complet.
Identifier : Frontend, Backend, API, Base de données, Authentification, MFA, RBAC, Supabase, PostgreSQL, Stockage fichiers, PDF, Realtime, PWA, Variables d'environnement, Migrations, Jobs, Webhooks, Services externes.
Produire une architecture réelle du système. Ne pas supposer l'architecture : inspecter le code.

3. 🔴 AUTHENTIFICATION
Tester : connexion ; déconnexion ; mauvais mot de passe ; session expirée ; renouvellement de session ; changement de mot de passe ; récupération de compte ; accès après déconnexion ; accès sans authentification.
Vérifier qu'aucune route sensible n'est accessible sans authentification.

4. 🔴 MFA — PRIORITÉ ABSOLUE
Le projet présente actuellement les problèmes :
❌ Code invalide — MFA
🟠 MFA Non configuré
Ils doivent être résolus avant toute mise en production.
Auditer entièrement : Génération secret → QR Code → Authenticator → Validation premier code → Stockage secret → mfa_enabled → Connexion → Validation TOTP → Session → Profil
Vérifier que : SECRET QR CODE = SECRET STOCKÉ = SECRET UTILISÉ POUR LA VALIDATION
Vérifier : TOTP ; Base32 ; algorithme ; période ; nombre de chiffres ; synchronisation horaire ; récupération du secret ; user_id ; persistance ; expiration ; réinitialisation.
Tester : Code valide → ACCEPTÉ ; Code invalide → REFUSÉ ; Code expiré → REFUSÉ ; Mauvais utilisateur → REFUSÉ.
Après configuration : 🟢 Configuré doit rester affiché après : actualisation ; déconnexion ; reconnexion ; nouvelle session ; PWA.
INTERDICTION : Ne jamais accepter n'importe quel code. Ne jamais désactiver MFA pour contourner le problème.

5. 🔴 RBAC / AUTORISATIONS
Auditer tous les rôles.
Vérifier : Utilisateur → Rôle → Module → Permission → Action
Tester notamment : lecture ; création ; modification ; suppression ; validation ; paiement ; export ; impression ; administration.
Un utilisateur non autorisé ne doit pas pouvoir appeler directement une API interdite. La sécurité doit être appliquée côté serveur, pas uniquement dans l'interface.

6. 🔴 ISOLATION DES DONNÉES
Vérifier qu'un utilisateur/tenant ne peut jamais accéder aux données d'un autre.
Tester : Clients, Produits, Ventes, Factures, Paiements, Stock, Livraisons, Utilisateurs, Documents, Rapports.
Auditer : RLS ; policies ; tenant_id ; user_id ; filtres backend ; endpoints ; exports ; PDF.

7. 🔴 BASE DE DONNÉES
Vérifier que la base réellement utilisée en production est celle prévue.
Auditer : migrations ; tables ; contraintes ; foreign keys ; indexes ; types ; valeurs NULL ; doublons ; données orphelines ; transactions.

8. 🔴 INTÉGRITÉ DES DONNÉES
Tester les relations : Client → Commande → Facture → Paiement → Solde et Produit → Stock → Vente → Mouvement stock.
Aucune opération ne doit créer de données incohérentes.

9. 🔴 COMPTABILITÉ / SOLDES CLIENTS
Tester plusieurs cas de facturation et paiements.
Vérifier : Débit, Crédit, Solde dans relevé client ; facture ; paiement ; dashboard ; rapports.

10. 🔴 STOCK
Tester : Achat (Entrée), Vente (Sortie), Retour client (Entrée), Retour fournisseur (Sortie), Annulation (Contre-mouvement), Inventaire (Ajustement).
Vérifier que chaque opération crée correctement son mouvement. Stock théorique = Stock réel calculé par mouvements.

11. 🔴 VENTES ET DOCUMENTS
Tester entièrement : Devis/Proforma → Commande → Bon de livraison → Facture → Paiement.
Vérifier : numérotation ; dates ; client ; représentant ; produits ; quantités ; prix ; remises ; taxes ; totaux.

12. 🔴 PDF
Tester : facture ; proforma ; bon de commande ; bon de livraison ; bon de réception ; relevé de compte ; catalogue ; rapports.
Vérifier : aucune coupure ; aucune superposition ; totaux corrects ; logo ; QR code ; pagination ; impression A4.

13. 🔴 LIVRAISONS / COLISAGE
Tester : Commande → Colisage → Préparation → Affectation livreur → Tournée → Livraison → Preuve → Statut final.
Vérifier que chaque changement de statut est cohérent et traçable.

14. 🔴 PERFORMANCE
Benchmark : Login, Dashboard, Clients, Produits, Ventes, Factures, Stock, Livraisons, Rapports, Recherche, PDF.
Rechercher : N+1 queries ; SELECT * ; requêtes SQL lentes ; absence d'index ; appels API répétés ; bundle trop lourd.

15. OBJECTIFS DE PERFORMANCE
UI < 100ms ; API simple < 500ms ; CRUD courant < 1s ; Dashboard < 2s ; Rapport complexe < 3s. Mesurer réellement.

16. PAGINATION
Toutes les grandes tables doivent être paginées côté serveur. Ne pas charger toute la table dans le navigateur.

17. RECHERCHE
La recherche doit être serveur-side.

18. FRONTEND
Auditer : re-renders ; hooks ; useEffect ; lazy loading ; code splitting ; bundle.

19. PWA
Tester : installation Android/Desktop ; cache ; mise à jour ; reconnexion ; authentification ; MFA.

20. SAUVEGARDE ET RESTAURATION
Backup automatique → Stockage sécurisé → Restauration testée. Faire un véritable test de restauration.

21. VARIABLES D'ENVIRONNEMENT
Auditer les secrets (Git, Frontend, Production). Rotation possible des secrets.

22. LOGS ET MONITORING
Monitoring des erreurs critiques. Ne jamais enregistrer de mots de passe ou tokens.

23. TEST DE CHARGE
Tester avec 10, 25 et 50 utilisateurs simultanés. Mesurer latence, erreurs, CPU, RAM, DB.

24. TEST DE RÉGRESSION
Créer une suite de 110 TESTS couvrant tous les modules. Chaque test doit être documenté (PASS/FAIL).

25. DONNÉES DE PRODUCTION
Vérifier doublons, clients, produits, stocks, factures, paiements, soldes avant migration.

26. PLAN DE ROLLBACK
Préparer et documenter la procédure de retour en version stable.

27. CHECKLIST FINALE
Vérifier tous les points : Authentification, MFA, RBAC, DB, Données, Finance, Stock, Ventes, PDF, Performance, PWA, Backup, Monitoring, Sécurité.

28. RÈGLE DE DÉCISION
🔴 NO-GO si un seul problème critique existe.
🟢 GO PRODUCTION uniquement si tous les points sont validés (✅).

29. RAPPORT FINAL OBLIGATOIRE
Produire le rapport formaté AUDIT FINAL GESTI-ONE avec décision finale GO/NO-GO et justification.

🚨 CONSIGNE FINALE
Analyse basée sur le code réel, la base réelle, les requêtes réelles et les flux réels.
SÉCURITÉ → INTÉGRITÉ DES DONNÉES → FIABILITÉ → PERFORMANCE.
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

