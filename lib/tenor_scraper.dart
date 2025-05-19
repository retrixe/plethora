import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

class TenorScraper {
  /// Attempts to scrape a Tenor page URL to find a direct GIF or video URL.
  /// Returns the found URL or null if scraping fails.
  static Future<String?> scrapeGifUrl(String tenorPageUrl) async {
    try {
      final response = await http.get(Uri.parse(tenorPageUrl));

      if (response.statusCode == 200) {
        final document = parse(response.body);

        // --- Attempt 1: Look for Open Graph meta tags ---
        // Tenor often uses og:image for the preview/main media.
        // og:image might point to a GIF or an MP4. cached_network_image
        // can sometimes handle MP4s if the platform supports it.
        final ogImageMeta = document.head?.querySelector(
          'meta[property="og:image"]',
        );
        if (ogImageMeta != null) {
          final content = ogImageMeta.attributes['content'];
          if (content != null && content.isNotEmpty) {
            debugPrint('Scraped og:image URL: $content');
            return content; // Found a potential media URL
          }
        }

        // --- Attempt 2: Look for specific video/image tags (less reliable) ---
        // This is highly dependent on Tenor's current page structure.
        // This part is speculative and might need adjustment based on actual page source.
        // Example: looking for a video tag that might play the GIF
        // final videoSrc = document.body?.querySelector('video source');
        // if (videoSrc != null) {
        //   final src = videoSrc.attributes['src'];
        //   if (src != null && src.isNotEmpty) {
        //     print('Scraped video source URL: $src');
        //     return src; // Found a potential video URL
        //   }
        // }

        // Example: looking for an img tag (less common for main GIF on page)
        // final imgTag = document.body?.querySelector('img.gif-item'); // Example class name
        // if (imgTag != null) {
        //   final src = imgTag.attributes['src'];
        //   if (src != null && src.isNotEmpty) {
        //     print('Scraped image source URL: $src');
        //     return src; // Found a potential image URL
        //   }
        // }

        // If neither attempt finds a URL
        debugPrint('Scraping failed to find a media URL on $tenorPageUrl');
        return null;
      } else {
        // Handle non-200 status codes
        debugPrint('Failed to load Tenor page: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      // Handle any exceptions during the process
      debugPrint('Error during scraping: $e');
      return null;
    }
  }
}
