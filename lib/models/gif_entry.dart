import 'package:hive/hive.dart';

part 'gif_entry.g.dart'; // This line is crucial for the generated code

@HiveType(typeId: 0) // Unique typeId for this object
class GifEntry extends HiveObject {
  @HiveField(0)
  String originalUrl;

  @HiveField(1)
  String
      mediaUrl; // Scraped URL for Tenor, or same as originalUrl for direct GIFs

  GifEntry({required this.originalUrl, required this.mediaUrl});
}
