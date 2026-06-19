import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProfileImageStorageService {
  ProfileImageStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadProfileImage({
    required XFile image,
    required String userId,
  }) async {
    final fileName = _safeFileName(
      image.name.trim().isEmpty
          ? 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : image.name,
    );
    final storagePath = 'profile_images/$userId/$fileName';
    final ref = _storage.ref(storagePath);
    final bytes = await image.readAsBytes();
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(
        contentType: image.mimeType ?? _contentTypeFor(fileName),
        customMetadata: {'userId': userId},
      ),
    );

    return uploadTask.ref.getDownloadURL();
  }

  String _safeFileName(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    return cleaned.isEmpty ? 'profile.jpg' : cleaned;
  }

  String _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }

    return 'image/jpeg';
  }
}
