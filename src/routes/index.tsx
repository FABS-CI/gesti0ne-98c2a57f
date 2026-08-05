import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";

export const Route = createFileRoute("/")({
  component: IndexRedirect,
});

function IndexRedirect() {
  return (
    <div className="container mx-auto max-w-4xl p-8 prose dark:prose-invert">
      <p>Tu es mandaté pour réaliser <strong>l'audit final avant mise en production</strong> de cet ERP.</p>
      <p>Ce n'est <strong>pas un audit de code classique</strong>.</p>
      <p>Tu dois agir comme un cabinet d'audit spécialisé dans les ERP critiques (SAP, Odoo Enterprise, Microsoft Dynamics 365, Oracle ERP).</p>
      <p>Considère que demain matin le système sera utilisé en production par :</p>
      <ul>
        <li>plusieurs entreprises</li>
        <li>plusieurs agences</li>
        <li>plusieurs dépôts</li>
        <li>plusieurs caissiers</li>
        <li>plusieurs comptables</li>
        <li>plusieurs commerciaux</li>
        <li>plusieurs administrateurs</li>
      </ul>
      <p>Le système doit pouvoir fonctionner <strong>24h/24</strong> sans perte de données.</p>
      <p>Une seule erreur peut entraîner :</p>
      <ul>
        <li>pertes financières</li>
        <li>erreurs comptables</li>
        <li>pertes de stock</li>
        <li>pertes de données</li>
        <li>litiges clients</li>
        <li>indisponibilité du système</li>
      </ul>
      <p>Tu dois considérer que <strong>tout est critique</strong>.</p>

      <hr className="my-8" />

      <h1 id="ta-mission">TA MISSION</h1>
      <p>Tu dois parcourir <strong>100 % du projet</strong>, sans exception :</p>
      <ul>
        <li>Frontend</li>
        <li>Backend</li>
        <li>Base PostgreSQL</li>
        <li>Supabase</li>
        <li>RPC</li>
        <li>React</li>
        <li>Hooks</li>
        <li>API</li>
        <li>Middleware</li>
        <li>PDF</li>
        <li>Authentification</li>
        <li>RBAC</li>
        <li>Workflows</li>
        <li>Calculs</li>
        <li>Scripts</li>
        <li>CI/CD</li>
        <li>Android Capacitor</li>
        <li>Configuration</li>
        <li>Variables d'environnement</li>
        <li>Dépendances</li>
      </ul>
      <p>Ne jamais supposer.</p>
      <p>Tout ce que tu affirmes doit être :</p>
      <ul>
        <li>vérifié</li>
        <li>localisé</li>
        <li>expliqué</li>
        <li>justifié</li>
      </ul>

      <hr className="my-8" />

      <h1 id="phase-1-%E2%80%94-architecture">PHASE 1 — ARCHITECTURE</h1>
      <p>Auditer :</p>
      <ul>
        <li>architecture globale</li>
        <li>découpage métier</li>
        <li>Clean Architecture</li>
        <li>SOLID</li>
        <li>DDD</li>
        <li>modularité</li>
        <li>dette technique</li>
        <li>duplication</li>
        <li>dépendances circulaires</li>
        <li>anti-patterns</li>
        <li>responsabilités</li>
      </ul>
      <p>Attribuer un score.</p>

      <hr className="my-8" />

      <h1 id="phase-2-%E2%80%94-analyse-statique">PHASE 2 — ANALYSE STATIQUE</h1>
      <p>Chercher :</p>
      <ul>
        <li>code mort</li>
        <li>imports inutilisés</li>
        <li>composants inutilisés</li>
        <li>routes inutilisées</li>
        <li>endpoints inutilisés</li>
        <li>fonctions inutilisées</li>
        <li>TODO</li>
        <li>FIXME</li>
        <li>console.log</li>
        <li>print()</li>
        <li>debug</li>
        <li>any</li>
        <li>casts dangereux</li>
        <li>memory leaks</li>
        <li>erreurs silencieuses</li>
      </ul>
      <p><strong>Contrôler spécifiquement</strong> les occurrences de <code>as any</code> et proposer leur remplacement par des types sûrs lorsqu'elles touchent des modules métier critiques.</p>

      <hr className="my-8" />

      <h1 id="phase-3-%E2%80%94-base-de-donn%C3%A9es">PHASE 3 — BASE DE DONNÉES</h1>
      <p>Auditer :</p>
      <ul>
        <li>contraintes</li>
        <li>index</li>
        <li>clés étrangères</li>
        <li>transactions</li>
        <li>rollback</li>
        <li>unicité</li>
        <li>cascade</li>
        <li>performances SQL</li>
        <li>requêtes lentes</li>
        <li>N+1</li>
        <li>normalisation</li>
        <li>migrations</li>
        <li>sauvegardes</li>
        <li>restauration</li>
      </ul>
      <p><strong>Contrôler également :</strong></p>
      <ul>
        <li>nombre de migrations</li>
        <li>cohérence chronologique</li>
        <li>possibilité de rejouer toutes les migrations sur une base vierge</li>
        <li>génération d'une baseline SQL</li>
        <li>dépendances entre migrations</li>
      </ul>
      <p>Le rapport précédent a identifié un volume important de migrations et recommande la création d'un schéma de référence consolidé ; vérifier ce point et confirmer s'il est résolu.</p>

      <hr className="my-8" />

      <h1 id="phase-4-%E2%80%94-rbac">PHASE 4 — RBAC</h1>
      <p>Contrôler :</p>
      <ul>
        <li>permissions</li>
        <li>rôles</li>
        <li>héritage</li>
        <li>propagation</li>
      </ul>
      <p>Vérifier :</p>
      <ul>
        <li>permissions orphelines</li>
        <li>permissions sans écran</li>
        <li>écrans sans permission</li>
        <li>routes sans protection</li>
        <li>API sans contrôle</li>
      </ul>
      <p>Comparer :</p>
      <p>Permissions<br />↓<br />Routes<br />↓<br />Menus<br />↓<br />Composants<br />↓<br />RPC<br />↓<br />Policies RLS</p>
      <p>Identifier toute permission exposée dans l'administration mais sans fonctionnalité réellement accessible. Vérifier en particulier les modules de trésorerie, livraisons, avoirs, paie, intégrations et prospects.</p>

      <hr className="my-8" />

      <h1 id="phase-5-%E2%80%94-workflow">PHASE 5 — WORKFLOW</h1>
      <p>Tester tous les parcours.</p>
      <p>Prospect<br />↓<br />Client<br />↓<br />Devis<br />↓<br />Commande<br />↓<br />Réservation<br />↓<br />Préparation<br />↓<br />Colisage<br />↓<br />Livraison<br />↓<br />Facture<br />↓<br />Paiement<br />↓<br />Comptabilité<br />↓<br />Archivage</p>
      <p>Chercher :</p>
      <ul>
        <li>états impossibles</li>
        <li>transitions manquantes</li>
        <li>validations absentes</li>
        <li>blocages</li>
        <li>boucles</li>
        <li>doublons</li>
        <li>suppressions dangereuses</li>
        <li>workflow cassé</li>
      </ul>

      <hr className="my-8" />

      <h1 id="phase-6-%E2%80%94-stock">PHASE 6 — STOCK</h1>
      <p>Tester :</p>
      <ul>
        <li>rupture</li>
        <li>stock négatif</li>
        <li>réservations</li>
        <li>inventaires</li>
        <li>transferts</li>
        <li>corrections</li>
        <li>retours</li>
        <li>avoirs</li>
        <li>annulations</li>
        <li>multi dépôts</li>
      </ul>
      <p>Vérifier que les quantités restent cohérentes après chaque opération.</p>

      <hr className="my-8" />

      <h1 id="phase-7-%E2%80%94-comptabilit%C3%A9">PHASE 7 — COMPTABILITÉ</h1>
      <p>Vérifier :</p>
      <ul>
        <li>écritures équilibrées</li>
        <li>journal</li>
        <li>grand livre</li>
        <li>balance</li>
        <li>comptes clients</li>
        <li>comptes fournisseurs</li>
        <li>TVA</li>
        <li>remises</li>
        <li>avoirs</li>
        <li>paiements partiels</li>
        <li>paiements multiples</li>
        <li>annulations</li>
      </ul>
      <p>Aucune facture ne doit produire une écriture incorrecte.</p>

      <hr className="my-8" />

      <h1 id="phase-8-%E2%80%94-tests-m%C3%A9tier">PHASE 8 — TESTS MÉTIER</h1>
      <p>Créer des centaines de scénarios.</p>
      <p>Exemples :</p>
      <ul>
        <li>100000 clients</li>
        <li>500000 articles</li>
        <li>0 article</li>
        <li>stock nul</li>
        <li>stock négatif</li>
        <li>prix négatif</li>
        <li>TVA absente</li>
        <li>client supprimé</li>
        <li>produit supprimé</li>
        <li>double clic</li>
        <li>double paiement</li>
        <li>double facture</li>
        <li>double livraison</li>
        <li>double impression</li>
        <li>double encaissement</li>
      </ul>

      <hr className="my-8" />

      <h1 id="phase-9-%E2%80%94-tests-de-concurrence">PHASE 9 — TESTS DE CONCURRENCE</h1>
      <p>Simuler :</p>
      <ul>
        <li>10</li>
        <li>50</li>
        <li>100</li>
        <li>500</li>
        <li>1000 utilisateurs</li>
      </ul>
      <p>Chercher :</p>
      <ul>
        <li>deadlocks</li>
        <li>race conditions</li>
        <li>rollback</li>
        <li>perte de données</li>
        <li>conflits</li>
      </ul>
      <p>Tester explicitement les mécanismes d'idempotence sur les opérations critiques afin de confirmer qu'aucun doublon ne peut être créé lors de doubles soumissions ou de reprises après incident.</p>

      <hr className="my-8" />

      <h1 id="phase-10-%E2%80%94-api">PHASE 10 — API</h1>
      <p>Auditer :</p>
      <ul>
        <li>validation</li>
        <li>pagination</li>
        <li>tri</li>
        <li>filtre</li>
        <li>cache</li>
        <li>versionning</li>
        <li>timeouts</li>
        <li>journalisation</li>
        <li>codes HTTP</li>
        <li>messages d'erreur</li>
      </ul>

      <hr className="my-8" />

      <h1 id="phase-11-%E2%80%94-frontend">PHASE 11 — FRONTEND</h1>
      <p>Contrôler :</p>
      <ul>
        <li>React</li>
        <li>Hooks</li>
        <li>Memo</li>
        <li>Suspense</li>
        <li>Lazy Loading</li>
        <li>Virtualisation</li>
        <li>Responsive</li>
        <li>Navigation</li>
        <li>Messages</li>
        <li>Chargements</li>
        <li>Memory leaks</li>
      </ul>

      <hr className="my-8" />

      <h1 id="phase-12-%E2%80%94-pdf">PHASE 12 — PDF</h1>
      <p>Tester :</p>
      <ul>
        <li>Facture</li>
        <li>Pro Forma</li>
        <li>Devis</li>
        <li>BL</li>
        <li>BC</li>
        <li>Avoir</li>
        <li>Reçu</li>
        <li>Rapports</li>
      </ul>
      <p>Contrôler :</p>
      <ul>
        <li>pagination</li>
        <li>logo</li>
        <li>totaux</li>
        <li>arrondis</li>
        <li>QR Code</li>
        <li>signature</li>
        <li>cachet</li>
      </ul>

      <hr className="my-8" />

      <h1 id="phase-13-%E2%80%94-s%C3%A9curit%C3%A9">PHASE 13 — SÉCURITÉ</h1>
      <p>Audit OWASP complet :</p>
      <ul>
        <li>XSS</li>
        <li>CSRF</li>
        <li>Injection SQL</li>
        <li>Injection NoSQL</li>
        <li>JWT</li>
        <li>RLS</li>
        <li>RBAC</li>
        <li>Cookies</li>
        <li>Secrets</li>
        <li>Variables d'environnement</li>
        <li>Bruteforce</li>
        <li>Headers</li>
        <li>Upload</li>
        <li>Téléchargement</li>
        <li>Rate limiting</li>
        <li>Escalade de privilèges</li>
      </ul>

      <hr className="my-8" />

      <h1 id="phase-14-%E2%80%94-performance">PHASE 14 — PERFORMANCE</h1>
      <p>Mesurer :</p>
      <ul>
        <li>login</li>
        <li>dashboard</li>
        <li>facture</li>
        <li>commande</li>
        <li>stock</li>
        <li>recherche</li>
        <li>PDF</li>
        <li>imports</li>
        <li>exports</li>
        <li>CPU</li>
        <li>RAM</li>
      </ul>

      <hr className="my-8" />

      <h1 id="phase-15-%E2%80%94-r%C3%A9silience">PHASE 15 — RÉSILIENCE</h1>
      <p>Tester :</p>
      <ul>
        <li>perte réseau</li>
        <li>coupure serveur</li>
        <li>coupure DB</li>
        <li>timeout</li>
        <li>reprise</li>
        <li>rollback</li>
        <li>autosave</li>
        <li>brouillons</li>
      </ul>

      <hr className="my-8" />

      <h1 id="phase-16-%E2%80%94-ci-cd">PHASE 16 — CI/CD</h1>
      <p>Contrôler :</p>
      <ul>
        <li>GitHub Actions</li>
        <li>Pipeline</li>
        <li>Lint</li>
        <li>Typecheck</li>
        <li>Tests</li>
        <li>Build</li>
        <li>Déploiement</li>
        <li>Rollback</li>
      </ul>
      <p>Vérifier que le pipeline couvre tous les modules critiques (stock, paie, logistique, FNE, etc.) et pas uniquement la facturation. Vérifier également qu'un build complet et les tests pré-déploiement sont bloquants avant toute mise en production.</p>

      <hr className="my-8" />

      <h1 id="phase-17-%E2%80%94-observabilit%C3%A9">PHASE 17 — OBSERVABILITÉ</h1>
      <p>Contrôler :</p>
      <ul>
        <li>Logs</li>
        <li>Monitoring</li>
        <li>Métriques</li>
        <li>Alertes</li>
        <li>Crash</li>
        <li>Traçabilité</li>
        <li>Audit Trail</li>
      </ul>

      <hr className="my-8" />

      <h1 id="phase-18-%E2%80%94-ux">PHASE 18 — UX</h1>
      <p>Chercher :</p>
      <ul>
        <li>clics inutiles</li>
        <li>écrans confus</li>
        <li>chargements infinis</li>
        <li>messages incomplets</li>
        <li>workflow trop long</li>
        <li>navigation difficile</li>
      </ul>

      <hr className="my-8" />

      <h1 id="phase-19-%E2%80%94-plan-de-correction">PHASE 19 — PLAN DE CORRECTION</h1>
      <p>Pour chaque anomalie produire :</p>
      <ul>
        <li>ID</li>
        <li>Gravité</li>
        <li>Priorité (P0 à P3)</li>
        <li>Module</li>
        <li>Description</li>
        <li>Cause</li>
        <li>Impact métier</li>
        <li>Impact technique</li>
        <li>Risque</li>
        <li>Fichiers concernés</li>
        <li>Proposition de correction</li>
        <li>Estimation</li>
        <li>Dépendances</li>
        <li>Tests à ajouter</li>
      </ul>

      <hr className="my-8" />

      <h1 id="phase-20-%E2%80%94-checklist-go-live">PHASE 20 — CHECKLIST GO-LIVE</h1>
      <p>Produire une checklist exhaustive :</p>
      <ul>
        <li>Base de données validée</li>
        <li>Migrations validées</li>
        <li>Sauvegardes testées</li>
        <li>Restauration testée</li>
        <li>Permissions validées</li>
        <li>API validées</li>
        <li>PDF validées</li>
        <li>Android validé</li>
        <li>Performance validée</li>
        <li>Monitoring actif</li>
        <li>Logs actifs</li>
        <li>Alertes configurées</li>
        <li>Documentation disponible</li>
        <li>Rollback testé</li>
        <li>Plan de reprise d'activité validé</li>
      </ul>

      <hr className="my-8" />

      <h1 id="phase-21-%E2%80%94-rapport-final">PHASE 21 — RAPPORT FINAL</h1>
      <p>Produire :</p>
      <h3 id="score-global">Score global</h3>
      <p>Architecture<br />Backend<br />Frontend<br />DB<br />Sécurité<br />Performance<br />UX<br />Comptabilité<br />Stock<br />Logistique<br />CI/CD<br />Tests<br />Documentation<br />Maintenabilité<br />Production Readiness</p>

      <hr className="my-8" />

      <h3 id="tableau-des-anomalies">Tableau des anomalies</h3>
      <ul>
        <li>P0</li>
        <li>P1</li>
        <li>P2</li>
        <li>P3</li>
      </ul>

      <hr className="my-8" />

      <h3 id="top-20-des-risques-majeurs">Top 20 des risques majeurs</h3>
      <p>Classés par :</p>
      <ul>
        <li>probabilité</li>
        <li>impact</li>
        <li>criticité</li>
      </ul>

      <hr className="my-8" />

      <h3 id="go-no-go">GO / NO GO</h3>
      <p>Conclure obligatoirement par <strong>une seule</strong> des décisions suivantes :</p>
      <ul>
        <li>✅ GO</li>
        <li>⚠️ GO SOUS CONDITIONS</li>
        <li>❌ NO GO</li>
      </ul>
      <p>La décision doit être justifiée par des éléments vérifiés dans le code. Aucun problème critique ne doit être omis et chaque recommandation doit être directement exploitable par l'équipe de développement avant la mise en production.</p>
    </div>
  );
}

