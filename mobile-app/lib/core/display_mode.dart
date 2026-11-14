import 'package:flutter/material.dart';

final ValueNotifier<ThemeMode> floraDisplayMode = ValueNotifier(ThemeMode.light);

void applyDisplayMode(String mode) {
  floraDisplayMode.value = switch (mode) {
    'โหมดมืด' => ThemeMode.dark,
    'ตามระบบ' => ThemeMode.system,
    _ => ThemeMode.light,
  };
}
