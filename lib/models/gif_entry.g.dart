// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gif_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GifEntryAdapter extends TypeAdapter<GifEntry> {
  @override
  final int typeId = 0;

  @override
  GifEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GifEntry(
      originalUrl: fields[0] as String,
      mediaUrl: fields[1] as String,
      localPath: fields[2] as String?,
      width: fields[3] as int?,
      height: fields[4] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, GifEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.originalUrl)
      ..writeByte(1)
      ..write(obj.mediaUrl)
      ..writeByte(2)
      ..write(obj.localPath)
      ..writeByte(3)
      ..write(obj.width)
      ..writeByte(4)
      ..write(obj.height);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GifEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
