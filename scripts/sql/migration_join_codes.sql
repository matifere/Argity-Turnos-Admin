-- 1. Agregamos el código a la tabla de instituciones
ALTER TABLE public.institutions ADD COLUMN IF NOT EXISTS join_code TEXT UNIQUE;

-- 2. Creamos una función RPC simple para que el alumno se vincule
CREATE OR REPLACE FUNCTION public.join_institution(p_code TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_inst_id uuid;
BEGIN
  -- Buscamos si existe el código
  SELECT id INTO v_inst_id FROM public.institutions WHERE join_code = p_code;
  
  IF v_inst_id IS NULL THEN
    RAISE EXCEPTION 'Código de gimnasio inválido';
  END IF;

  -- Actualizamos el perfil del usuario autenticado
  UPDATE public.profiles 
  SET institution_id = v_inst_id 
  WHERE id = auth.uid();
END;
$$;

-- Permisos
REVOKE EXECUTE ON FUNCTION public.join_institution(TEXT) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.join_institution(TEXT) TO authenticated;
