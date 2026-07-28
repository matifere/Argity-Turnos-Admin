// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'package:supabase/supabase.dart';

Future<void> main() async {
  final client = SupabaseClient(
    'https://tmfcnvtjzmtpqhzvfxos.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtZmNudnRqem10cHFoenZmeG9zIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3Mzg2ODY2NiwiZXhwIjoyMDg5NDQ0NjY2fQ.ZJJXQ0Nd3UZoBQYovlXgAzUcaIa7eW5hTuA_hXiWcmA'
  );

  try {
    final data = await client
        .from('profiles')
        .select('role, institution_id, full_name, is_active, institutions(theme_id)')
        .eq('id', '257cd7cf-64c8-49a8-95f8-df0f0aca5bd9')
        .maybeSingle();

    print('Data: $data');
    
    final instData = data!['institutions'];
    print('InstData: $instData');
    print('ThemeId: ${instData['theme_id']}');

    final subData = await client
        .from('tenant_subscriptions')
        .select('status, current_period_end, saas_plans(features)')
        .eq('institution_id', '3c9de23a-e012-4831-966c-16e1f949d717')
        .maybeSingle();
        
    print('SubData: $subData');
    
    final saasPlans = subData!['saas_plans'];
    print('SaasPlans: $saasPlans');
    final features = saasPlans['features'] as Map<String, dynamic>;
    print('Features: $features');

  } catch (e, stack) {
    print('ERROR: $e');
    print(stack);
  }
}
