# 🔑 Variables d'environnement et secrets

## Variables obligatoires

### Côté client (préfixe `VITE_`, exposées au navigateur)
```
VITE_SUPABASE_URL=https://<votre-ref>.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxxxxxxxxxxxxxxxxxxx
VITE_SUPABASE_PROJECT_ID=<votre-ref>
```

### Côté serveur (jamais exposées au navigateur)
```
SUPABASE_URL=https://<votre-ref>.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxxxxxxxxxxxxxxxxxxx
SUPABASE_SERVICE_ROLE_KEY=sb_secret_xxxxxxxxxxxxxxxxxxxx
SUPABASE_PROJECT_ID=<votre-ref>
```

⚠️ **`SUPABASE_SERVICE_ROLE_KEY`** contourne RLS. À stocker uniquement côté serveur (Vercel Environment Variables, Cloudflare Secrets, ou `.env` sur VPS avec permissions restreintes).

## Secrets à récupérer / recréer

Ouvrez **Project Settings → Secrets** dans Lovable pour voir la liste. Pour chacun, notez si :
- ✅ Vous pouvez retrouver la valeur (dashboard tiers) → à re-saisir dans le nouvel hébergeur
- ❌ Valeur perdue → régénérer depuis le service tiers

### Secrets fréquemment utilisés (à vérifier dans votre projet)
```
# Google OAuth (côté Supabase, PAS côté hébergeur)
# → à configurer dans Supabase Auth → Providers → Google

# FNE (facturation électronique Côte d'Ivoire)
FNE_API_KEY=...
FNE_API_URL=...

# Email transactionnel (si utilisé)
RESEND_API_KEY=...
# ou
SENDGRID_API_KEY=...

# SMS (si utilisé)
TWILIO_ACCOUNT_SID=...
TWILIO_AUTH_TOKEN=...

# IA (si vous utilisiez Lovable AI Gateway)
# → à remplacer par une clé directe OpenAI/Anthropic
OPENAI_API_KEY=...
# ou
ANTHROPIC_API_KEY=...

# Webhooks (signatures)
WEBHOOK_SECRET=<générer avec: openssl rand -hex 32>
```

## Où configurer selon l'hébergeur

| Hébergeur | Où saisir |
|---|---|
| Vercel | Settings → Environment Variables (Production/Preview/Dev) |
| Netlify | Site settings → Environment variables |
| Cloudflare Workers | Settings → Variables and Secrets |
| VPS | Fichier `.env` avec `chmod 600` + PM2 `--update-env` |
| Supabase (auth) | Auth → Providers pour OAuth ; Auth → URL Configuration pour Site URL |

## ⚠️ Erreurs à éviter

1. **Ne jamais commit `.env`** dans Git — vérifier que `.gitignore` contient `.env` et `.env.local`
2. **Ne jamais renommer `SUPABASE_SERVICE_ROLE_KEY` en `VITE_...`** — ce serait exposer la clé au navigateur (faille critique)
3. **Séparer les environnements** dev / staging / prod avec des projets Supabase distincts si possible
4. **Rotation** : prévoir un plan de rotation des secrets tous les 6-12 mois

## Vérifier que les variables sont bien lues

Après déploiement, un simple test :
```typescript
// Dans une server function
export const testEnv = createServerFn().handler(() => {
  return {
    hasUrl: !!process.env.SUPABASE_URL,
    hasKey: !!process.env.SUPABASE_PUBLISHABLE_KEY,
    hasServiceKey: !!process.env.SUPABASE_SERVICE_ROLE_KEY,
    // ⚠️ NE JAMAIS retourner les valeurs, juste les booléens
  };
});
```
