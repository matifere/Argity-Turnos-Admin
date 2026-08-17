-- ==============================================================================
-- Migración: Sección Rutinas (catálogo por institución + asignación por alumno)
-- ==============================================================================

-- 1. Catálogo de rutinas de la institución
CREATE TABLE IF NOT EXISTS public.routines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id uuid NOT NULL REFERENCES public.institutions(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  exercises jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 2. Rutina asignada a cada alumno (una rutina activa por alumno; reasignar = upsert)
CREATE TABLE IF NOT EXISTS public.routine_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  routine_id uuid NOT NULL REFERENCES public.routines(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  assigned_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes text,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS idx_routines_institution ON public.routines (institution_id);
CREATE INDEX IF NOT EXISTS idx_routine_assignments_routine ON public.routine_assignments (routine_id);

-- 3. RLS
ALTER TABLE public.routines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routine_assignments ENABLE ROW LEVEL SECURITY;

-- Staff (sudo = dueño, admin = profesor) gestiona las rutinas de su institución.
CREATE POLICY "routines_staff_all"
ON public.routines
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
      AND profiles.institution_id = routines.institution_id
      AND profiles.role IN ('sudo', 'admin')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
      AND profiles.institution_id = routines.institution_id
      AND profiles.role IN ('sudo', 'admin')
  )
);

-- El alumno puede leer la rutina que tiene asignada (para la app Client).
CREATE POLICY "routines_client_read_assigned"
ON public.routines
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.routine_assignments ra
    WHERE ra.routine_id = routines.id
      AND ra.user_id = auth.uid()
  )
);

-- Staff gestiona las asignaciones de alumnos de su institución.
CREATE POLICY "routine_assignments_staff_all"
ON public.routine_assignments
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles staff
    JOIN public.profiles alumno ON alumno.id = routine_assignments.user_id
    WHERE staff.id = auth.uid()
      AND staff.role IN ('sudo', 'admin')
      AND staff.institution_id = alumno.institution_id
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles staff
    JOIN public.profiles alumno ON alumno.id = routine_assignments.user_id
    WHERE staff.id = auth.uid()
      AND staff.role IN ('sudo', 'admin')
      AND staff.institution_id = alumno.institution_id
  )
);

-- El alumno lee su propia asignación.
CREATE POLICY "routine_assignments_own_read"
ON public.routine_assignments
FOR SELECT
TO authenticated
USING (user_id = auth.uid());
