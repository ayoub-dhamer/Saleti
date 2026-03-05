// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'khatm_screen.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class KhatmYearAdapter extends TypeAdapter<KhatmYear> {
  @override
  final int typeId = 20;

  @override
  KhatmYear read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return KhatmYear(
      year: fields[0] as int,
      targetCompletions: fields[1] as int,
      pagesPerDay: fields[2] as int,
      startDate: fields[6] as DateTime,
      pagesReadTotal: fields[3] as int,
      completedCycles: fields[4] as int,
      isActive: fields[5] as bool,
      endDate: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, KhatmYear obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.year)
      ..writeByte(1)
      ..write(obj.targetCompletions)
      ..writeByte(2)
      ..write(obj.pagesPerDay)
      ..writeByte(3)
      ..write(obj.pagesReadTotal)
      ..writeByte(4)
      ..write(obj.completedCycles)
      ..writeByte(5)
      ..write(obj.isActive)
      ..writeByte(6)
      ..write(obj.startDate)
      ..writeByte(7)
      ..write(obj.endDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KhatmYearAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DailyKhatmLogAdapter extends TypeAdapter<DailyKhatmLog> {
  @override
  final int typeId = 21;

  @override
  DailyKhatmLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyKhatmLog(
      year: fields[0] as int,
      date: fields[1] as String,
      pagesRead: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DailyKhatmLog obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.year)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.pagesRead);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyKhatmLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
