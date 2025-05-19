import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'gif_box.dart';
import 'tenor_scraper.dart';
import 'models/gif_entry.dart';
import 'package:flutter/foundation.dart';

class GifListScreen extends StatefulWidget {
  const GifListScreen({super.key});

  @override
  State<GifListScreen> createState() => _GifListScreenState();
}

class _GifListScreenState extends State<GifListScreen> {
  final TextEditingController _urlController = TextEditingController();

  // Re-add the desktop breakpoint
  static const double kDesktopBreakpoint = 600.0; // Adjust as needed

  final _gifBox = Hive.box<GifEntry>(gifBoxName);
  bool _isProcessingUrl = false;

  Future<void> _handleUrlInput() async {
    final originalUrl = _urlController.text.trim();
    if (originalUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a URL'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (_isProcessingUrl) return;

    Uri? uri = Uri.tryParse(originalUrl);
    if (uri?.hasAbsolutePath != true) {
      if (!mounted) return;
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

    String mediaUrl = originalUrl;

    if (originalUrl.contains('tenor.com')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attempting to scrape Tenor URL...'),
          duration: Duration(seconds: 2),
        ),
      );
      final scrapedUrl = await TenorScraper.scrapeGifUrl(originalUrl);

      if (!mounted) return;

      if (scrapedUrl != null) {
        mediaUrl = scrapedUrl;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scraping successful! Adding GIF.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to scrape GIF from Tenor URL. Cannot add.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          _isProcessingUrl = false;
        });
        return;
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adding URL.'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    final gifEntry = GifEntry(originalUrl: originalUrl, mediaUrl: mediaUrl);
    _gifBox.add(gifEntry);
    _urlController.clear();

    setState(() {
      _isProcessingUrl = false;
    });
  }

  void _removeGif(int index) {
    _gifBox.deleteAt(index);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('GIF removed.'),
      ),
    );
  }

  void _copyOriginalUrl(String originalUrl) {
    final urlToCopy = _cleanDiscordUrlForDisplay(originalUrl);
    Clipboard.setData(ClipboardData(text: urlToCopy));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied URL: $urlToCopy'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _cleanDiscordUrlForDisplay(String url) {
    if (url.contains('cdn.discordapp.com') ||
        url.contains('media.discordapp.net')) {
      try {
        final uri = Uri.parse(url);
        return uri.replace(query: '').toString();
      } catch (e) {
        debugPrint('Error cleaning Discord URL for display/copy: $e');
        return url;
      }
    }
    return url;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen width and check for desktop mode
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > kDesktopBreakpoint;

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
            // --- The list area ---
            Expanded(
              // Expanded takes up the remaining vertical space
              child: ValueListenableBuilder<Box<GifEntry>>(
                // ValueListenableBuilder for Hive changes
                valueListenable: _gifBox.listenable(),
                builder: (context, box, _) {
                  if (box.isEmpty) {
                    return const Center(
                      child: Text('No favorite GIFs yet. Add URLs!'),
                    );
                  }
                  // ListView.builder to display the list items
                  return ListView.builder(
                    itemCount: box.length,
                    itemBuilder: (context, index) {
                      final gifEntry = box.getAt(index);
                      if (gifEntry == null) {
                        return const SizedBox.shrink();
                      }

                      final displayedOriginalUrl =
                          _cleanDiscordUrlForDisplay(gifEntry.originalUrl);

                      // The Card widget for each list item
                      Widget gifCard = Card(
                        // Margin for spacing between cards
                        margin: const EdgeInsets.symmetric(
                            vertical: 4.0), // Keep vertical margin
                        clipBehavior: Clip.antiAlias,
                        child: GestureDetector(
                          onTap: () => _copyOriginalUrl(gifEntry.originalUrl),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // GIF Preview - maintains aspect ratio
                                CachedNetworkImage(
                                  imageUrl: gifEntry.mediaUrl,
                                  placeholder: (context, url) => Container(
                                    height: 150,
                                    color: Colors.grey[300],
                                    child: const Center(
                                        child: CircularProgressIndicator()),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    height: 150,
                                    color: Colors.red[100],
                                    child: const Icon(Icons.error,
                                        color: Colors.red),
                                  ),
                                  // Allow image to fill available width up to its intrinsic size or parent constraint
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 8.0),

                                // URLs and Delete Button
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayedOriginalUrl,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          if (gifEntry.originalUrl !=
                                              gifEntry.mediaUrl)
                                            Text(
                                              'Media: ${gifEntry.mediaUrl}',
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey[600]),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => _removeGif(index),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );

                      // Conditionally wrap the card for centering and max width on desktop
                      if (isDesktop) {
                        return Center(
                          // Center the card horizontally
                          child: ConstrainedBox(
                            // Limit the max width of the card
                            constraints: const BoxConstraints(
                              maxWidth:
                                  700.0, // Adjust max width for the card as needed
                            ),
                            child:
                                gifCard, // Place the Card inside the constraint
                          ),
                        );
                      } else {
                        // On phone, return the card with horizontal padding
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal:
                                  8.0), // Add padding to the card on phone
                          child: gifCard,
                        );
                      }
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
