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
                Oui. Pour ton ERP GESTI-ONE, je te conseille un prompt qui force le LLM à faire un audit de performance réel, et pas simplement à ajouter des loaders ou modifier quelques composants.

🚀 PROMPT — AUDIT PERFORMANCE COMPLET ET OPTIMISATION PRODUCTION — ERP GESTI-ONE

Tu es un architecte logiciel senior spécialisé en performance des ERP, PostgreSQL, API, React/TypeScript, Supabase et applications SaaS.

Tu dois réaliser un audit complet des performances de GESTI-ONE, identifier les véritables goulots d'étranglement et appliquer les optimisations nécessaires.

⚠️ RÈGLE PRINCIPALE

NE PAS faire d'optimisations superficielles.

Ne pas simplement ajouter :
- des loaders ;
- des animations ;
- des délais artificiels ;
- du cache partout ;
- des useMemo inutiles ;
- des useEffect supplémentaires ;
- des requêtes parallèles sans analyse ;
- de la pagination uniquement visuelle.

Je veux mesurer les performances, identifier les causes et corriger le problème à la source.

1. AUDIT GLOBAL
Analyse toute l'application : Frontend ↓ React / TypeScript ↓ Hooks / Context / State ↓ API ↓ Backend ↓ PostgreSQL / Supabase ↓ Indexes / Queries ↓ Infrastructure.

Audite particulièrement : temps de connexion ; chargement du dashboard ; navigation entre modules ; chargement des listes ; recherche ; filtres ; pagination ; création/modification de documents ; génération PDF ; rapports ; statistiques ; notifications ; authentification MFA ; gestion des utilisateurs ; RBAC ; ventes ; clients ; produits ; stocks ; achats ; livraisons ; facturation ; comptabilité.

2. MESURER AVANT DE MODIFIER
Avant toute optimisation, établis un état initial. Mesure notamment : TTFB, FCP, LCP, INP, CLS, API response time, Database query time, JavaScript execution time, Bundle size, Memory usage, Number of API calls, Number of database queries, Number of rows returned.

Ne remplis pas les valeurs avec des estimations : mesure réellement le projet.

3. AUDIT DU LOGIN & DASHBOARD
Le login doit être particulièrement rapide. Rechercher : requêtes inutiles ; appels API séquentiels ; récupération de toutes les permissions ; appels répétés ; refresh inutiles. Le dashboard ne doit pas charger toutes les données de l'ERP. Remplacer lorsque possible par des requêtes SQL agrégées (COUNT, SUM, AVG, GROUP BY).

4. AUDIT POSTGRESQL & INDEXATION
Inspecter toutes les requêtes SQL importantes. Rechercher : SELECT *, jointures coûteuses, filtres sans index, N+1 queries. Utiliser EXPLAIN ANALYZE. Auditer les indexes des tables principales. Toutes les grandes listes doivent utiliser une pagination serveur. NE PAS charger SELECT * FROM table puis paginer côté navigateur.

5. FRONTEND & API
Auditer les composants React (re-render inutiles, Context globaux). Mettre en place du lazy loading pour les gros modules. Optimiser en priorité les 20 % d'endpoints responsables de la majorité de la latence.

6. RAPPORT FINAL
Produire un SCORE PERFORMANCE global et un TOP 10 DES PROBLÈMES avec gain mesuré avant/après.

🟢 GO PRODUCTION ou 🔴 NO-GO PRODUCTION avec raisons précises.
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

