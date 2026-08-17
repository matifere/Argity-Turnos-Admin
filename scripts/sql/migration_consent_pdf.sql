-- ==============================================================================
-- Migración: consentimiento informado por institución
-- El admin sube un PDF desde Configuración -> Institución (bucket "institutions",
-- carpeta <institution_id>/, igual que el logo) y acá se guarda su URL pública.
-- La app Client lo muestra en Perfil -> Consentimiento; si es NULL usa el PDF
-- embebido en la app como fallback.
-- ==============================================================================

ALTER TABLE public.institutions
  ADD COLUMN IF NOT EXISTS consent_pdf_url text;
