import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const url = Deno.env.get("SUPABASE_URL") || 'https://tmfcnvtjzmtpqhzvfxos.supabase.co';
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!key) {
  console.error("ERROR: Falta la variable de entorno SUPABASE_SERVICE_ROLE_KEY");
  Deno.exit(1);
}

const supabase = createClient(url, key);

async function main() {
  const tables = ['institutions', 'profiles', 'subscriptions', 'plans', 'payments'];
  for (const table of tables) {
    const { data, error } = await supabase.from(table).select('*').limit(1);
    if (error) {
      console.error(`Error ${table}:`, error.message);
    } else {
      console.log(`${table} columns:`, Object.keys(data[0] || {}));
    }
  }
}

main();
