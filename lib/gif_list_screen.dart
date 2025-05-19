import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'gif_box.dart';
import 'tenor_scraper.dart';
import 'models/gif_entry.dart';
import 'cache/my_cache_manager.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('GIF removed.')));
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

  Future<void> _exportFavorites() async {
    try {
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

      final List<Map<String, dynamic>> jsonList =
          allFavorites.map((gifEntry) => gifEntry.toJson()).toList();
      final String jsonString = jsonEncode(jsonList);

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Favorite GIFs',
        fileName: 'favorite_gifs_export.json',
        allowedExtensions: ['json'],
        type: FileType.custom,
      );

      if (outputFile != null) {
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
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Export canceled.')));
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

  Future<void> _importFavorites() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import Favorite GIFs',
        allowedExtensions: ['json'],
        type: FileType.custom,
        allowMultiple: false,
      );

      if (result != null) {
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
        final String jsonString = await file.readAsString();

        final List<dynamic> decodedJson = jsonDecode(jsonString);

        final List<GifEntry> importedFavorites =
            decodedJson
                .map((jsonItem) {
                  try {
                    return GifEntry.fromJson(jsonItem as Map<String, dynamic>);
                  } catch (e) {
                    debugPrint('Error decoding JSON item: $jsonItem - $e');
                    return null;
                  }
                })
                .whereType<GifEntry>()
                .toList();

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

        final existingUrls =
            _gifBox.values.map((entry) => entry.originalUrl).toSet();
        final newFavoritesToAdd =
            importedFavorites.where((importedEntry) {
              return !existingUrls.contains(importedEntry.originalUrl);
            }).toList();

        if (newFavoritesToAdd.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No new favorites to add (duplicates found or no valid entries).',
              ),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          return;
        }

        _gifBox.addAll(newFavoritesToAdd);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully imported ${newFavoritesToAdd.length} favorite(s)!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Import canceled.')));
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
        // Add actions to the AppBar for the overflow menu
        actions: [
          PopupMenuButton<String>(
            onSelected: (String result) {
              if (result == 'export') {
                _exportFavorites();
              } else if (result == 'import') {
                _importFavorites();
              }
            },
            itemBuilder:
                (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'export',
                    child: Text('Export Favorites'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'import',
                    child: Text('Import Favorites'),
                  ),
                ],
          ),
        ],
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                      ),
                      suffixIcon:
                          _isProcessingUrl
                              ? const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                ),
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
            // Removed the Row containing the import/export buttons from here
            const SizedBox(height: 16.0), // Keep spacing

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

                      final displayedOriginalUrl = _cleanDiscordUrlForDisplay(
                        gifEntry.originalUrl,
                      );

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
                                  placeholder:
                                      (context, url) => Container(
                                        height: 150,
                                        color: Colors.grey[300],
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                  errorWidget:
                                      (context, url, error) => Container(
                                        height: 150,
                                        color: Colors.red[100],
                                        child: const Icon(
                                          Icons.error,
                                          color: Colors.red,
                                        ),
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
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (gifEntry.originalUrl !=
                                              gifEntry.mediaUrl)
                                            Text(
                                              'Media: ${gifEntry.mediaUrl}',
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
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
                            constraints: const BoxConstraints(maxWidth: 700.0),
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
