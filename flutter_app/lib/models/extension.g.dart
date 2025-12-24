// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'extension.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExtensionRepoAdapter extends TypeAdapter<ExtensionRepo> {
  @override
  final int typeId = 10;

  @override
  ExtensionRepo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExtensionRepo(
      name: fields[0] as String,
      url: fields[1] as String,
      lastUpdated: fields[2] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ExtensionRepo obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.url)
      ..writeByte(2)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtensionRepoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class InstalledSourceAdapter extends TypeAdapter<InstalledSource> {
  @override
  final int typeId = 11;

  @override
  InstalledSource read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InstalledSource(
      id: fields[0] as String,
      name: fields[1] as String,
      lang: fields[2] as String,
      baseUrl: fields[3] as String,
      extensionPkg: fields[4] as String,
      enabled: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, InstalledSource obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.lang)
      ..writeByte(3)
      ..write(obj.baseUrl)
      ..writeByte(4)
      ..write(obj.extensionPkg)
      ..writeByte(5)
      ..write(obj.enabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstalledSourceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
