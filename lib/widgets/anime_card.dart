import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AnimeCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final VoidCallback? onTap;

  const AnimeCard({super.key, required this.title, this.imageUrl, this.onTap});

  String _getCorsProxiedUrl(String url) {
    // Use CORS proxy for web, direct URL for mobile/desktop
    if (kIsWeb) {
      return 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 160,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: _getCorsProxiedUrl(imageUrl!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        httpHeaders: const {'User-Agent': 'Mozilla/5.0'},
                        placeholder: (context, url) => Container(
                          color: Colors.grey.withValues(alpha: 0.3),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.withValues(alpha: 0.3),
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 48),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey.withValues(alpha: 0.3),
                        child: const Center(
                          child: Icon(Icons.image_outlined, size: 48),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
