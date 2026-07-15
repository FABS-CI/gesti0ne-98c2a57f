
CREATE TABLE public.login_history (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  email text,
  nom_complet text,
  role text,
  ip_address text,
  user_agent text,
  device text,
  status text NOT NULL DEFAULT 'success',
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX login_history_occurred_at_idx ON public.login_history (occurred_at DESC);
CREATE INDEX login_history_user_id_idx ON public.login_history (user_id);

GRANT SELECT, INSERT ON public.login_history TO authenticated;
GRANT ALL ON public.login_history TO service_role;

ALTER TABLE public.login_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Super admins can view all login history"
  ON public.login_history FOR SELECT
  TO authenticated
  USING (public.has_role(auth.uid(), 'super_admin'::public.app_role));

CREATE POLICY "Users can insert their own login entry"
  ON public.login_history FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.log_user_login(
  _ip_address text DEFAULT NULL,
  _user_agent text DEFAULT NULL,
  _device text DEFAULT NULL,
  _status text DEFAULT 'success'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_email text;
  v_nom text;
  v_role text;
  v_id uuid;
  v_msg text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT u.email, p.nom_complet
    INTO v_email, v_nom
    FROM auth.users u
    LEFT JOIN public.profiles p ON p.id = u.id
    WHERE u.id = v_uid;

  SELECT role::text INTO v_role
    FROM public.user_roles
    WHERE user_id = v_uid
    ORDER BY CASE WHEN role::text = 'super_admin' THEN 0 ELSE 1 END
    LIMIT 1;

  INSERT INTO public.login_history (
    user_id, email, nom_complet, role, ip_address, user_agent, device, status
  ) VALUES (
    v_uid, v_email, v_nom, v_role, _ip_address, _user_agent, _device, COALESCE(_status, 'success')
  )
  RETURNING id INTO v_id;

  v_msg := COALESCE(v_nom, v_email, 'Utilisateur') ||
    ' (' || COALESCE(v_role, 'sans rôle') || ')' ||
    ' — ' || COALESCE(_device, 'Appareil inconnu') ||
    CASE WHEN _ip_address IS NOT NULL THEN ' — IP ' || _ip_address ELSE '' END;

  PERFORM public.creer_notification(
    'Connexion utilisateur',
    v_msg,
    'info',
    'auth',
    'basse',
    NULL,
    NULL,
    NULL,
    'super_admin'::public.app_role,
    NULL,
    NULL
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_user_login(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_user_login(text, text, text, text) TO authenticated;
