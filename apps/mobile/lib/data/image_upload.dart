import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api_client.dart';

final ImagePicker _picker = ImagePicker();

String _contentTypeFor(String name, String? mimeType) {
  if (mimeType != null && mimeType.startsWith('image/')) return mimeType;
  final n = name.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.gif')) return 'image/gif';
  if (n.endsWith('.heic')) return 'image/heic';
  return 'image/jpeg';
}

/// Pick an image from the gallery (or camera) and upload it via the media
/// pipeline, returning the public URL — or null if the user cancels or it
/// fails. Works on Android, iOS and web (image_picker_for_web uses the browser
/// file input). Shows a snackbar on error.
Future<String?> pickAndUploadImage(
  BuildContext context, {
  required ApiClient apiClient,
  required String token,
  required String usage,
  String? scopeType,
  String? scopeId,
  ImageSource source = ImageSource.gallery,
}) async {
  // Capture the messenger before any await so we never touch context across
  // an async gap.
  final messenger = ScaffoldMessenger.of(context);
  if (token.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('Please sign in to upload images.')));
    return null;
  }
  XFile? file;
  try {
    file = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('Could not open the picker: ${_clean(error)}')));
    return null;
  }
  if (file == null) return null; // cancelled

  messenger.showSnackBar(const SnackBar(content: Text('Uploading image…'), duration: Duration(seconds: 30)));
  try {
    final bytes = await file.readAsBytes();
    final asset = await apiClient.uploadMediaAsset(
      token: token,
      usage: usage,
      fileName: file.name,
      contentType: _contentTypeFor(file.name, file.mimeType),
      byteSize: bytes.length,
      bytes: bytes,
      scopeType: scopeType,
      scopeId: scopeId,
    );
    messenger.hideCurrentSnackBar();
    final url = asset['publicUrl']?.toString() ?? '';
    if (url.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Upload finished but no URL was returned.')));
      return null;
    }
    return url;
  } catch (error) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text('Upload failed: ${_clean(error)}')));
    return null;
  }
}

/// A tappable avatar that lets the user pick + upload a new image, calling
/// [onUploaded] with the resulting URL. Shows [currentUrl] (or initials).
class ImageUploadAvatar extends StatelessWidget {
  const ImageUploadAvatar({
    super.key,
    required this.apiClient,
    required this.token,
    required this.usage,
    required this.onUploaded,
    this.currentUrl,
    this.initials = '',
    this.radius = 44,
    this.scopeType,
    this.scopeId,
  });

  final ApiClient apiClient;
  final String token;
  final String usage;
  final ValueChanged<String> onUploaded;
  final String? currentUrl;
  final String initials;
  final double radius;
  final String? scopeType;
  final String? scopeId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = currentUrl ?? '';
    return Stack(clipBehavior: Clip.none, children: [
      CircleAvatar(
        radius: radius,
        backgroundColor: colors.surfaceContainerHighest,
        backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
        child: url.isEmpty
            ? Text(initials.isNotEmpty ? initials : '?',
                style: TextStyle(fontSize: radius * 0.7, color: colors.onSurfaceVariant, fontWeight: FontWeight.w700))
            : null,
      ),
      Positioned(
        right: -2,
        bottom: -2,
        child: Material(
          color: colors.primary,
          shape: const CircleBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () async {
              final uploaded = await pickAndUploadImage(context,
                  apiClient: apiClient, token: token, usage: usage, scopeType: scopeType, scopeId: scopeId);
              if (uploaded != null) onUploaded(uploaded);
            },
            child: Padding(
              padding: EdgeInsets.all(radius * 0.16),
              child: Icon(Icons.photo_camera_rounded, size: radius * 0.42, color: colors.onPrimary),
            ),
          ),
        ),
      ),
    ]);
  }
}

String _clean(Object e) => e.toString().replaceFirst('HttpException: ', '');
