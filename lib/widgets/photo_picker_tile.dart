import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
      final photo = PhotoService.localPhoto(await file.readAsBytes());
      if (mounted) widget.onChanged(photo);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is FormatException
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
                label: const Text('Choose photo'),
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
                ? 'This portrait is included when you share this identity. Photos sync when you sign in.'
                : widget.photo.startsWith('portrait:')
                ? 'This portrait came with their card. A photo you add here stays private to your wallet.'
                : 'A photo you add here is private to your wallet. It stays available locally while offline.',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    ),
  );
}
