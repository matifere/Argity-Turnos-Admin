-- ==============================================================================
-- Migración: Soporte para Temas Personalizados (Instituciones y Planes SaaS)
-- ==============================================================================

-- 1. Agregar columna theme_id a la tabla institutions
ALTER TABLE public.institutions 
ADD COLUMN IF NOT EXISTS theme_id TEXT DEFAULT 'default'::text NOT NULL;

-- 2. Crear política RLS para permitir que el rol 'sudo' actualice el tema de su institución
-- Nota: Si la política ya existe, este comando arrojará un error. 
-- En ese caso, puedes omitirlo o eliminar la política existente primero.
CREATE POLICY "institutions_update_sudo" 
ON public.institutions 
FOR UPDATE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE profiles.id = auth.uid() 
      AND profiles.institution_id = institutions.id 
      AND profiles.role = 'sudo'
  )
) 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE profiles.id = auth.uid() 
      AND profiles.institution_id = institutions.id 
      AND profiles.role = 'sudo'
  )
);

-- 3. Habilitar RLS en institutions si no estaba habilitado
ALTER TABLE public.institutions ENABLE ROW LEVEL SECURITY;

-- 4. Agregar columna features a la tabla saas_plans para almacenar flags JSONB (ej. custom_themes)
ALTER TABLE public.saas_plans 
ADD COLUMN IF NOT EXISTS features JSONB DEFAULT '{}'::jsonb;
