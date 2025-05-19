import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class MyCacheManager extends CacheManager with ImageCacheManager {
  // Define your custom cache duration and maximum number of files
  // WARNING: Setting these values very high can consume significant storage
  static const Duration _cacheDuration = Duration(
    days: 365 * 50,
  ); // Cache for 50 years
  static const int _maxCacheFiles = 10000; // Keep up to 10,000 files
  // Removed maxCacheSize as it's not a parameter in Config

  MyCacheManager._()
    : super(
        Config(
          'myFavoriteGifsCacheKey', // A unique key for this cache instance
          stalePeriod: _cacheDuration,
          maxNrOfCacheObjects: _maxCacheFiles,
          // maxCacheSize: ..., // This parameter does not exist
          // Consider adding fileService if you need custom file fetching logic
          // fileService: ...,
        ),
      );

  static final MyCacheManager _instance = MyCacheManager._();

  factory MyCacheManager() {
    return _instance;
  }
}
