import 'dart:typed_data';

import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.imageBytes,
    this.radius = 20,
  });

  final String name;
  final String? photoUrl;
  final Uint8List? imageBytes;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedPhotoUrl = photoUrl?.trim() ?? '';
    ImageProvider<Object>? imageProvider;
    if (imageBytes != null) {
      imageProvider = MemoryImage(imageBytes!);
    } else if (normalizedPhotoUrl.isNotEmpty) {
      imageProvider = NetworkImage(normalizedPhotoUrl);
    }
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.65,
      ),
      foregroundImage: imageProvider,
      child: Text(
        initial,
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
