import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/photo_service.dart';

class FaceAvatar extends StatefulWidget {
  final String name, photo;
  final double radius;
  final Color? backgroundColor, foregroundColor;
  const FaceAvatar({
    super.key,
    required this.name,
    this.photo = '',
    this.radius = 24,
    this.backgroundColor,
    this.foregroundColor,
  });
  @override
  State<FaceAvatar> createState() => _FaceAvatarState();
}

class _FaceAvatarState extends State<FaceAvatar> {
  String? _key;
  Future<Uint8List?>? _bytes;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService?>();
    final key = '${auth?.currentUser?.uid}:${widget.photo}';
    if (key != _key) {
      _key = key;
      _bytes = PhotoService.load(widget.photo, auth);
    }
    final initials = widget.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0])
        .join();
    final fallback = Text(
      initials.isEmpty ? '?' : initials,
      style: TextStyle(
        color: widget.foregroundColor,
        fontWeight: FontWeight.bold,
        fontSize: widget.radius * .65,
      ),
    );
    return Semantics(
      label: 'Photo of ${widget.name}',
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor,
        child: FutureBuilder<Uint8List?>(
          key: ValueKey(key),
          future: _bytes,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return fallback;
            return ClipOval(
              child: Image.memory(
                snapshot.data!,
                key: ValueKey(key),
                width: widget.radius * 2,
                height: widget.radius * 2,
                fit: BoxFit.cover,
                cacheWidth: 384,
                errorBuilder: (_, error, stack) => fallback,
              ),
            );
          },
        ),
      ),
    );
  }
}
