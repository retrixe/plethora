import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'gif_box.dart';
import 'tenor_scraper.dart';
import 'models/gif_entry.dart';
import 'package:flutter/foundation.dart';
import 'cache/my_cache_manager.dart'; // Import your custom cache manager
import 'dart:convert'; // Import for JSON encoding/decoding
import 'package:file_picker/file_picker.dart'; // Import file_picker
import 'dart:io'; // Import for File operations

class GifListScreen extends StatefulWidget {
  const GifListScreen({super.key});

  @override
  State<GifListScreen> createState() => _GifListScreenState();
}

class _GifListScreenState extends State<GifListScreen> {
  final TextEditingController _urlController = TextEditingController();

  static const double kDesktopBreakpoint = 600.0;

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

  // --- Export Favorites Logic ---
  Future<void> _exportFavorites() async {
    try {
      // Get all favorite GIFs from Hive
      final allFavorites = _gifBox.values.toList();

      if (allFavorites.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No favorites to export!'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }

      // Convert the list of GifEntry objects to a list of maps
      final List<Map<String, dynamic>> jsonList =
          allFavorites.map((gifEntry) => gifEntry.toJson()).toList();

      // Encode the list of maps to a JSON string
      final String jsonString = jsonEncode(jsonList);

      // Use file_picker to show a save file dialog
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Favorite GIFs',
        fileName: 'favorite_gifs_export.json', // Suggested filename
        allowedExtensions: ['json'], // Allow saving as JSON files
        type: FileType.custom, // Specify custom file type
      );

      if (outputFile != null) {
        // User selected a save location, write the JSON string to the file
        final File file = File(outputFile);
        await file.writeAsString(jsonString);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Favorites exported to $outputFile'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // User canceled the save dialog
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export canceled.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting favorites: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export favorites: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // --- Import Favorites Logic ---
  Future<void> _importFavorites() async {
    try {
      // Use file_picker to show a pick file dialog
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import Favorite GIFs',
        allowedExtensions: ['json'], // Allow picking only JSON files
        type: FileType.custom, // Specify custom file type
        allowMultiple: false, // Allow picking only a single file
      );

      if (result != null) {
        // User selected a file
        final PlatformFile selectedFile = result.files.single;

        if (selectedFile.path == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not get file path.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }

        final File file = File(selectedFile.path!);

        // Read the content of the selected file
        final String jsonString = await file.readAsString();

        // Decode the JSON string into a list of dynamic objects (maps)
        final List<dynamic> decodedJson = jsonDecode(jsonString);

        // Convert the list of maps back to GifEntry objects
        final List<GifEntry> importedFavorites = decodedJson
            .map((jsonItem) {
              // Add error handling for individual item conversion if needed
              try {
                return GifEntry.fromJson(jsonItem as Map<String, dynamic>);
              } catch (e) {
                debugPrint('Error decoding JSON item: $jsonItem - $e');
                return null; // Skip invalid items
              }
            })
            .whereType<GifEntry>()
            .toList(); // Filter out any null entries from failed conversions

        if (importedFavorites.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No valid favorites found in the file.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          return;
        }

        // --- Merge Strategy (Avoid Duplicates) ---
        // Get existing original URLs to check for duplicates
        final existingUrls =
            _gifBox.values.map((entry) => entry.originalUrl).toSet();
        final newFavoritesToAdd = importedFavorites.where((importedEntry) {
          // Add only if the originalUrl does not already exist
          return !existingUrls.contains(importedEntry.originalUrl);
        }).toList();

        if (newFavoritesToAdd.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No new favorites to add (duplicates found or no valid entries).'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          return;
        }

        // Add the new favorites to the Hive box
        _gifBox.addAll(newFavoritesToAdd);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Successfully imported ${newFavoritesToAdd.length} favorite(s)!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // User canceled the pick file dialog
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Import canceled.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error importing favorites: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import favorites: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            // --- Import/Export Buttons ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
              children: [
                ElevatedButton(
                  onPressed: _exportFavorites,
                  child: const Text('Export Favorites'),
                ),
                const SizedBox(width: 16.0), // Space between buttons
                ElevatedButton(
                  onPressed: _importFavorites,
                  child: const Text('Import Favorites'),
                ),
              ],
            ),
            const SizedBox(height: 16.0), // Space between buttons and list
            Expanded(
              child: ValueListenableBuilder<Box<GifEntry>>(
                valueListenable: _gifBox.listenable(),
                builder: (context, box, _) {
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

                      final displayedOriginalUrl =
                          _cleanDiscordUrlForDisplay(gifEntry.originalUrl);

                      Widget gifCard = Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        clipBehavior: Clip.antiAlias,
                        child: GestureDetector(
                          onTap: () => _copyOriginalUrl(gifEntry.originalUrl),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: gifEntry.mediaUrl,
                                  cacheManager: MyCacheManager(),
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
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 8.0),
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

                      if (isDesktop) {
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 700.0,
                            ),
                            child: gifCard,
                          ),
                        );
                      } else {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
