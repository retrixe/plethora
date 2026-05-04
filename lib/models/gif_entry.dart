import 'package:hive/hive.dart';

part 'gif_entry.g.dart';

@HiveType(typeId: 0)
class GifEntry extends HiveObject {
  @HiveField(0)
  String originalUrl;

  @HiveField(1)
  String mediaUrl;

  @HiveField(2) // Add this new field for local path
  String? localPath; // Make it nullable as it might not always exist

  @HiveField(3)
  int? width;

  @HiveField(4)
  int? height;

  GifEntry({
    required this.originalUrl,
    required this.mediaUrl,
    this.localPath,
    this.width,
    this.height,
  });

  // Convert GifEntry object to a Map (for JSON encoding)
  Map<String, dynamic> toJson() {
    return {
      'originalUrl': originalUrl,
      'mediaUrl': mediaUrl,
      'localPath': localPath, // Include localPath in JSON
      'width': width,
      'height': height,
    };
  }

  // Create a GifEntry object from a Map (for JSON decoding)
  factory GifEntry.fromJson(Map<String, dynamic> json) {
    return GifEntry(
      originalUrl: json['originalUrl'] as String,
      mediaUrl: json['mediaUrl'] as String,
      localPath: json['localPath'] as String?, // Read localPath from JSON
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );
  }
}
