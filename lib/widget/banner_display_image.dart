import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mprs_android/core/utils/banner_image_util.dart';
import 'package:mprs_android/core/utils/banner_local_image_store.dart';

class BannerDisplayImage extends StatelessWidget {
  final String bannerId;
  final String imageUrl;
  final DateTime updatedAt;
  final int cacheKey;
  final BoxFit fit;
  final double? width;
  final double? height;

  const BannerDisplayImage({
    super.key,
    required this.bannerId,
    required this.imageUrl,
    required this.updatedAt,
    required this.cacheKey,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final localPath = BannerLocalImageStore.get(bannerId);
    if (localPath != null) {
      final file = File(localPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: fit,
          width: width,
          height: height,
          key: ValueKey('local_${bannerId}_$localPath'),
        );
      }
    }

    final cacheBustedImageUrl = BannerImageUtil.cacheBustedUrl(
      imageUrl,
      updatedAt: updatedAt,
      cacheKey: cacheKey,
    );

    if (cacheBustedImageUrl.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_not_supported),
      );
    }

    return Image.network(
      cacheBustedImageUrl,
      fit: fit,
      width: width,
      height: height,
      key: ValueKey(cacheBustedImageUrl),
      errorBuilder:
          (_, __, ___) => Container(
            width: width,
            height: height,
            color: Colors.grey.shade200,
            child: const Icon(Icons.image_not_supported),
          ),
    );
  }
}
