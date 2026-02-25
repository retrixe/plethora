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
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:archive/archive_io.dart';

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
  bool _useMasonryLayout = true;
  bool _showDetails = false;
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

      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Favorite GIFs',
        fileName: 'favorite_gifs_export.zip',
        allowedExtensions: ['zip'],
        type: FileType.custom,
      );

      if (outputPath != null) {
        // Create archive
        final archive = Archive();

        // Add JSON metadata file
        archive.addFile(
          ArchiveFile('metadata.json', jsonString.length, jsonString.codeUnits),
        );

        // Add local GIF files
        int gifCount = 0;
        for (final gifEntry in allFavorites) {
          if (gifEntry.localPath != null) {
            final gifFile = File(gifEntry.localPath!);
            if (await gifFile.exists()) {
              final bytes = await gifFile.readAsBytes();
              final fileName = gifEntry.localPath!.split('/').last;
              archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
              gifCount++;
            }
          }
        }

        // Write ZIP file
        final zipFile = File(outputPath);
        await zipFile.writeAsBytes(ZipEncoder().encode(archive)!);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to $outputPath ($gifCount GIFs included)'),
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
        allowedExtensions: ['json', 'zip'],
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

        final filePath = selectedFile.path!;
        String jsonString = '';
        Map<String, List<int>> extractedGifs = {}; // fileName -> fileBytes

        // Check if it's a ZIP file
        if (filePath.endsWith('.zip')) {
          final zipFile = File(filePath);
          final zipBytes = await zipFile.readAsBytes();
          final archive = ZipDecoder().decodeBytes(zipBytes);

          // Extract metadata.json and GIF files
          for (final file in archive) {
            if (file.name == 'metadata.json') {
              jsonString = String.fromCharCodes(file.content as List<int>);
            } else if (!file.isFile || file.name.startsWith('/')) {
              continue;
            } else {
              // This is a GIF file
              extractedGifs[file.name] = file.content as List<int>;
            }
          }

          if (jsonString.isEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No metadata.json found in ZIP file.'),
                backgroundColor: Colors.redAccent,
              ),
            );
            return;
          }
        } else {
          // It's a JSON file
          final file = File(filePath);
          jsonString = await file.readAsString();
        }

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
        int successfullyImported = 0;
        int failedImports = 0;

        for (final entry in newFavoritesToProcess) {
          String? currentLocalPath;

          // Check if the GIF was exported with the ZIP
          if (entry.localPath != null) {
            final fileName = entry.localPath!.split('/').last;
            if (extractedGifs.containsKey(fileName)) {
              // Copy the extracted GIF to permanent storage
              try {
                final localFile = File(
                  '${_permanentGifStorageDirectory.path}/$fileName',
                );
                await localFile.writeAsBytes(extractedGifs[fileName]!);
                currentLocalPath = localFile.path;
                debugPrint('Imported GIF from ZIP: $currentLocalPath');
                successfullyImported++;
              } catch (e) {
                debugPrint('Error importing GIF file: $e');
                failedImports++;
              }
            } else {
              // GIF not in ZIP, try to download
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
                  currentLocalPath = localFile.path;
                  debugPrint('Downloaded GIF: $currentLocalPath');
                  successfullyImported++;
                } else {
                  debugPrint(
                    'Failed to download ${entry.mediaUrl}: Status ${response.statusCode}',
                  );
                  failedImports++;
                }
              } catch (e) {
                debugPrint('Error downloading GIF: $e');
                failedImports++;
              }
            }
          }

          finalImportedEntries.add(
            GifEntry(
              originalUrl: entry.originalUrl,
              mediaUrl: entry.mediaUrl,
              localPath: currentLocalPath,
            ),
          );
        }

        _gifBox.addAll(finalImportedEntries);

        if (!mounted) return;
        String message =
            'Successfully imported ${finalImportedEntries.length} new favorite(s). ';
        if (successfullyImported > 0) {
          message += '$successfullyImported GIF(s) were imported.';
        }
        if (failedImports > 0) {
          message += '$failedImports GIF(s) failed to import.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: (failedImports > 0) ? Colors.orange : Colors.green,
            duration: Duration(
              seconds: (successfullyImported > 0 || failedImports > 0) ? 5 : 3,
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
    final int crossAxisCount =
        (isDesktop
                ? (screenWidth / 280).floor().clamp(2, 4)
                : (screenWidth / 180).floor().clamp(1, 2))
            .toInt();

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
              } else if (result == 'masonry') {
                setState(() {
                  _useMasonryLayout = !_useMasonryLayout;
                });
              } else if (result == 'details') {
                setState(() {
                  _showDetails = !_showDetails;
                });
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
                  const PopupMenuDivider(),
                  CheckedPopupMenuItem<String>(
                    value: 'masonry',
                    checked: _useMasonryLayout,
                    child: const Text('Masonry layout'),
                  ),
                  CheckedPopupMenuItem<String>(
                    value: 'details',
                    checked: _showDetails,
                    child: const Text('Show details'),
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
                  Widget buildGifCard(int index) {
                    final gifEntry =
                        filteredGifList[index]; // Use the filtered list

                    final displayedOriginalUrl = _cleanDiscordUrlForDisplay(
                      gifEntry.originalUrl,
                    );

                    return Card(
                      margin:
                          _useMasonryLayout
                              ? EdgeInsets.zero
                              : const EdgeInsets.symmetric(vertical: 4.0),
                      clipBehavior: Clip.antiAlias,
                      child: GestureDetector(
                        onTap: () => _copyOriginalUrl(gifEntry.originalUrl),
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
                                      (context, error, stackTrace) => Container(
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
                                  fit: BoxFit.fitWidth,
                                ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
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
                                        if (_showDetails &&
                                            gifEntry.originalUrl !=
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
                                        if (_showDetails &&
                                            gifEntry.localPath != null)
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
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (_useMasonryLayout) {
                    return MasonryGridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      gridDelegate:
                          SliverSimpleGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                          ),
                      mainAxisSpacing: 8.0,
                      crossAxisSpacing: 8.0,
                      itemCount: filteredGifList.length,
                      itemBuilder: (context, index) {
                        return buildGifCard(index);
                      },
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    itemCount: filteredGifList.length,
                    itemBuilder: (context, index) {
                      final gifCard = buildGifCard(index);
                      if (isDesktop) {
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 700.0),
                            child: gifCard,
                          ),
                        );
                      }
                      return gifCard;
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
