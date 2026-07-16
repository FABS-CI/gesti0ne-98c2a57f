# 🚀 Déploiement du frontend

## Comparatif des hébergeurs

| Hébergeur | Runtime | Prix indicatif | Complexité | Recommandation |
|---|---|---|---|---|
| **Vercel** | Node.js / Edge | Gratuit → 20$/mois | ⭐ Facile | ✅ Recommandé |
| **Netlify** | Node.js / Edge | Gratuit → 19$/mois | ⭐ Facile | ✅ Bon choix |
| **Cloudflare Pages/Workers** | Cloudflare Workers | Gratuit → 5$/mois | ⭐⭐ Moyen | Bon si déjà utilisé |
| **Railway / Render** | Node.js | 5-20$/mois | ⭐ Facile | Bien pour petits volumes |
| **VPS (Hetzner, OVH, DigitalOcean)** | Node.js + Nginx | 5-20€/mois | ⭐⭐⭐ Avancé | Contrôle total |

## Option A — Vercel (recommandé)

### 1. Créer le projet
1. Aller sur https://vercel.com/ → **Add New → Project**
2. Importer votre repo GitHub
3. Vercel détecte automatiquement TanStack Start / Vite

### 2. Variables d'environnement
Dans **Settings → Environment Variables**, ajouter toutes les variables listées dans `.env.example` :
- `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`, `VITE_SUPABASE_PROJECT_ID`
- `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
- Tous les secrets tiers (Google OAuth côté Supabase, pas côté Vercel)

### 3. Build settings
- **Build command** : `bun run build` (ou `npm run build`)
- **Output directory** : `.output/public` (par défaut TanStack Start)
- **Install command** : `bun install` (ou `npm install`)
- **Node version** : 20.x

### 4. Deploy
Cliquer **Deploy**. Premier build : 3-5 min.

## Option B — Cloudflare Pages/Workers

TanStack Start supporte nativement Cloudflare Workers.

1. Créer compte Cloudflare
2. Dans Workers → **Create → Connect to Git**
3. Sélectionner le repo
4. Build command : `bun run build`
5. Output : `.output/public`
6. Compatibility flags : `nodejs_compat`
7. Ajouter les variables d'environnement dans **Settings → Variables**

## Option C — VPS avec Node.js

### Prérequis
- VPS Ubuntu 22.04+ avec 2 GB RAM min
- Domaine pointant vers l'IP
- Node.js 20+, Nginx, PM2

### Setup
```bash
# Sur le VPS
sudo apt update && sudo apt install -y nginx
curl -fsSL https://bun.sh/install | bash
sudo npm install -g pm2

# Clone + build
git clone https://github.com/<user>/<repo>.git /var/www/erp
cd /var/www/erp
bun install
bun run build

# Créer .env avec vos variables
nano .env

# Démarrer avec PM2
pm2 start ".output/server/index.mjs" --name erp
pm2 startup
pm2 save
```

### Config Nginx (`/etc/nginx/sites-available/erp`)
```nginx
server {
    listen 80;
    server_name gesti0ne.com www.gesti0ne.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/erp /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# SSL avec Let's Encrypt
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d gesti0ne.com -d www.gesti0ne.com
```

## Points d'attention communs

- **`vite.config.ts`** : peut avoir besoin d'ajustement selon le target (`node` vs `cloudflare-module`)
- **Adapter TanStack Start** : par défaut auto-détecté, sinon spécifier via `TSS_TARGET=node|cloudflare-module`
- **Timezone serveur** : configurer en UTC pour éviter les décalages sur les dates
- **Logs** : configurer Sentry/LogRocket ou équivalent pour le monitoring
- **Backups automatiques** : à activer dans Supabase (Settings → Database → Backups)
