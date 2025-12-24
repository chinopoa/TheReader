// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manga.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MangaAdapter extends TypeAdapter<Manga> {
  @override
  final int typeId = 2;

  @override
  Manga read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Manga(
      id: fields[0] as String,
      title: fields[1] as String,
      author: fields[2] as String,
      artist: fields[3] as String,
      status: fields[4] as MangaStatus,
      synopsis: fields[5] as String,
      coverUrl: fields[6] as String?,
      source: fields[7] as MangaSource,
      genres: (fields[8] as List).cast<String>(),
      lastUpdated: fields[9] as DateTime?,
      isFollowed: fields[10] as bool,
      rating: fields[11] as double?,
      chapterIds: (fields[12] as List).cast<String>(),
      customSourceId: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Manga obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.artist)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.synopsis)
      ..writeByte(6)
      ..write(obj.coverUrl)
      ..writeByte(7)
      ..write(obj.source)
      ..writeByte(8)
      ..write(obj.genres)
      ..writeByte(9)
      ..write(obj.lastUpdated)
      ..writeByte(10)
      ..write(obj.isFollowed)
      ..writeByte(11)
      ..write(obj.rating)
      ..writeByte(12)
      ..write(obj.chapterIds)
      ..writeByte(13)
      ..write(obj.customSourceId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MangaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MangaStatusAdapter extends TypeAdapter<MangaStatus> {
  @override
  final int typeId = 0;

  @override
  MangaStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MangaStatus.ongoing;
      case 1:
        return MangaStatus.completed;
      case 2:
        return MangaStatus.hiatus;
      case 3:
        return MangaStatus.cancelled;
      default:
        return MangaStatus.ongoing;
    }
  }

  @override
  void write(BinaryWriter writer, MangaStatus obj) {
    switch (obj) {
      case MangaStatus.ongoing:
        writer.writeByte(0);
        break;
      case MangaStatus.completed:
        writer.writeByte(1);
        break;
      case MangaStatus.hiatus:
        writer.writeByte(2);
        break;
      case MangaStatus.cancelled:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MangaStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MangaSourceAdapter extends TypeAdapter<MangaSource> {
  @override
  final int typeId = 1;

  @override
  MangaSource read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MangaSource.mangadex;
      case 1:
        return MangaSource.mangakakalot;
      case 2:
        return MangaSource.webtoons;
      case 3:
        return MangaSource.asurascans;
      case 4:
        return MangaSource.custom;
      default:
        return MangaSource.mangadex;
    }
  }

  @override
  void write(BinaryWriter writer, MangaSource obj) {
    switch (obj) {
      case MangaSource.mangadex:
        writer.writeByte(0);
        break;
      case MangaSource.mangakakalot:
        writer.writeByte(1);
        break;
      case MangaSource.webtoons:
        writer.writeByte(2);
        break;
      case MangaSource.asurascans:
        writer.writeByte(3);
        break;
      case MangaSource.custom:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MangaSourceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
