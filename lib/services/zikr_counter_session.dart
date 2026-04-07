import 'package:flutter/material.dart';

class ZikrCounterSessionState {
  final int count;
  final bool isVisible;
  final Offset offset;

  const ZikrCounterSessionState({
    this.count = 0,
    this.isVisible = false,
    this.offset = const Offset(-1, -1),
  });

  ZikrCounterSessionState copyWith({
    int? count,
    bool? isVisible,
    Offset? offset,
  }) {
    return ZikrCounterSessionState(
      count: count ?? this.count,
      isVisible: isVisible ?? this.isVisible,
      offset: offset ?? this.offset,
    );
  }
}

class ZikrCounterSessionStore {
  ZikrCounterSessionStore._();

  static final ZikrCounterSessionStore instance = ZikrCounterSessionStore._();

  final Map<String, ZikrCounterSessionState> _states = {};

  ZikrCounterSessionState read(String zikrId) {
    return _states[zikrId] ?? const ZikrCounterSessionState();
  }

  void write(String zikrId, ZikrCounterSessionState state) {
    _states[zikrId] = state;
  }
}
