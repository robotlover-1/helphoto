class EditParams {
  static const List<String> paramNames = [
    'exposure',
    'contrast',
    'temperature',
    'tint',
    'saturation',
    'vibrance',
    'highlights',
    'shadows',
  ];

  static const int minValue = -100;
  static const int maxValue = 100;

  final int exposure;
  final int contrast;
  final int temperature;
  final int tint;
  final int saturation;
  final int vibrance;
  final int highlights;
  final int shadows;

  const EditParams({
    this.exposure = 0,
    this.contrast = 0,
    this.temperature = 0,
    this.tint = 0,
    this.saturation = 0,
    this.vibrance = 0,
    this.highlights = 0,
    this.shadows = 0,
  });

  static const EditParams zero = EditParams();

  EditParams copyWith({
    int? exposure,
    int? contrast,
    int? temperature,
    int? tint,
    int? saturation,
    int? vibrance,
    int? highlights,
    int? shadows,
  }) {
    return EditParams(
      exposure: exposure ?? this.exposure,
      contrast: contrast ?? this.contrast,
      temperature: temperature ?? this.temperature,
      tint: tint ?? this.tint,
      saturation: saturation ?? this.saturation,
      vibrance: vibrance ?? this.vibrance,
      highlights: highlights ?? this.highlights,
      shadows: shadows ?? this.shadows,
    );
  }

  Map<String, int> toJson() => {
        'exposure': exposure,
        'contrast': contrast,
        'temperature': temperature,
        'tint': tint,
        'saturation': saturation,
        'vibrance': vibrance,
        'highlights': highlights,
        'shadows': shadows,
      };

  factory EditParams.fromJson(Map<String, dynamic> json) {
    int read(String key) {
      final v = json[key];
      if (v is num) return v.toInt().clamp(minValue, maxValue);
      return 0;
    }

    return EditParams(
      exposure: read('exposure'),
      contrast: read('contrast'),
      temperature: read('temperature'),
      tint: read('tint'),
      saturation: read('saturation'),
      vibrance: read('vibrance'),
      highlights: read('highlights'),
      shadows: read('shadows'),
    );
  }

  int operator [](String name) => switch (name) {
        'exposure' => exposure,
        'contrast' => contrast,
        'temperature' => temperature,
        'tint' => tint,
        'saturation' => saturation,
        'vibrance' => vibrance,
        'highlights' => highlights,
        'shadows' => shadows,
        _ => throw ArgumentError('unknown param: $name'),
      };
}
