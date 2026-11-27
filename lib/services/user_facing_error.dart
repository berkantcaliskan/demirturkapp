import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

String userFacingError(Object? error, {String fallback = 'İşlem tamamlanamadı. Bağlantınızı kontrol edip tekrar deneyin.'}) {
  if (error is FormatException) return error.message;
  if (error is TimeoutException) return 'Bağlantı zaman aşımına uğradı. Tekrar deneyin.';
  final message = error is AuthException ? error.message
      : error is PostgrestException ? error.message : '';
  if (message.toLowerCase().contains('invalid login credentials')) return 'Telefon numarası veya parola hatalı.';
  if (error is PostgrestException && error.code == '42501') return 'Bu işlem için yetkiniz yok. Hesabınızı ve erişiminizi kontrol edin.';
  const safePrefixes = ['Telefon numarası veya parola biçimi', 'Bu numara', 'Çok fazla kayıt',
    'Kayıt servisi', 'Hesap oluşturulamadı', 'Müşteri kaydınız', 'Satış danışmanınız',
    'Muhasebe ekibi', 'Sohbet başlatılamadı', 'Mesaj 1', 'Mesaj sınırına',
    'Yükleme sınırına', 'Dosya boyutu', 'Hesabınızın dosya', 'Bu dosya türü',
    'Onaylamadan önce', 'Geçerli bir sözleşme', 'Bekleyen sözleşme bulunamadı'];
  if (safePrefixes.any(message.startsWith)) return message;
  return fallback;
}
