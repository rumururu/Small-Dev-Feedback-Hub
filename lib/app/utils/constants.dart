// lib/app/utils/constants.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase 설정
String get supabaseUrl     => dotenv.env['SUPABASE_URL']!;
String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY']!;


/// 테스트 재시작 실행가능시점
int get testRestartPossibleDate => 0;

/// 인스톨 다시 체크시작가능한 시점
int get installRecheckHour => 0;