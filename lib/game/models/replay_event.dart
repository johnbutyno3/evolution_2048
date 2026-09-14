class ReplayEvent {
  ReplayEvent._(this.type, this.data);

  final String type;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        ...data,
      };

  static ReplayEvent move({
    required String direction,
    required int spawnIndex,
    required int spawnValue,
  }) {
    return ReplayEvent._('move', <String, dynamic>{
      'direction': direction,
      'spawnIndex': spawnIndex,
      'spawnValue': spawnValue,
    });
  }

  static ReplayEvent revive({
    required int index,
    int? spawnIndex,
    int? spawnValue,
  }) {
    return ReplayEvent._('revive', <String, dynamic>{
      'index': index,
      ..._optionalField('spawnIndex', spawnIndex),
      ..._optionalField('spawnValue', spawnValue),
    });
  }

  static Map<String, dynamic> _optionalField(String key, int? value) {
    return value == null ? <String, dynamic>{} : <String, dynamic>{key: value};
  }

  static ReplayEvent positionSwap({
    required int firstIndex,
    required int secondIndex,
  }) {
    return ReplayEvent._('positionSwap', <String, dynamic>{
      'firstIndex': firstIndex,
      'secondIndex': secondIndex,
    });
  }

  static ReplayEvent duplicate({
    required int sourceIndex,
    required int targetIndex,
  }) {
    return ReplayEvent._('duplicate', <String, dynamic>{
      'sourceIndex': sourceIndex,
      'targetIndex': targetIndex,
    });
  }

  static ReplayEvent timeRewind() {
    return ReplayEvent._('timeRewind', <String, dynamic>{});
  }

  static ReplayEvent fromJson(dynamic raw) {
    if (raw is! Map) {
      throw const FormatException('Invalid replay event.');
    }

    final type = raw['type'];
    if (type is! String || type.isEmpty) {
      throw const FormatException('Invalid replay event type.');
    }

    final data = <String, dynamic>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      if (key != 'type') {
        data[key] = entry.value;
      }
    }

    return ReplayEvent._(type, data);
  }
}
