// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'surah_goals_screen.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SurahGoalAdapter extends TypeAdapter<SurahGoal> {
  @override
  final int typeId = 30;

  @override
  SurahGoal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SurahGoal(
      surahNumber: fields[0] as int,
      surahName: fields[1] as String,
      targetCount: fields[2] as int,
      completedCount: fields[3] as int,
      deadline: fields[4] as DateTime?,
      label: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SurahGoal obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.surahNumber)
      ..writeByte(1)
      ..write(obj.surahName)
      ..writeByte(2)
      ..write(obj.targetCount)
      ..writeByte(3)
      ..write(obj.completedCount)
      ..writeByte(4)
      ..write(obj.deadline)
      ..writeByte(5)
      ..write(obj.label);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SurahGoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
