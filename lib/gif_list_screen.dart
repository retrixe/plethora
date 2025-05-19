import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'gif_box.dart';
import 'tenor_scraper.dart';
import 'models/gif_entry.dart';

class GifListScreen extends StatefulWidget {
  const GifListScreen({super.key});

  @override
  State<GifListScreen> createState() => _GifListScreenState();
}

class _GifListScreenState extends State<GifListScreen> {
  final TextEditingController _urlController = TextEditingController();
  final _gifBox = Hive.box<GifEntry>(gifBoxName);
  bool _isProcessingUrl = false;

  Future<void> _handleUrlInput() async {
    final originalUrl = _urlController.text.trim();
    if (originalUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a URL'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (_isProcessingUrl) return;

    // Validate if it's a valid URL format before processing
    Uri? uri = Uri.tryParse(originalUrl);
    if (uri?.hasAbsolutePath != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid URL format'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isProcessingUrl = true;
    });

    String mediaUrl = originalUrl; // Start with originalUrl for media

    // --- Handle Tenor URLs ---
    if (originalUrl.contains('tenor.com')) {
      // Attempt to scrape the original Tenor page to get the media URL.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attempting to scrape Tenor URL...'),
          duration: Duration(seconds: 2),
        ),
      );
      final scrapedUrl = await TenorScraper.scrapeGifUrl(
          originalUrl); // Use originalUrl for scraping

      if (scrapedUrl != null) {
        mediaUrl = scrapedUrl; // Use scraped URL for preview/caching
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scraping successful! Adding GIF.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // If scraping failed, we can't get a media URL for preview/caching
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to scrape GIF from Tenor URL. Cannot add.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          _isProcessingUrl = false;
        });
        return; // Exit if scraping failed
      }
    } else {
      // For non-Tenor URLs (including Discord), mediaUrl is the originalUrl (with query string)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adding URL.'),
          duration: Duration(seconds: 1),
        ),
      );
      // mediaUrl is already set to originalUrl at the beginning
    }

    // --- Add the GifEntry object to Hive ---
    // Save the original URL as entered (with query string)
    final gifEntry = GifEntry(originalUrl: originalUrl, mediaUrl: mediaUrl);
    _gifBox.add(gifEntry);
    _urlController.clear();

    setState(() {
      _isProcessingUrl = false;
    });
  }

  void _removeGif(int index) {
    _gifBox.deleteAt(index);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('GIF removed.'),
      ),
    );
  }

  // Function to copy the original URL to clipboard, cleaned for Discord
  void _copyOriginalUrl(String originalUrl) {
    // Clean the URL before copying if it's a Discord URL
    final urlToCopy = _cleanDiscordUrlForDisplay(originalUrl);
    Clipboard.setData(ClipboardData(text: urlToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Copied URL: $urlToCopy'), // Show the copied URL in the snackbar
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Helper function to clean Discord URLs for display and copying
  String _cleanDiscordUrlForDisplay(String url) {
    if (url.contains('cdn.discordapp.com') ||
        url.contains('media.discordapp.net')) {
      try {
        final uri = Uri.parse(url);
        return uri.replace(query: '').toString();
      } catch (e) {
        // If parsing fails for some reason, return the original URL
        print('Error cleaning Discord URL for display/copy: $e');
        return url;
      }
    }
    return url; // Return original URL if not a Discord link
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite GIFs'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'Enter URL (GIF, Tenor, Discord)',
                      border: const OutlineInputBorder(),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10.0),
                      suffixIcon: _isProcessingUrl
                          ? const Padding(
                              padding: EdgeInsets.all(8.0),
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.0),
                            )
                          : null,
                    ),
                    keyboardType: TextInputType.url,
                    onSubmitted: (_) => _handleUrlInput(),
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: _isProcessingUrl ? null : _handleUrlInput,
                  child: const Text('Submit'),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: _gifBox.listenable(),
                builder: (context, Box<GifEntry> box, _) {
                  if (box.isEmpty) {
                    return const Center(
                      child: Text('No favorite GIFs yet. Add URLs!'),
                    );
                  }
                  return ListView.builder(
                    itemCount: box.length,
                    itemBuilder: (context, index) {
                      final gifEntry = box.getAt(index);
                      if (gifEntry == null) {
                        return const SizedBox.shrink();
                      }

                      // Clean the URL for display in the title text
                      final displayedOriginalUrl =
                          _cleanDiscordUrlForDisplay(gifEntry.originalUrl);

                      return GestureDetector(
                        // Pass the originalUrl to the copy function
                        onTap: () => _copyOriginalUrl(gifEntry.originalUrl),
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(8.0),
                            leading: SizedBox(
                              width: 100,
                              child: CachedNetworkImage(
                                imageUrl: gifEntry
                                    .mediaUrl, // Use mediaUrl for preview
                                placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.error),
                                fit: BoxFit.cover,
                              ),
                            ),
                            // Display the cleaned URL in the title
                            title: Text(displayedOriginalUrl,
                                overflow: TextOverflow.ellipsis),
                            // Optionally show the media URL if different from original
                            subtitle: gifEntry.originalUrl != gifEntry.mediaUrl
                                ? Text('Media: ${gifEntry.mediaUrl}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 10))
                                : null,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeGif(index),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
