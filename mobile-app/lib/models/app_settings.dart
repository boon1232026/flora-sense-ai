class AppSettings {
  const AppSettings({
    required this.notifyApp,
    required this.notifyEmail,
    required this.notifyLine,
    required this.pumpEnabled,
    required this.autoIrrigation,
    required this.language,
    required this.displayMode,
    required this.autoStartMoisture,
    required this.autoStopMoisture,
    required this.autoRunSeconds,
    required this.highRiskScore,
  });

  final bool notifyApp;
  final bool notifyEmail;
  final bool notifyLine;
  final bool pumpEnabled;
  final bool autoIrrigation;
  final String language;
  final String displayMode;
  final double autoStartMoisture;
  final double autoStopMoisture;
  final double autoRunSeconds;
  final double highRiskScore;

  Map<String, dynamic> toJson() => {
        'notifyApp': notifyApp,
        'notifyEmail': notifyEmail,
        'notifyLine': notifyLine,
        'pumpEnabled': pumpEnabled,
        'autoIrrigation': autoIrrigation,
        'language': language,
        'displayMode': displayMode,
        'autoStartMoisture': autoStartMoisture,
        'autoStopMoisture': autoStopMoisture,
        'autoRunSeconds': autoRunSeconds,
        'highRiskScore': highRiskScore,
      };

  AppSettings copyWith({
    bool? notifyApp,
    bool? notifyEmail,
    bool? notifyLine,
    bool? pumpEnabled,
    bool? autoIrrigation,
    String? language,
    String? displayMode,
    double? autoStartMoisture,
    double? autoStopMoisture,
    double? autoRunSeconds,
    double? highRiskScore,
  }) {
    return AppSettings(
      notifyApp: notifyApp ?? this.notifyApp,
      notifyEmail: notifyEmail ?? this.notifyEmail,
      notifyLine: notifyLine ?? this.notifyLine,
      pumpEnabled: pumpEnabled ?? this.pumpEnabled,
      autoIrrigation: autoIrrigation ?? this.autoIrrigation,
      language: language ?? this.language,
      displayMode: displayMode ?? this.displayMode,
      autoStartMoisture: autoStartMoisture ?? this.autoStartMoisture,
      autoStopMoisture: autoStopMoisture ?? this.autoStopMoisture,
      autoRunSeconds: autoRunSeconds ?? this.autoRunSeconds,
      highRiskScore: highRiskScore ?? this.highRiskScore,
    );
  }
}
