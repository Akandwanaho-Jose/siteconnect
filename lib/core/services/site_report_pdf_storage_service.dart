import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class SiteReportPdfUpload {
  const SiteReportPdfUpload({
    required this.storagePath,
    required this.downloadUrl,
    required this.fileName,
    required this.fileSizeBytes,
  });

  final String storagePath;
  final String downloadUrl;
  final String fileName;
  final int fileSizeBytes;
}

class SiteReportPdfStorageService {
  SiteReportPdfStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<SiteReportPdfUpload> uploadReportPdf({
    required Uint8List bytes,
    required String projectId,
    required String reportId,
    required int version,
    required String fileName,
  }) async {
    final safeFileName = _safePdfFileName(fileName);
    final storagePath =
        'report_pdfs/$projectId/$reportId/v$version/$safeFileName';
    final ref = _storage.ref(storagePath);
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'projectId': projectId,
          'reportId': reportId,
          'version': version.toString(),
        },
      ),
    );

    return SiteReportPdfUpload(
      storagePath: uploadTask.ref.fullPath,
      downloadUrl: await uploadTask.ref.getDownloadURL(),
      fileName: safeFileName,
      fileSizeBytes: bytes.length,
    );
  }

  String _safePdfFileName(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    final fileName = cleaned.isEmpty ? 'site_report.pdf' : cleaned;
    return fileName.toLowerCase().endsWith('.pdf') ? fileName : '$fileName.pdf';
  }
}
