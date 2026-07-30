
-- 1) Super admin : toutes les permissions du catalogue
INSERT INTO public.rbac2_role_perms (role_code, perm_code, granted)
SELECT 'super_admin', p.code, true FROM public.rbac2_permissions p
ON CONFLICT (role_code, perm_code) DO UPDATE SET granted = true;

-- 2) Direction générale : toutes les lectures
INSERT INTO public.rbac2_role_perms (role_code, perm_code, granted)
SELECT 'directeur_general', p.code, true FROM public.rbac2_permissions p
WHERE p.action IN ('voir','voir_historique','exporter_pdf','exporter')
ON CONFLICT (role_code, perm_code) DO UPDATE SET granted = true;

-- 3) Dashboard visible par tous les rôles
INSERT INTO public.rbac2_role_perms (role_code, perm_code, granted)
SELECT r.code, p.code, true FROM public.rbac2_roles r
CROSS JOIN public.rbac2_permissions p
WHERE p.code IN ('dashboard.voir')
ON CONFLICT (role_code, perm_code) DO UPDATE SET granted = true;

-- 4) Comptabilité
INSERT INTO public.rbac2_role_perms (role_code, perm_code, granted)
SELECT rc, pc, true FROM (
  SELECT unnest(ARRAY['comptable','assistante_comptable']) AS rc
) r, unnest(ARRAY[
  'compta_dashboard.voir','ecritures_comptables.voir','etats_comptables.voir',
  'exercices.voir','finances.voir','rapports_comptables.voir','rapports.voir',
  'etat_compte_clients.voir','fne.voir','exports.voir','centre_documents.voir'
]) AS pc
WHERE EXISTS (SELECT 1 FROM public.rbac2_permissions p WHERE p.code = pc)
ON CONFLICT (role_code, perm_code) DO UPDATE SET granted = true;

-- 5) Ressources Humaines
INSERT INTO public.rbac2_role_perms (role_code, perm_code, granted)
SELECT 'rh', pc, true FROM unnest(ARRAY[
  'paie.voir','paie.creer','paie.exporter_pdf','paie.voir_historique','paie.acceder_parametres',
  'paie_parametres.voir','paie_rubriques.voir','absences.voir','conges.voir','contrats.voir',
  'departements.voir','evaluations.voir','fonctions.voir','missions.voir','exports.voir'
]) AS pc
WHERE EXISTS (SELECT 1 FROM public.rbac2_permissions p WHERE p.code = pc)
ON CONFLICT (role_code, perm_code) DO UPDATE SET granted = true;

-- 6) Logistique
INSERT INTO public.rbac2_role_perms (role_code, perm_code, granted)
SELECT rc, pc, true FROM (
  SELECT unnest(ARRAY['service_logistique','responsable_magasinier']) AS rc
) r, unnest(ARRAY[
  'bons_livraison.voir','expeditions.voir','couts_logistiques.voir','dashboard_logistique.voir',
  'rapports_logistique.voir','flotte.voir','livreurs.voir','depots.voir','missions.voir',
  'historique_envois.voir','centre_documents.voir'
]) AS pc
WHERE EXISTS (SELECT 1 FROM public.rbac2_permissions p WHERE p.code = pc)
ON CONFLICT (role_code, perm_code) DO UPDATE SET granted = true;

-- 7) Commercial / Direction commerciale
INSERT INTO public.rbac2_role_perms (role_code, perm_code, granted)
SELECT rc, pc, true FROM (
  SELECT unnest(ARRAY['directeur_commercial','commercial']) AS rc
) r, unnest(ARRAY[
  'clients_dashboard.voir','etat_compte_clients.voir','bons_livraison.voir',
  'centre_documents.voir','rapports.voir','exports.voir'
]) AS pc
WHERE EXISTS (SELECT 1 FROM public.rbac2_permissions p WHERE p.code = pc)
ON CONFLICT (role_code, perm_code) DO UPDATE SET granted = true;
