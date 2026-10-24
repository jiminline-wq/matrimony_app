import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // ✅ kIsWeb এর জন্য
import 'package:flutter/material.dart';

class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Duration fadeInDuration;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;

  const AppNetworkImage(
    this.imageUrl, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.placeholder,
    this.errorWidget,
    this.errorBuilder,
    this.loadingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isHttp =
        imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    final isBlob = imageUrl.startsWith('blob:') || imageUrl.startsWith('data:');

    // ✅ এখানে kIsWeb চেক যোগ করা হয়েছে, যাতে ওয়েবে File() কল না হয়
    final isFile = !kIsWeb && !isHttp && !isBlob && File(imageUrl).existsSync();

    Widget img;
    if (isHttp) {
      img = CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: fadeInDuration,
        imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet, // 🔑 ফিক্স
        placeholder: placeholder,
        errorWidget: errorWidget,
      );
    } else if (isFile) {
      // মোবাইলের লোকাল ফাইলের জন্য
      img = Image.file(
        File(imageUrl),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder,
      );
    } else {
      // ✅ ওয়েবে blob: বা data: URL-এর জন্য Image.network নিখুঁতভাবে কাজ করে
      img = Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder,
        loadingBuilder: loadingBuilder,
      );
    }

    return borderRadius != null
        ? ClipRRect(borderRadius: borderRadius!, child: img)
        : img;
  }
}
