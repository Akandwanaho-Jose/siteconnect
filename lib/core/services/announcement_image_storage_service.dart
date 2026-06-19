import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AnnouncementImageUpload {
  const AnnouncementImageUpload({
    required this.storagePath,
    required this.downloadUrl,
  });

  final String storagePath;
  final String downloadUrl;
}

class AnnouncementImageStorageService {
  AnnouncementImageStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<AnnouncementImageUpload> uploadAnnouncementImage({
    required XFile image,
    required String announcementId,
  }) async {
    final fileName = _safeFileName(
      image.name.trim().isEmpty
          ? 'announcement_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : image.name,
    );
    final storagePath = 'announcement_images/$announcementId/$fileName';
    final ref = _storage.ref(storagePath);
    final bytes = await image.readAsBytes();
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(
        contentType: image.mimeType ?? _contentTypeFor(fileName),
        customMetadata: {'announcementId': announcementId},
      ),
    );

    return AnnouncementImageUpload(
      storagePath: uploadTask.ref.fullPath,
      downloadUrl: await uploadTask.ref.getDownloadURL(),
    );
  }

  String _safeFileName(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    return cleaned.isEmpty ? 'announcement.jpg' : cleaned;
  }

  String _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }

    return 'image/jpeg';
  }
}
