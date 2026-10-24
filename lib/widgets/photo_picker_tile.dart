import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/photo_service.dart';
import 'face_avatar.dart';

class PhotoPickerTile extends StatefulWidget {
  final String photo, name;
  final bool isPortrait;
  final ValueChanged<String> onChanged;
  const PhotoPickerTile({
    super.key,
    required this.photo,
    required this.onChanged,
    this.name = '',
    this.isPortrait = false,
  });
  @override
  State<PhotoPickerTile> createState() => _PhotoPickerTileState();
}

class _PhotoPickerTileState extends State<PhotoPickerTile> {
  bool _busy = false;
  Future<void> _pick(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
        requestFullMetadata: false,
      );
      if (file == null) return;
      var photo = PhotoService.localPhoto(await file.readAsBytes());
      if (!mounted) return;
      final auth = context.read<AuthService?>();
      if (auth != null && auth.isAuthenticated) {
        final uid = auth.currentUser?.uid;
        final client = http.Client();
        try {
          photo = await PhotoService.uploadIfNeeded(
            photo,
            widget.isPortrait ? 'portrait' : 'connection',
            auth,
            client,
          );
        } finally {
          client.close();
        }
        if (!mounted || auth.currentUser?.uid != uid) return;
      }
      if (mounted) widget.onChanged(photo);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is PhotoSafetyException
                  ? e.message
                  : e is FormatException
                  ? e.message
                  : 'Photo access is unavailable. Try choosing a JPEG from your files.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaceAvatar(name: widget.name, photo: widget.photo, radius: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.isPortrait
                      ? 'Your card portrait'
                      : 'A face to remember',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(_busy ? 'Checking photo…' : 'Choose photo'),
              ),
              if (kIsWeb ||
                  [
                    TargetPlatform.android,
                    TargetPlatform.iOS,
                  ].contains(defaultTargetPlatform))
                TextButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Take photo'),
                ),
              if (widget.photo.isNotEmpty)
                TextButton(
                  onPressed: _busy ? null : () => widget.onChanged(''),
                  child: const Text('Remove from card'),
                ),
            ],
          ),
          Text(
            widget.isPortrait
                ? 'This portrait is included when you share this identity. Photos are safety-checked before upload.'
                : widget.photo.startsWith('portrait:')
                ? 'This portrait came with their card. A photo you add here stays private to your wallet.'
                : 'A photo you add here is private to your wallet. It is safety-checked before upload.',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    ),
  );
}
