import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class UploadPolicy {
  static const receiptBytes = 10 * 1024 * 1024;
  static const contractBytes = 20 * 1024 * 1024;
  static const attachmentBytes = 100 * 1024 * 1024;
  static const messageCharacters = 4000;
  static const attachmentExtensions = {'pdf','doc','docx','xls','xlsx','ppt','pptx',
    'jpg','jpeg','png','webp','heic','mp4','mov','mp3','m4a','wav','txt','csv','zip'};

  static void validateAttachmentName(String name) {
    if (!attachmentExtensions.contains(name.split('.').last.toLowerCase())) {
      throw const FormatException('Bu dosya türü desteklenmiyor. Belge, fotoğraf, ses veya video seçin.');
    }
  }

  static void validateSize(int size, int limit) {
    if (size <= 0) throw const FormatException('Dosya boş olamaz.');
    if (size > limit) throw FormatException('Dosya boyutu ${limit ~/ (1024 * 1024)} MB sınırını aşıyor.');
  }

  static Future<Uint8List> readFile(PlatformFile file, int limit) async {
    if (limit == attachmentBytes) validateAttachmentName(file.name);
    final knownSize = file.lengthSync();
    if (knownSize != null) validateSize(knownSize, limit);
    return readStream(file.readAsByteStream(), limit);
  }

  static Future<Uint8List> readStream(Stream<Uint8List> source, int limit) async {
    final result = BytesBuilder(copy: false);
    await for (final chunk in source) {
      if (result.length + chunk.length > limit) {
        throw FormatException('Dosya boyutu ${limit ~/ (1024 * 1024)} MB sınırını aşıyor.');
      }
      result.add(chunk);
    }
    validateSize(result.length, limit);
    return result.takeBytes();
  }
}
