import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'klipy_config.dart';

class KlipyScraper {
  static Future<String?> scrapeGifUrl(String klipyUrl) async {
    try {
      final uri = Uri.parse(klipyUrl);
      final host = uri.host.toLowerCase();
      final apiKey = KlipyConfig.appKey;

      if (host == 'static.klipy.com') {
        debugPrint('KlipyScraper: Using direct static media URL: $klipyUrl');
        return klipyUrl;
      }

      if (host == 'klipy.com' &&
          uri.pathSegments.isNotEmpty &&
          uri.pathSegments.first == 'ii') {
        final directMediaUrl = 'https://static.klipy.com${uri.path}';
        debugPrint('KlipyScraper: Converted CDN URL to: $directMediaUrl');
        return directMediaUrl;
      }

      if (apiKey.isNotEmpty) {
        final slug = _extractGifSlug(uri);
        if (slug != null && slug.isNotEmpty) {
          final apiUri = Uri.https(
            'api.klipy.com',
            '/api/v1/$apiKey/gifs/items',
            {'slugs': slug},
          );

          final response = await http.get(apiUri);
          if (response.statusCode == 200) {
            final decoded = jsonDecode(response.body);
            final data =
                decoded is Map<String, dynamic> ? decoded['data'] : null;
            final items = data is Map<String, dynamic> ? data['data'] : null;
            if (items is List && items.isNotEmpty) {
              final item = items.first;
              if (item is Map<String, dynamic>) {
                final resolvedUrl = _extractGifUrlFromItem(item);
                if (resolvedUrl != null) {
                  debugPrint(
                    'KlipyScraper: Resolved via API using slug "$slug": $resolvedUrl',
                  );
                  return resolvedUrl;
                }
              }
            }

            debugPrint(
              'KlipyScraper: KLIPY API returned no usable GIF URL for slug "$slug".',
            );
          } else {
            debugPrint(
              'KlipyScraper: KLIPY API request failed: ${response.statusCode}',
            );
          }
        }
      }

      if (host == 'klipy.com') {
        final response = await http.get(
          uri,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
          },
        );

        if (response.statusCode == 200) {
          final html = response.body;
          final directGifMatch = RegExp(
            r"""https://static\.klipy\.com/ii/[^"'\s>]+\.gif""",
            caseSensitive: false,
          ).firstMatch(html);

          if (directGifMatch != null) {
            final directGifUrl = directGifMatch.group(0);
            if (directGifUrl != null && directGifUrl.isNotEmpty) {
              debugPrint('KlipyScraper: Scraped direct GIF URL: $directGifUrl');
              return directGifUrl;
            }
          }

          final directMediaMatch = RegExp(
            r"""https://static\.klipy\.com/ii/[^"'\s>]+""",
            caseSensitive: false,
          ).firstMatch(html);

          if (directMediaMatch != null) {
            final directMediaUrl = directMediaMatch.group(0);
            if (directMediaUrl != null && directMediaUrl.isNotEmpty) {
              debugPrint(
                'KlipyScraper: Scraped direct media URL: $directMediaUrl',
              );
              return directMediaUrl;
            }
          }

          debugPrint(
            'KlipyScraper: KLIPY page loaded but no direct media URL was found.',
          );
        } else {
          debugPrint(
            'KlipyScraper: Failed to load KLIPY page: ${response.statusCode}',
          );
        }
      }

      debugPrint(
        'KlipyScraper: Unsupported KLIPY URL or page scraping failed: $klipyUrl',
      );
      return null;
    } catch (e) {
      debugPrint('KlipyScraper error: $e');
      return null;
    }
  }

  static String? _extractGifSlug(Uri uri) {
    if (uri.host.toLowerCase() != 'klipy.com') {
      return null;
    }

    if (uri.pathSegments.length < 2 || uri.pathSegments.first != 'gifs') {
      return null;
    }

    return uri.pathSegments[1];
  }

  static String? _extractGifUrlFromItem(Map<String, dynamic> item) {
    final file = item['file'];
    if (file is! Map<String, dynamic>) {
      return null;
    }

    final preferredSizes = ['hd', 'md', 'sm', 'xs'];
    for (final size in preferredSizes) {
      final sizeData = file[size];
      if (sizeData is Map<String, dynamic>) {
        final gifData = sizeData['gif'];
        if (gifData is Map<String, dynamic>) {
          final url = gifData['url'];
          if (url is String && url.isNotEmpty) {
            return url;
          }
        }
      }
    }

    return null;
  }
}
