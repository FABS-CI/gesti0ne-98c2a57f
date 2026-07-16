# ✅ Vérifications post-migration

## Tests fonctionnels à passer

### Auth
- [ ] Login email/password fonctionne
- [ ] Login Google fonctionne et redirige au bon endroit
- [ ] Signup crée bien un user + profile
- [ ] Password reset envoie un email
- [ ] Logout nettoie bien la session
- [ ] Routes `/_authenticated/*` refusent l'accès non connecté

### RBAC
- [ ] Un `super_admin` accède à tout
- [ ] Un `comptable` voit factures mais pas RH
- [ ] Un `gestionnaire_stock` voit stocks mais pas paiements
- [ ] La table `user_roles` contient les bons rôles
- [ ] Les fonctions `has_role()` répondent correctement

### Modules métier
- [ ] Créer un client → apparaît dans la liste
- [ ] Créer une commande → lignes + totaux corrects
- [ ] Convertir proforma → commande
- [ ] Générer un BL depuis commande
- [ ] Faire un colisage → colis créés
- [ ] Créer une facture → PDF généré
- [ ] Enregistrer un paiement → solde client mis à jour
- [ ] Créer un achat → réception → stock incrémenté
- [ ] Faire un transfert entre dépôts
- [ ] Consulter dashboard → KPIs affichés
- [ ] Créer inventaire → régulariser → stock ajusté

### Storage (si utilisé)
- [ ] Upload document dans commande/facture
- [ ] Téléchargement PDF facture
- [ ] Photos employés/produits accessibles

### Audit & sécurité
- [ ] `audit_logs` reçoit bien les événements
- [ ] `login_history` trace les connexions
- [ ] RLS bloque un utilisateur d'accéder aux données d'un autre client

## Monitoring à mettre en place

### Logs applicatifs
- **Vercel** : Logs onglet dans le dashboard
- **VPS** : `pm2 logs erp` + `journalctl -u nginx`
- Considérer **Sentry** (gratuit jusqu'à 5k events/mois) pour catcher les erreurs prod

### Logs Supabase
- Dashboard → **Logs & Analytics** → Postgres, Auth, API
- Configurer des alertes sur les erreurs 500

### Sauvegardes
- Supabase Cloud → **Database → Backups** : activer daily backups (plan Pro ou +)
- Self-hosted : configurer `pg_dump` en cron :
  ```bash
  0 3 * * * pg_dump -Fc "$DATABASE_URL" > /backups/erp-$(date +\%F).dump
  ```
- Tester une **restauration** au moins une fois

### Uptime monitoring
- **UptimeRobot** ou **Better Uptime** (gratuit) : ping toutes les 5 min sur `/`
- Alertes email/SMS en cas de downtime

## Performance à surveiller

- **P95 latence** < 500ms sur les pages principales
- **Requêtes DB lentes** : Supabase → Reports → Query Performance
- Ajouter des **indexes** si certaines requêtes deviennent lentes après montée en volume

## Sécurité en continu

- Rotation des secrets tous les 6-12 mois
- Mise à jour des dépendances : `bun update` tous les mois
- Audit RLS après chaque nouvelle table :
  ```sql
  SELECT tablename FROM pg_tables WHERE schemaname='public' AND rowsecurity = false;
  ```
- Revue trimestrielle des rôles RBAC (qui a accès à quoi)

## En cas de problème

**"Impossible de me connecter avec Google"**
- Vérifier `redirect_uri` dans Google Console = `https://<ref>.supabase.co/auth/v1/callback`
- Vérifier Site URL dans Supabase Auth
- Vider cache navigateur

**"Erreur 401 sur toutes les requêtes"**
- Vérifier que `functionMiddleware` attache bien le bearer token
- Vérifier que `VITE_SUPABASE_URL` et `VITE_SUPABASE_PUBLISHABLE_KEY` sont bien injectés au build

**"Erreur permission_denied sur une table"**
- Vérifier RLS activé et policies scopées à `auth.uid()`
- Vérifier les `GRANT` sur la table

**"Build échoue sur Vercel/CF"**
- Vérifier Node version 20+
- Vérifier que `bun.lock` est bien commité
- Vérifier target TanStack Start (`node` vs `cloudflare-module`)

## Support à long terme

- Documenter dans un **Runbook** interne : comment ajouter un user, comment restaurer un backup, comment déployer une nouvelle version
- Former **au moins 2 personnes** sur l'admin Supabase + hébergeur
- Garder un accès **read-only** sur l'ancien Lovable Cloud 30 jours "au cas où"
