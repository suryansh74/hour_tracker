class TrackCategory {
  final int? id;
  final String name;
  final int colorValue; // ARGB int, e.g. 0xFF2196F3

  TrackCategory({
    this.id,
    required this.name,
    required this.colorValue,
  });

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'color': colorValue,
    };
  }

  factory TrackCategory.fromMap(Map<String, Object?> map) {
    return TrackCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      colorValue: map['color'] as int,
    );
  }

  TrackCategory copyWith({int? id, String? name, int? colorValue}) {
    return TrackCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}

// Expanded starting palette + default categories so the app isn't empty
// on first launch. Users can also pick a fully custom color.
const List<int> kCategoryPalette = [
  0xFF3B82F6, // blue
  0xFF10B981, // green
  0xFFF59E0B, // amber
  0xFFEF4444, // red
  0xFF8B5CF6, // violet
  0xFFEC4899, // pink
  0xFF14B8A6, // teal
  0xFF6B7280, // gray
  0xFF0EA5E9, // sky
  0xFF22C55E, // lime-green
  0xFFF97316, // orange
  0xFFA855F7, // purple
  0xFF06B6D4, // cyan
  0xFFE11D48, // rose
  0xFF84CC16, // lime
  0xFF64748B, // slate
  0xFFD946EF, // fuchsia
  0xFF78716C, // stone
  0xFF4F46E5, // indigo
  0xFFCA8A04, // yellow
];

List<TrackCategory> defaultCategories() => [
      TrackCategory(name: 'Deep Work', colorValue: kCategoryPalette[0]),
      TrackCategory(name: 'Study', colorValue: kCategoryPalette[1]),
      TrackCategory(name: 'Exercise', colorValue: kCategoryPalette[2]),
      TrackCategory(name: 'Chores', colorValue: kCategoryPalette[6]),
      TrackCategory(name: 'Leisure', colorValue: kCategoryPalette[4]),
      TrackCategory(name: 'Distracted', colorValue: kCategoryPalette[3]),
    ];
