# 🔐 Reconfigurer Google OAuth

L'application utilise actuellement le broker OAuth managé par Lovable. Après migration, vous devez configurer **votre propre Google OAuth** directement dans Supabase.

## 1. Créer les credentials Google

1. Aller sur https://console.cloud.google.com/
2. Créer un projet (ou réutiliser un existant)
3. **APIs & Services → Credentials → Create Credentials → OAuth Client ID**
4. Type : **Web application**
5. Nom : `ERP Gesti0ne`
6. **Authorized JavaScript origins** :
   - `https://votre-domaine.com`
   - `https://<votre-ref>.supabase.co`
7. **Authorized redirect URIs** :
   - `https://<votre-ref>.supabase.co/auth/v1/callback`
8. Sauvegarder → noter **Client ID** et **Client Secret**

## 2. Configurer Supabase

Dans **Supabase Dashboard → Authentication → Providers → Google** :
- Enabled : ✅
- Client ID : (collé depuis Google)
- Client Secret : (collé depuis Google)
- Sauvegarder

Dans **Authentication → URL Configuration** :
- **Site URL** : `https://votre-domaine.com`
- **Redirect URLs** (ajouter chacune) :
  - `https://votre-domaine.com`
  - `https://votre-domaine.com/**`
  - `https://votre-domaine.com/auth/callback` (si utilisé)

## 3. Adapter le code

Le code utilise actuellement `lovable.auth.signInWithOAuth("google", ...)` (via `@/integrations/lovable`).

⚠️ **Après migration**, ce package Lovable ne fonctionnera plus. Il faut remplacer par l'API Supabase native :

```typescript
// AVANT (Lovable Cloud)
import { lovable } from "@/integrations/lovable";
await lovable.auth.signInWithOAuth("google", {
  redirect_uri: window.location.origin,
});

// APRÈS (Supabase direct)
import { supabase } from "@/integrations/supabase/client";
const { data, error } = await supabase.auth.signInWithOAuth({
  provider: "google",
  options: {
    redirectTo: `${window.location.origin}/auth/callback`,
  },
});
```

**Fichiers à modifier** (rechercher dans le code) :
```bash
grep -r "lovable.auth" src/
grep -r "@/integrations/lovable" src/
```

## 4. Créer la route callback

Créer `src/routes/auth.callback.tsx` :

```tsx
import { createFileRoute, redirect } from "@tanstack/react-router";
import { useEffect } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useNavigate } from "@tanstack/react-router";

export const Route = createFileRoute("/auth/callback")({
  component: AuthCallback,
});

function AuthCallback() {
  const navigate = useNavigate();

  useEffect(() => {
    // Supabase auto-consume le token dans l'URL
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === "SIGNED_IN" && session) {
        navigate({ to: "/" });
      }
    });

    return () => subscription.unsubscribe();
  }, [navigate]);

  return <div>Connexion en cours...</div>;
}
```

## 5. Password Protection (HIBP)

Dans **Authentication → Providers → Email** :
- Activer **Password HIBP Check** (vérifie contre les fuites de mots de passe)
- Confirm email : ✅ (recommandé en prod)

## 6. Migration des utilisateurs existants

Les utilisateurs de `auth.users` du Lovable Cloud actuel **ne sont pas transférables tels quels** (les hash de mots de passe ne sont pas exportables).

**Solutions :**
- **A. Reset password global** : depuis le nouveau Supabase, créer les users via Admin API avec les mêmes emails, puis envoyer un reset password à tous
- **B. Réinscription** : demander à tous les utilisateurs de se réinscrire (plus simple mais impactant)
- **C. Google OAuth uniquement** : si tous les utilisateurs utilisent Google, ils se reconnectent sans effort

Recommandé pour un ERP avec peu d'utilisateurs : **option A**.

Script exemple :
```typescript
// À exécuter depuis un script Node avec SUPABASE_SERVICE_ROLE_KEY
import { createClient } from "@supabase/supabase-js";

const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
const oldUsers = [/* liste depuis export */];

for (const u of oldUsers) {
  await admin.auth.admin.createUser({
    email: u.email,
    email_confirm: true,
    user_metadata: u.metadata,
  });
  await admin.auth.resetPasswordForEmail(u.email);
}
```
