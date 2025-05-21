import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'gif_box.dart';
import 'tenor_scraper.dart';
import 'giphy_scraper.dart';
import 'models/gif_entry.dart';
import 'cache/my_cache_manager.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

class GifListScreen extends StatefulWidget {
  const GifListScreen({super.key});

  @override
  State<GifListScreen> createState() => _GifListScreenState();
}

class _GifListScreenState extends State<GifListScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _searchController =
      TextEditingController(); // New controller for search
  String _searchText = ''; // New state variable for search text

  static const double kDesktopBreakpoint = 600.0;

  final _gifBox = Hive.box<GifEntry>(gifBoxName);
  bool _isProcessingUrl = false;
  late Directory _permanentGifStorageDirectory;
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _initializePermanentStorage();
    // Listen to changes in the search text field
    _searchController.addListener(() {
      setState(() {
        _searchText =
            _searchController.text
                .toLowerCase(); // Convert to lower case for case-insensitive search
      });
    });
  }

  Future<void> _initializePermanentStorage() async {
    final appSupportDir = await getApplicationSupportDirectory();
    _permanentGifStorageDirectory = Directory(
      '${appSupportDir.path}/permanent_gifs',
    );
    if (!await _permanentGifStorageDirectory.exists()) {
      await _permanentGifStorageDirectory.create(recursive: true);
    }
    debugPrint(
      'Permanent GIF storage directory: ${_permanentGifStorageDirectory.path}',
    );
  }

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
    String? localPath;

    if (originalUrl.contains('giphy.com')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attempting to scrape Giphy URL...'),
          duration: Duration(seconds: 2),
        ),
      );
      // GiphyScraper.scrapeGifUrl is now synchronous as it only parses the URL string
      final scrapedUrl = GiphyScraper.scrapeGifUrl(originalUrl);

      if (!mounted) return;

      if (scrapedUrl != null) {
        mediaUrl = scrapedUrl;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Giphy URL parsed successfully! Adding GIF.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to parse GIF/media from Giphy URL. Cannot add.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          _isProcessingUrl = false;
        });
        return;
      }
    } else if (originalUrl.contains('tenor.com')) {
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
            content: Text('Tenor scraping successful! Adding GIF.'),
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

    try {
      final response = await http.get(Uri.parse(mediaUrl));
      if (response.statusCode == 200) {
        final fileExtension = mediaUrl.split('.').last.split('?').first;
        final uniqueFileName = '${_uuid.v4()}.$fileExtension';
        final localFile = File(
          '${_permanentGifStorageDirectory.path}/$uniqueFileName',
        );

        await localFile.writeAsBytes(response.bodyBytes);
        localPath = localFile.path;
        debugPrint('GIF saved permanently to: $localPath');
      } else {
        debugPrint(
          'Failed to download GIF for permanent storage: ${response.statusCode}',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to download GIF for permanent storage (${response.statusCode}). Will use URL only.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving GIF permanently: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error saving GIF permanently ($e). Will use URL only.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }

    final gifEntry = GifEntry(
      originalUrl: originalUrl,
      mediaUrl: mediaUrl,
      localPath: localPath,
    );
    _gifBox.add(gifEntry);
    _urlController.clear();

    setState(() {
      _isProcessingUrl = false;
    });
  }

  void _removeGif(int index) async {
    // When removing, remember that the list is reversed for display.
    // So, we need to get the original index from the un-reversed box.
    // If the list is filtered, the index might not directly map to the box.
    // Instead, get the actual GifEntry object from the filtered list.
    final displayedGifList = _getFilteredGifList();
    final gifEntryToRemove = displayedGifList[index];

    // Find the actual index in the unfiltered box to remove it
    final originalIndex = _gifBox.values.toList().indexOf(gifEntryToRemove);
    if (originalIndex == -1) {
      debugPrint('Error: GIF not found in box for removal.');
      return;
    }

    if (gifEntryToRemove.localPath != null) {
      try {
        final file = File(gifEntryToRemove.localPath!);
        if (await file.exists()) {
          await file.delete();
          debugPrint('Deleted local file: ${gifEntryToRemove.localPath}');
        }
      } catch (e) {
        debugPrint('Error deleting local file: $e');
      }
    }
    _gifBox.deleteAt(originalIndex);
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
        final List<GifEntry> newFavoritesToProcess =
            importedFavorites.where((importedEntry) {
              return !existingUrls.contains(importedEntry.originalUrl);
            }).toList();

        if (newFavoritesToProcess.isEmpty) {
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

        List<GifEntry> finalImportedEntries = [];
        int successfullyDownloaded = 0;
        int failedDownloads = 0;

        for (final entry in newFavoritesToProcess) {
          String? currentLocalPath =
              entry.localPath; // Start with the path from the imported JSON

          // Check if localPath exists and is valid
          if (currentLocalPath != null &&
              await File(currentLocalPath).exists()) {
            debugPrint(
              'Local file exists for ${entry.originalUrl}: $currentLocalPath',
            );
            // File exists, no need to re-download
          } else {
            // Local path is null or file doesn't exist, try to download
            debugPrint(
              'Local file missing or invalid for ${entry.originalUrl}. Attempting download...',
            );
            String? newLocalPath;
            try {
              final response = await http.get(Uri.parse(entry.mediaUrl));
              if (response.statusCode == 200) {
                final fileExtension =
                    entry.mediaUrl.split('.').last.split('?').first;
                final uniqueFileName = '${_uuid.v4()}.$fileExtension';
                final localFile = File(
                  '${_permanentGifStorageDirectory.path}/$uniqueFileName',
                );
                await localFile.writeAsBytes(response.bodyBytes);
                newLocalPath = localFile.path;
                debugPrint('Successfully downloaded and saved: $newLocalPath');
                successfullyDownloaded++;
              } else {
                debugPrint(
                  'Failed to download ${entry.mediaUrl}: Status ${response.statusCode}',
                );
                failedDownloads++;
              }
            } catch (e) {
              debugPrint('Error during download of ${entry.mediaUrl}: $e');
              failedDownloads++;
            }
            currentLocalPath =
                newLocalPath; // Update localPath with the newly downloaded path or null
          }

          finalImportedEntries.add(
            GifEntry(
              originalUrl: entry.originalUrl,
              mediaUrl: entry.mediaUrl,
              localPath:
                  currentLocalPath, // Use the new (or existing valid) local path
            ),
          );
        }

        _gifBox.addAll(finalImportedEntries);

        if (!mounted) return;
        String message =
            'Successfully imported ${finalImportedEntries.length} new favorite(s). ';
        if (successfullyDownloaded > 0) {
          message += '$successfullyDownloaded GIF(s) were downloaded locally.';
        }
        if (failedDownloads > 0) {
          message += '$failedDownloads GIF(s) failed to download locally.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor:
                (failedDownloads > 0) ? Colors.orange : Colors.green,
            duration: Duration(
              seconds:
                  (successfullyDownloaded > 0 || failedDownloads > 0) ? 5 : 3,
            ),
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

  // New helper method to get filtered GIF list
  List<GifEntry> _getFilteredGifList() {
    final allGifs =
        _gifBox.values
            .toList()
            .reversed
            .toList(); // Always start with reversed list
    if (_searchText.isEmpty) {
      return allGifs;
    } else {
      return allGifs.where((gif) {
        final lowerCaseSearchText = _searchText.toLowerCase();
        return gif.originalUrl.toLowerCase().contains(lowerCaseSearchText) ||
            gif.mediaUrl.toLowerCase().contains(lowerCaseSearchText) ||
            (gif.localPath?.toLowerCase().contains(lowerCaseSearchText) ??
                false); // Check localPath too
      }).toList();
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _searchController.dispose(); // Dispose the new search controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > kDesktopBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite GIFs'),
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
                      hintText: 'Enter URL (GIF, Tenor, Giphy, Discord)',
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
            const SizedBox(height: 16.0),
            // New Search Bar
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search GIFs',
                  hintText: 'Filter by URL or local path...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 0,
                  ), // Adjust vertical padding
                ),
                onChanged: (value) {
                  // The addListener on the controller already handles setState
                  // This callback can be used for other logic if needed.
                },
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<Box<GifEntry>>(
                valueListenable: _gifBox.listenable(),
                builder: (context, box, _) {
                  final filteredGifList =
                      _getFilteredGifList(); // Get the filtered list

                  if (filteredGifList.isEmpty) {
                    if (_searchText.isNotEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No GIFs match your search.'),
                        ),
                      );
                    }
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No favorite GIFs yet. Add URLs!'),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: filteredGifList.length,
                    itemBuilder: (context, index) {
                      final gifEntry =
                          filteredGifList[index]; // Use the filtered list

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
                                gifEntry.localPath != null &&
                                        File(gifEntry.localPath!).existsSync()
                                    ? Image.file(
                                      File(gifEntry.localPath!),
                                      width: double.infinity,
                                      fit: BoxFit.fitWidth,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                height: 150,
                                                color: Colors.red[100],
                                                child: const Icon(
                                                  Icons.error,
                                                  color: Colors.red,
                                                ),
                                              ),
                                    )
                                    : CachedNetworkImage(
                                      imageUrl: gifEntry.mediaUrl,
                                      cacheManager: MyCacheManager(),
                                      placeholder:
                                          (context, url) => Container(
                                            height: 150,
                                            color: Colors.grey[300],
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(),
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
                                      fit: BoxFit.fitWidth,
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
                                          if (gifEntry.localPath != null)
                                            Text(
                                              'Local: ${gifEntry.localPath!.split('/').last}',
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[400],
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
