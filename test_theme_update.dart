// ignore_for_file: avoid_print, depend_on_referenced_packages, unused_local_variable
import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://[SUPABASE_URL].supabase.co', // Needs real URL from env
    '[SUPABASE_KEY]'
  );
  // Actually, I can't run this without the env variables.
  // It's better to modify ThemeCubit to print the error.
}
