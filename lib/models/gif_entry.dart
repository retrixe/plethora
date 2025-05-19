import 'package:hive/hive.dart';

part 'gif_entry.g.dart';

@HiveType(typeId: 0)
class GifEntry extends HiveObject {
  @HiveField(0)
  String originalUrl;

  @HiveField(1)
  String mediaUrl;

  GifEntry({required this.originalUrl, required this.mediaUrl});

  // Convert GifEntry object to a Map (for JSON encoding)
  Map<String, dynamic> toJson() {
    return {
      'originalUrl': originalUrl,
      'mediaUrl': mediaUrl,
    };
  }

  // Create a GifEntry object from a Map (for JSON decoding)
  factory GifEntry.fromJson(Map<String, dynamic> json) {
    return GifEntry(
      originalUrl: json['originalUrl'] as String,
      mediaUrl: json['mediaUrl'] as String,
    );
  }
}
