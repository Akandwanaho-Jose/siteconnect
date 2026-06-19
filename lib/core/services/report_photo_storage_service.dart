import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ReportPhotoUpload {
  const ReportPhotoUpload({
    required this.storagePath,
    required this.downloadUrl,
  });

  final String storagePath;
  final String downloadUrl;
}

class ReportPhotoStorageService {
  ReportPhotoStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<ReportPhotoUpload> uploadReportPhoto({
    required XFile image,
    required String projectId,
    required String reportId,
    required String photoId,
  }) async {
    final fileName = _safeFileName(
      image.name.trim().isEmpty ? '$photoId.jpg' : image.name,
    );
    final storagePath = 'report_photos/$projectId/$reportId/$photoId/$fileName';
    final ref = _storage.ref(storagePath);
    final bytes = await image.readAsBytes();
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(
        contentType: image.mimeType ?? _contentTypeFor(fileName),
        customMetadata: {
          'projectId': projectId,
          'reportId': reportId,
          'photoId': photoId,
        },
      ),
    );

    return ReportPhotoUpload(
      storagePath: uploadTask.ref.fullPath,
      downloadUrl: await uploadTask.ref.getDownloadURL(),
    );
  }

  Future<void> deleteReportPhoto(String storagePath) async {
    if (storagePath.trim().isEmpty) {
      return;
    }

    await _storage.ref(storagePath).delete();
  }

  String _safeFileName(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    return cleaned.isEmpty ? 'photo.jpg' : cleaned;
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
