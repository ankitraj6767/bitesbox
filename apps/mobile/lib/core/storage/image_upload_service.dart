import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_error.dart';

/// Where an image came from.
enum ImageSourceChoice { camera, gallery }

/// Uploads an image to a private Supabase Storage bucket under the caller's own
/// prefix.
///
/// Every private bucket policy in this project is written the same way:
///
/// ```sql
/// (storage.foldername(name))[1] = auth.uid()::text
/// ```
///
/// So the object key must start with the user's id. That is not a convention this
/// class invented — it is the only shape the database will accept, and
/// `submit_rider_document` independently re-checks it before recording a path.
/// Building the key here means a screen cannot get it wrong.
class ImageUploadService {
  ImageUploadService(this._client, {ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final SupabaseClient _client;
  final ImagePicker _picker;

  /// Long edge cap. A licence needs to be readable by a human on a laptop, not
  /// archival: 1600px keeps the number legible and the file inside the bucket's
  /// size limit on a rider's mobile data.
  static const double _maxDimension = 1600;
  static const int _quality = 82;

  /// Picks an image and returns the local file, or null if the rider backed out.
  Future<File?> pick(ImageSourceChoice source) async {
    final picked = await _picker.pickImage(
      source: source == ImageSourceChoice.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: _quality,
      // Rear camera: they are photographing a document or a doorstep, not
      // themselves. Overridden for the profile photo below.
      preferredCameraDevice: CameraDevice.rear,
    );

    if (picked == null) return null;
    return File(picked.path);
  }

  /// Picks a selfie for a profile photo.
  Future<File?> pickPortrait() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: _quality,
      preferredCameraDevice: CameraDevice.front,
    );

    if (picked == null) return null;
    return File(picked.path);
  }

  /// Uploads [file] to [bucket] as `{uid}/{name}.{ext}` and returns the object key.
  ///
  /// [name] should be stable per logical slot (`driving_licence`,
  /// `proof_{assignmentId}`) so a re-upload replaces the previous attempt instead
  /// of accumulating orphans the rider can never delete.
  Future<String> upload({
    required File file,
    required String bucket,
    required String name,
  }) async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw const AppError(
        code: ErrorCodes.unauthenticated,
        message: 'Please sign in again to upload this.',
      );
    }

    final extension = _extensionOf(file.path);
    final objectKey = '$userId/$name.$extension';

    try {
      await _client.storage.from(bucket).upload(
            objectKey,
            file,
            fileOptions: FileOptions(
              contentType: _contentTypeFor(extension),
              // Replaces the previous attempt at this slot.
              upsert: true,
            ),
          );
    } catch (error, stackTrace) {
      throw AppError.from(error, stackTrace);
    }

    return objectKey;
  }

  /// A short-lived signed URL, for showing back what was uploaded.
  ///
  /// These are identity documents, so the link is deliberately brief: long enough
  /// to render, not long enough to be worth sharing.
  Future<String?> signedUrl({
    required String bucket,
    required String objectKey,
    Duration expiresIn = const Duration(minutes: 3),
  }) async {
    try {
      return await _client.storage.from(bucket).createSignedUrl(
            objectKey,
            expiresIn.inSeconds,
          );
    } catch (error) {
      // A missing or unreadable object is not worth an error screen; the caller
      // renders a placeholder instead.
      debugPrint('signedUrl failed for $bucket/$objectKey: $error');
      return null;
    }
  }

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return 'jpg';

    final raw = path.substring(dot + 1).toLowerCase();
    // The buckets allow png/jpeg/webp; anything else the picker hands us is
    // re-labelled rather than rejected at the edge.
    return switch (raw) {
      'png' => 'png',
      'webp' => 'webp',
      'jpeg' || 'jpg' => 'jpg',
      _ => 'jpg',
    };
  }

  static String _contentTypeFor(String extension) => switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
}

/// Bucket names, matching what migration 0028 creates in SQL.
abstract final class StorageBuckets {
  static const riderDocuments = 'rider-documents';
  static const deliveryProofs = 'delivery-proofs';
  static const staffPhotos = 'staff-photos';
  static const supportAttachments = 'support-attachments';
}
