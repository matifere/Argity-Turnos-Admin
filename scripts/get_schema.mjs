import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const url = 'https://tmfcnvtjzmtpqhzvfxos.supabase.co';
const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtZmNudnRqem10cHFoenZmeG9zIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3Mzg2ODY2NiwiZXhwIjoyMDg5NDQ0NjY2fQ.ZJJXQ0Nd3UZoBQYovlXgAzUcaIa7eW5hTuA_hXiWcmA';

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
