// lib/app/utils/validators.dart

String? requiredField(String? v) {
  if (v == null || v.trim().isEmpty) return '필수 입력 항목입니다.';
  return null;
}

String? maxLength(String? v, int max) {
  if (v != null && v.length > max) return '최대 $max자까지 입력할 수 있습니다.';
  return null;
}