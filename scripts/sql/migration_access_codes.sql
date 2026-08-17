-- ============================================================================
-- Códigos de acceso para alumnos
-- ============================================================================
-- El admin genera un código por alumno (uno activo a la vez). El alumno puede
-- iniciar sesión en la app cliente solo con ese código: la Edge Function
-- `login-with-code` (service role) lo valida y emite un token de sesión, y la
-- institución sale automáticamente del perfil del alumno.
--
-- Seguridad:
--  * RLS: solo admins/sudo de la MISMA institución ven y gestionan códigos.
--    El rol client no tiene acceso a la tabla (el login pasa por la edge
--    function con service role, nunca por PostgREST).
--  * El código se genera server-side (RPC security definer) con pgcrypto,
--    alfabeto sin caracteres ambiguos (sin 0/O/1/I/L).
--  * Regenerar un código revoca el anterior (revoked_at).
-- ============================================================================

create table if not exists public.access_codes (
  id             uuid primary key default gen_random_uuid(),
  code           text not null unique,
  user_id        uuid not null references public.profiles(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  created_by     uuid references public.profiles(id) on delete set null,
  created_at     timestamptz not null default now(),
  revoked_at     timestamptz,
  last_used_at   timestamptz,
  use_count      integer not null default 0
);

create index if not exists access_codes_user_id_idx on public.access_codes (user_id);

alter table public.access_codes enable row level security;

drop policy if exists access_codes_select on public.access_codes;
create policy access_codes_select on public.access_codes
  for select to authenticated
  using (institution_id = kali_institution_id() and kali_is_admin());

drop policy if exists access_codes_update on public.access_codes;
create policy access_codes_update on public.access_codes
  for update to authenticated
  using (institution_id = kali_institution_id() and kali_is_admin())
  with check (institution_id = kali_institution_id() and kali_is_admin());

drop policy if exists access_codes_delete on public.access_codes;
create policy access_codes_delete on public.access_codes
  for delete to authenticated
  using (institution_id = kali_institution_id() and kali_is_admin());

-- Sin policy de INSERT: los códigos solo se crean vía la RPC de abajo
-- (security definer), que valida rol e institución por su cuenta.

-- ============================================================================
-- RPC: generar (o regenerar) el código de acceso de un alumno
-- ============================================================================
create or replace function public.generate_access_code(p_student_id uuid)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_inst uuid;
  v_student_inst uuid;
  v_code text;
  -- Sin 0/O/1/I/L para que el código se pueda dictar por teléfono sin errores.
  v_chars constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_bytes bytea;
  i int;
begin
  if not kali_is_admin() then
    raise exception 'Solo administradores pueden generar códigos de acceso';
  end if;

  v_inst := kali_institution_id();

  select institution_id into v_student_inst
  from profiles
  where id = p_student_id and role = 'client';

  if v_student_inst is null or v_student_inst is distinct from v_inst then
    raise exception 'Alumno no encontrado en tu institución';
  end if;

  -- Un solo código activo por alumno: revocar los anteriores.
  update access_codes
  set revoked_at = now()
  where user_id = p_student_id and revoked_at is null;

  loop
    v_bytes := gen_random_bytes(8);
    v_code := '';
    for i in 0..7 loop
      v_code := v_code
        || substr(v_chars, 1 + (get_byte(v_bytes, i) % length(v_chars)), 1);
    end loop;

    begin
      insert into access_codes (code, user_id, institution_id, created_by)
      values (v_code, p_student_id, v_inst, auth.uid());
      exit;
    exception when unique_violation then
      -- Colisión (1 en ~10^12): reintentar con otro código.
    end;
  end loop;

  return v_code;
end;
$$;

revoke execute on function public.generate_access_code(uuid) from public, anon;
grant execute on function public.generate_access_code(uuid) to authenticated;
