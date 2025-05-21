// lib/giphy_scraper.dart
// We no longer need http or html for this approach, but keeping them for consistency
// if future scraping attempts are made for other sites.
import 'package:flutter/foundation.dart'; // For debugPrint

class GiphyScraper {
  static String? scrapeGifUrl(String giphyUrl) {
    try {
      // Giphy URLs are typically in the format:
      // https://giphy.com/gifs/SOME-SLUG-GIF_ID
      // or just https://giphy.com/gifs/GIF_ID
      // We need to extract the GIF_ID.

      final uri = Uri.parse(giphyUrl);
      final pathSegments = uri.pathSegments;

      String? gifId;

      // Find the segment that looks like a Giphy ID (usually alphanumeric)
      // It's often the last segment, or the one after 'gifs'.
      for (int i = 0; i < pathSegments.length; i++) {
        final segment = pathSegments[i];
        if (segment.isNotEmpty) {
          // A Giphy ID is typically a string of alphanumeric characters.
          // It's usually the part *after* "gifs" and often before a potential slug.
          // Example: /gifs/hello-world-oQGg4fH5c43dG
          // Here, 'oQGg4fH5c43dG' is the ID.
          // Let's try to match the common pattern: "gifs/<slug>-<id>" or "gifs/<id>"
          if (segment.contains('-') && i > 0 && pathSegments[i - 1] == 'gifs') {
            final parts = segment.split('-');
            gifId = parts.last; // Assume the ID is the last part after a hyphen
            break;
          } else if (i > 0 && pathSegments[i - 1] == 'gifs') {
            gifId = segment; // If no hyphen, the segment itself might be the ID
            break;
          }
          // Also check if the whole path is just /gifs/ID
          if (pathSegments.length == 2 && pathSegments[0] == 'gifs') {
            gifId = pathSegments[1];
            break;
          }
        }
      }

      if (gifId != null && gifId.isNotEmpty) {
        // Construct a common Giphy direct media URL.
        // Giphy uses media.giphy.com for direct access.
        // Different qualities are available, 'giphy-downsized.gif' is a good balance.
        // Other options: 'giphy.gif' (original), 'giphy_s.gif' (still), 'giphy.mp4', 'giphy.webp'
        final directGifUrl = 'https://media.giphy.com/media/$gifId/giphy.gif';
        debugPrint('GiphyScraper: Constructed direct URL: $directGifUrl');
        return directGifUrl;
      } else {
        debugPrint(
          'GiphyScraper: Could not extract GIF ID from URL: $giphyUrl',
        );
        return null;
      }
    } catch (e) {
      debugPrint('GiphyScraper error: $e');
      return null;
    }
  }
}
