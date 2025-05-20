import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class MyCacheManager extends CacheManager {
  static const key =
      "plethoraCacheKey"; // Still a unique key for this cache manager instance

  static MyCacheManager? _instance;

  factory MyCacheManager() {
    // Use null-aware assignment here to fix the lint
    _instance ??= MyCacheManager._();
    return _instance!;
  }

  MyCacheManager._()
    : super(
        Config(
          key,
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 250,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileSystem: IOFileSystem(key),
        ),
      );
}
