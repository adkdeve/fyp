import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';

Widget buildImage(
    dynamic icon, {
      double? width,
      double? height,
      Color? color,
      BoxFit fit = BoxFit.contain,
      required BuildContext context,
    }) {
  try {
    // Handle IconData
    if (icon is IconData) {
      return Icon(
        icon,
        color: color,
        size: width,
      );
    }

    // Handle SvgPicture widget directly
    if (icon is SvgPicture) {
      return icon;
    }

    // Handle string inputs
    if (icon is String) {
      // If SVG
      if (icon.endsWith(".svg")) {
        // Network SVG
        if (_isValidUrl(icon)) {
          return SvgPicture.network(
            icon,
            width: width,
            height: height,
            color: color,
            fit: fit,
            placeholderBuilder: (_) => _fallbackIcon(width),
          );
        }

        // Local SVG asset
        return SvgPicture.asset(
          icon,
          width: width,
          height: height,
          color: color,
          fit: fit,
          placeholderBuilder: (_) => _fallbackIcon(width),
        );
      }

      // If Network image (PNG/JPG/Webp etc.)
      if (_isValidUrl(icon)) {
        return CachedNetworkImage(
          imageUrl: icon,
          width: width,
          height: height,
          fit: fit,
          memCacheWidth: ((width ?? 100) * MediaQuery.of(context).devicePixelRatio).toInt(),
          placeholder: (context, url) => _fallbackIcon(width),
          errorWidget: (_, __, ___) => _fallbackIcon(width),
        );
      }

      // Local asset image
      if (icon.endsWith(".png") ||
          icon.endsWith(".jpg") ||
          icon.endsWith(".jpeg") ||
          icon.endsWith(".webp")) {
        return Image.asset(
          icon,
          width: width,
          height: height,
          fit: fit,
          color: color,
          errorBuilder: (_, __, ___) => _fallbackIcon(width),
        );
      }
    }

    // Anything else → fallback
    return _fallbackIcon(width);
  } catch (e) {
    return _fallbackIcon(width);
  }
}

bool _isValidUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return uri.isScheme("http") || uri.isScheme("https");
}

Widget _fallbackIcon(double? size) {
  return Icon(
    Icons.broken_image,
    color: Colors.grey,
    size: size ?? 20,
  );
}
