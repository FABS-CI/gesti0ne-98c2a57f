# Runbook Incidents — ERP FABS-CI V10

Procédures d'intervention en cas d'incident production.

---

## 1. Escalade

| Sévérité | Délai réponse | Responsable |
|---|---|---|
| **Critical** (site down, corruption données) | ≤ 15 min | Super-admin technique + direction |
| **Error** (fonctionnalité cassée) | ≤ 1 h | Super-admin technique |
| **Warning** (dégradation perf) | ≤ 4 h | Admin |
| **Info** | Prochain jour ouvré | Admin |

**Contacts** : à compléter par l'équipe (email, téléphone, canal Slack).

---

## 2. Diagnostic initial (5 min)

1. Ouvrir `/admin/slo` — vérifier erreurs 24 h, connexions actives, alertes ouvertes.
2. Ouvrir `/audit` — vérifier les dernières actions utilisateur.
3. Vérifier la console navigateur (F12) sur la page en erreur.

---

## 3. Rollback applicatif (site cassé après déploiement)

1. Aller dans Lovable → onglet **History** en haut à droite.
2. Identifier le dernier commit stable (avant l'incident).
3. Cliquer **Restore** sur cette version.
4. Le site est redéployé automatiquement (~1 min).
5. Créer une alerte de suivi : `POST /api/public/hooks/alert` avec `severity: info`, `title: "Rollback effectué"`.

**RTO** : ≤ 5 min.

---

## 4. Restauration base de données (PITR)

Supabase conserve un Point-In-Time Recovery de **7 jours**.

### Cas A — Corruption d'une table isolée

1. Identifier l'heure exacte avant corruption (via `/audit`).
2. Depuis le dashboard Supabase (accès équipe Lovable) → Database → Backups → **Point in Time**.
3. Choisir le timestamp cible, restaurer dans un projet clone.
4. Extraire la table via `pg_dump -t <table>` depuis le clone.
5. Réimporter dans production après validation.

**RTO** : 30-60 min. **RPO** : ≤ 2 min.

### Cas B — Corruption globale

1. Contacter Lovable Support immédiatement (procédure PITR complète).
2. Basculer l'app en mode maintenance (afficher bannière).
3. Attendre confirmation restauration (≤ 2 h).
4. Vérifier intégrité : compter les commandes/factures des dernières 24 h vs alertes reçues.

**RTO** : ≤ 2 h. **RPO** : ≤ 2 min.

---

## 5. Fuite de données / accès non autorisé

1. **Immédiat** — Révoquer les sessions actives : dashboard Supabase → Auth → Users → sign out all.
2. Rotation des clés API : `lovable_api_key--rotate_lovable_api_key`.
3. Rotation `ALERT_WEBHOOK_SECRET` et autres secrets exposés.
4. Audit trail : requête sur `audit_logs` sur la période suspecte.
5. Notifier les utilisateurs concernés sous 72 h (RGPD).

---

## 6. Performance dégradée

1. Ouvrir `/admin/slo` → onglet "Requêtes lentes".
2. Si une requête > 500 ms domine → ouvrir l'issue et créer un index.
3. Si connexions actives > 40 → identifier les longues transactions.
4. Vérifier la taille DB : si > 80 % du quota, purger `audit_logs` > 6 mois.

---

## 7. Emission d'alertes vers Slack/email

### Configuration webhook Slack (5 min)

1. Créer un webhook Slack : https://api.slack.com/messaging/webhooks
2. Ajouter le secret : `SLACK_ALERT_WEBHOOK_URL` (via tool `add_secret`).
3. Optionnel : ajouter `ALERT_WEBHOOK_SECRET` pour sécuriser l'endpoint entrant.
4. Test :

```bash
curl -X POST https://fabsci-gest.lovable.app/api/public/hooks/alert \
  -H "Content-Type: application/json" \
  -H "x-alert-secret: <SECRET>" \
  -d '{"source":"test","severity":"warning","title":"Test d'alerte"}'
```

### Format payload

```json
{
  "source": "cron | app | monitoring",
  "severity": "info | warning | error | critical",
  "title": "Titre court",
  "message": "Détail optionnel",
  "context": { "meta": "libre" }
}
```

---

## 8. Checklist post-incident

- [ ] Alerte résolue dans `/admin/slo` (bouton résoudre)
- [ ] Root cause documentée dans `docs/postmortems/AAAA-MM-JJ.md`
- [ ] Action préventive planifiée
- [ ] Communication utilisateurs si impact > 30 min

---

## Références

- Dashboard SLO : `/admin/slo`
- Audit : `/audit`
- Endpoint alertes : `POST /api/public/hooks/alert`
- Backup / restore : `/backup`
- Audit OWASP + DR : `docs/audit-owasp-dr.md`