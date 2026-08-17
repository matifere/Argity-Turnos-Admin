-- =============================================================================
-- RPC: cancel_range_as_holiday
-- Cancela todas las clases entre p_start_date y p_end_date (inclusive) como
-- vacaciones/feriado, para la institución del admin que lo invoca.
--
-- p_refund_credits = true  -> devuelve el crédito: la reserva 'confirmed' pasa a
--                             'cancelled' y el alumno libera el cupo.
-- p_refund_credits = false -> la clase se pierde: la reserva 'confirmed' pasa a
--                             'no_show' (se computa como usada, NO libera cupo).
--
-- Espeja cancel_day_as_holiday (mismos guards, scope por institución, notif y
-- limpieza de waitlist); solo agrega el rango de fechas y el flag de reintegro.
-- =============================================================================

create or replace function public.cancel_range_as_holiday(
  p_start_date     date,
  p_end_date       date,
  p_reason         text default null,
  p_refund_credits boolean default true
)
returns json
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_caller       uuid := auth.uid();
  v_inst         uuid := kali_institution_id();
  v_sessions     int  := 0;
  v_reservations int  := 0;
  r              record;
begin
  if not kali_is_admin() then
    return json_build_object('ok', false, 'error', 'forbidden');
  end if;
  if v_inst is null then
    return json_build_object('ok', false, 'error', 'no_institution');
  end if;
  if p_end_date < p_start_date then
    return json_build_object('ok', false, 'error', 'invalid_range');
  end if;

  -- 1. Cancelar las sesiones agendadas del rango (de la institución del admin).
  update class_sessions
     set status = 'cancelled'
   where date between p_start_date and p_end_date
     and institution_id = v_inst
     and status = 'scheduled';
  get diagnostics v_sessions = row_count;

  if v_sessions = 0 then
    return json_build_object('ok', true, 'sessions', 0, 'reservations', 0);
  end if;

  -- 2. Procesar reservas confirmadas y 3. notificar a cada alumno.
  --    Las sesiones ya están 'cancelled', así que la promoción de lista de espera no dispara.
  for r in
    select res.id as res_id, res.user_id, cs.name as class_name, cs.date as class_date
      from reservations res
      join class_sessions cs on cs.id = res.session_id
     where cs.date between p_start_date and p_end_date
       and cs.institution_id = v_inst
       and res.status = 'confirmed'
  loop
    if p_refund_credits then
      -- Devolver el crédito: se cancela la reserva y se libera el cupo.
      update reservations
         set status = 'cancelled', cancelled_at = now(), cancelled_by = v_caller
       where id = r.res_id;
    else
      -- La clase se pierde: la reserva queda como ausente y NO libera cupo.
      update reservations
         set status = 'no_show', cancelled_at = now(), cancelled_by = v_caller
       where id = r.res_id;
    end if;
    v_reservations := v_reservations + 1;

    insert into notifications (user_id, title, body, type)
    values (
      r.user_id,
      'Clase cancelada por feriado',
      'Se canceló ' || coalesce(nullif(r.class_name, ''), 'tu clase')
        || ' del ' || to_char(r.class_date, 'DD/MM')
        || case when nullif(p_reason, '') is not null then ' (' || p_reason || ')' else '' end
        || case
             when p_refund_credits
               then '. Se te devolvió el crédito, podés reservar otra clase.'
               else '. Esta clase se computa como usada (no se devuelve el crédito).'
           end,
      'holiday'
    );
  end loop;

  -- 4. Limpiar lista de espera de las sesiones canceladas.
  delete from waitlist w
   using class_sessions cs
   where w.session_id = cs.id
     and cs.date between p_start_date and p_end_date
     and cs.institution_id = v_inst;

  return json_build_object('ok', true, 'sessions', v_sessions, 'reservations', v_reservations);
end;
$function$;
