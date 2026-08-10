import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const url = 'https://tmfcnvtjzmtpqhzvfxos.supabase.co';
const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtZmNudnRqem10cHFoenZmeG9zIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3Mzg2ODY2NiwiZXhwIjoyMDg5NDQ0NjY2fQ.ZJJXQ0Nd3UZoBQYovlXgAzUcaIa7eW5hTuA_hXiWcmA';

const supabase = createClient(url, key);

const args = Deno.args;
if (args.length < 2) {
  console.log("================================================================");
  console.log("Uso: deno run -A activar_pago_prod.mjs <email> <fecha> [plan]");
  console.log("Ejemplo: deno run -A activar_pago_prod.mjs usuario@gmail.com \"2027-01-01\" \"Pro\"");
  console.log("================================================================");
  Deno.exit(1);
}

const email = args[0];
const fecha = args[1];
const planName = args[2] || '';

async function main() {
  console.log(`Conectando a producción (${url}) para activar pago manual...`);
  console.log(`Usuario: ${email}`);
  console.log(`Válido hasta: ${fecha}`);
  if (planName) console.log(`Plan solicitado: ${planName}`);
  
  // 1. Buscar la institución asociada al email
  const { data: profiles, error: profileErr } = await supabase
    .from('profiles')
    .select('institution_id')
    .eq('email', email)
    .limit(1);

  if (profileErr) {
    console.error('Error buscando profile:', profileErr);
    Deno.exit(1);
  }

  if (!profiles || profiles.length === 0 || !profiles[0].institution_id) {
    console.error(`ERROR: No se encontró ninguna institución asociada al email ${email}`);
    Deno.exit(1);
  }

  const institutionId = profiles[0].institution_id;
  console.log(`Institución encontrada: ${institutionId}`);

  // 2. Obtener un plan para asignar
  let planId;
  if (planName) {
    const { data: plans, error: planErr } = await supabase
      .from('saas_plans')
      .select('id')
      .ilike('name', planName)
      .eq('is_active', true)
      .limit(1);
      
    if (planErr) {
      console.error('Error buscando plan:', planErr);
      Deno.exit(1);
    }
    
    if (!plans || plans.length === 0) {
      console.error(`ERROR: No se encontró un plan activo con el nombre ${planName}`);
      Deno.exit(1);
    }
    planId = plans[0].id;
  } else {
    const { data: plans, error: planErr } = await supabase
      .from('saas_plans')
      .select('id')
      .eq('is_active', true)
      .order('price', { ascending: true })
      .limit(1);
      
    if (planErr) {
      console.error('Error buscando plan por defecto:', planErr);
      Deno.exit(1);
    }
    
    if (!plans || plans.length === 0) {
      console.error(`ERROR: No hay planes SaaS activos en la base de datos.`);
      Deno.exit(1);
    }
    planId = plans[0].id;
  }

  const periodEnd = `${fecha} 23:59:59`;

  // 3. Actualizar o insertar la suscripción
  const { data: updateData, error: updateErr } = await supabase
    .from('tenant_subscriptions')
    .update({
      status: 'active',
      current_period_end: periodEnd,
      saas_plan_id: planId,
      mp_preapproval_id: 'manual_payment',
      updated_at: new Date().toISOString()
    })
    .eq('institution_id', institutionId)
    .select();

  if (updateErr) {
    console.error('Error actualizando suscripción:', updateErr);
    Deno.exit(1);
  }

  if (!updateData || updateData.length === 0) {
    const { error: insertErr } = await supabase
      .from('tenant_subscriptions')
      .insert({
        institution_id: institutionId,
        saas_plan_id: planId,
        status: 'active',
        current_period_end: periodEnd,
        mp_preapproval_id: 'manual_payment'
      });
      
    if (insertErr) {
      console.error('Error insertando suscripción:', insertErr);
      Deno.exit(1);
    }
  }

  console.log(`✅ Suscripción activada exitosamente hasta el ${fecha}`);
}

main();
