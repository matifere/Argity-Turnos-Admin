import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  const buildUrl = String.fromEnvironment('SUPABASE_URL');
  final supabaseUrl =
      buildUrl.isNotEmpty ? buildUrl : (dotenv.env['URL'] ?? '');
  const buildAnon = String.fromEnvironment('SUPABASE_ANON');
  final supabaseAnon =
      buildAnon.isNotEmpty ? buildAnon : (dotenv.env['ANON'] ?? '');

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnon,
  );
}
