-- ==============================================================================
-- Migración: ventana de cancelación configurable por institución
-- La app Client usa este valor para bloquear cancelaciones a menos de N horas
-- de la clase (antes estaba hardcodeado en 2 horas).
-- ==============================================================================

ALTER TABLE public.institutions
  ADD COLUMN IF NOT EXISTS cancellation_hours integer NOT NULL DEFAULT 2;

ALTER TABLE public.institutions
  DROP CONSTRAINT IF EXISTS institutions_cancellation_hours_check;

ALTER TABLE public.institutions
  ADD CONSTRAINT institutions_cancellation_hours_check
  CHECK (cancellation_hours >= 0 AND cancellation_hours <= 168);
