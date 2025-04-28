// lib/app/utils/constants.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase 설정
String get supabaseUrl     => dotenv.env['SUPABASE_URL']!;
String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY']!;

