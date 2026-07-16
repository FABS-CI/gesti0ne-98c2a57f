# 🌐 Domaine et DNS

## Contexte

Votre domaine actuel (ex: `gesti0ne.com`) pointe probablement vers Lovable. Après migration, il faut le repointer vers le nouvel hébergeur.

## Étape 1 — Préparer avant bascule

**Ne pas repointer le DNS tant que le nouveau site n'est pas testé et fonctionnel.**

1. Déployer le nouveau frontend sur une URL temporaire (ex: `erp-nouveau.vercel.app`)
2. Tester complètement :
   - Login email + Google
   - CRUD principales
   - Livraisons, factures, paiements
   - Génération PDF
3. Configurer le domaine côté hébergeur (Vercel/CF/etc.) **avant** de changer les DNS

## Étape 2 — Configuration selon l'hébergeur

### Vercel
1. Projet → **Settings → Domains → Add**
2. Entrer `gesti0ne.com` et `www.gesti0ne.com`
3. Vercel affiche les enregistrements DNS à créer :
   - Pour le domaine racine : **A record** vers l'IP Vercel indiquée
   - Pour `www` : **CNAME** vers `cname.vercel-dns.com`

### Cloudflare Pages
1. Projet → **Custom domains → Set up a domain**
2. Cloudflare configure automatiquement si le DNS est déjà chez CF
3. Sinon, créer un **CNAME** vers `<projet>.pages.dev`

### VPS
1. Créer un **A record** `gesti0ne.com` → IP du VPS
2. Créer un **A record** `www.gesti0ne.com` → IP du VPS
3. Lancer Certbot pour SSL (voir `05-frontend-deploiement.md`)

## Étape 3 — Bascule DNS

1. Aller chez votre registrar (Namecheap, OVH, GoDaddy, Cloudflare DNS...)
2. **Supprimer** les anciens enregistrements pointant vers Lovable
3. **Ajouter** les nouveaux enregistrements fournis par Vercel/CF/VPS
4. Baisser le **TTL** à 300 secondes 24h avant la bascule pour propagation rapide

## Étape 4 — Attendre la propagation

- Généralement 15 min à 2h
- Peut prendre jusqu'à 72h dans certains cas
- Vérifier avec https://dnschecker.org/

## Étape 5 — SSL

- **Vercel / Netlify / CF** : SSL automatique via Let's Encrypt (rien à faire)
- **VPS** : `sudo certbot --nginx -d gesti0ne.com -d www.gesti0ne.com`

## Étape 6 — Mise à jour Supabase

Une fois le nouveau domaine actif, retourner dans **Supabase → Authentication → URL Configuration** :
- Mettre à jour **Site URL** avec le domaine final
- Ajouter les nouveaux **Redirect URLs**
- Retirer les anciennes URLs Lovable (`*.lovable.app`) si présentes

Et dans **Google Cloud Console → OAuth credentials** :
- Ajouter le domaine final dans **Authorized JavaScript origins**
- L'URL Supabase de callback reste identique

## Étape 7 — Anciennes URLs

Après quelques jours de fonctionnement stable :
- Vous pouvez unpublisher le site Lovable (Project settings → Unpublish)
- Ou le garder en lecture seule le temps de la transition

## Redirections SEO (optionnel)

Si vous voulez rediriger `www` vers le domaine racine (ou l'inverse) :

**Vercel** : Settings → Domains → Redirect
**Nginx** :
```nginx
server {
    server_name www.gesti0ne.com;
    return 301 https://gesti0ne.com$request_uri;
}
```
