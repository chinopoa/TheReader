// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HistoryItemAdapter extends TypeAdapter<HistoryItem> {
  @override
  final int typeId = 4;

  @override
  HistoryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HistoryItem(
      id: fields[0] as String,
      mangaId: fields[1] as String,
      mangaTitle: fields[2] as String,
      mangaCoverUrl: fields[3] as String?,
      chapterId: fields[4] as String,
      chapterNumber: fields[5] as double,
      chapterTitle: fields[6] as String,
      lastReadPage: fields[7] as int,
      totalPages: fields[8] as int,
      lastReadDate: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, HistoryItem obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.mangaId)
      ..writeByte(2)
      ..write(obj.mangaTitle)
      ..writeByte(3)
      ..write(obj.mangaCoverUrl)
      ..writeByte(4)
      ..write(obj.chapterId)
      ..writeByte(5)
      ..write(obj.chapterNumber)
      ..writeByte(6)
      ..write(obj.chapterTitle)
      ..writeByte(7)
      ..write(obj.lastReadPage)
      ..writeByte(8)
      ..write(obj.totalPages)
      ..writeByte(9)
      ..write(obj.lastReadDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
