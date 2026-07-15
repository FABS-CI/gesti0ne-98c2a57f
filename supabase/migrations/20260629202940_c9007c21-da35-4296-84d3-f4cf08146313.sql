
DO $$
DECLARE
  u record;
  v_id uuid;
  users jsonb := '[
    {"email":"pissken@editionsfabsci.com","nom":"AKE YVES DORIS","role":"super_admin","pwd":"Admin@2025"},
    {"email":"ali.mamin@editionsfabsci.com","nom":"ALI MAMIN","role":"directeur_general","pwd":"Fabs2026!"},
    {"email":"natachakoffi@editionsfabsci.com","nom":"NATACHA KOFFI","role":"comptable","pwd":"Fabs2026!"},
    {"email":"detymichel@editionsfabsci.com","nom":"DETY MICHEL","role":"directeur_commercial","pwd":"Fabs2026!"},
    {"email":"niangoran.georgie@editionsfabsci.com","nom":"NIANGORAN GEORGIE","role":"gestionnaire_stock","pwd":"Fabs2026!"},
    {"email":"joachin@editionsfabsci.com","nom":"JOACHIN","role":"responsable_magasinier","pwd":"Fabs2026!"},
    {"email":"dadjelarissa@editionsfabsci.com","nom":"AHOMAN DADJE","role":"secretariat","pwd":"Fabs2026!"},
    {"email":"amenan@editionsfabsci.com","nom":"AMENAN","role":"assistante","pwd":"Fabs2026!"},
    {"email":"yakeben@editionsfabsci.com","nom":"YAKE BEN","role":"service_logistique","pwd":"Fabs2026!"}
  ]'::jsonb;
BEGIN
  FOR u IN SELECT * FROM jsonb_to_recordset(users) AS x(email text, nom text, role text, pwd text) LOOP
    SELECT id INTO v_id FROM auth.users WHERE email = u.email;
    IF v_id IS NULL THEN
      v_id := gen_random_uuid();
      INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, created_at, updated_at,
        raw_app_meta_data, raw_user_meta_data, is_super_admin, confirmation_token,
        email_change, email_change_token_new, recovery_token
      ) VALUES (
        '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
        u.email, crypt(u.pwd, gen_salt('bf')),
        now(), now(), now(),
        jsonb_build_object('provider','email','providers',jsonb_build_array('email')),
        jsonb_build_object('nom_complet', u.nom),
        false, '', '', '', ''
      );
      INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
      VALUES (gen_random_uuid(), v_id,
        jsonb_build_object('sub', v_id::text, 'email', u.email, 'email_verified', true),
        'email', v_id::text, now(), now(), now());
    ELSE
      UPDATE auth.users
        SET encrypted_password = crypt(u.pwd, gen_salt('bf')),
            email_confirmed_at = coalesce(email_confirmed_at, now()),
            raw_user_meta_data = coalesce(raw_user_meta_data,'{}'::jsonb) || jsonb_build_object('nom_complet', u.nom),
            updated_at = now()
        WHERE id = v_id;
    END IF;

    INSERT INTO public.profiles (id, email, nom_complet)
      VALUES (v_id, u.email, u.nom)
      ON CONFLICT (id) DO UPDATE SET nom_complet = EXCLUDED.nom_complet, email = EXCLUDED.email;

    INSERT INTO public.user_roles (user_id, role)
      VALUES (v_id, u.role::app_role)
      ON CONFLICT (user_id, role) DO NOTHING;
  END LOOP;
END $$;
