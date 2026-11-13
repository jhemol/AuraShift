import 'dart:convert';

class ClothingItem {
  const ClothingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.color,
    required this.colorHex,
    required this.image,
    this.season = 'All season',
    this.brand = '',
    this.tags = const [],
    this.status = 'Clean',
    this.laundryStartedAt,
    this.laundryDurationMinutes = 45,
  });

  final String id;
  final String name;
  final String category;
  final String color;
  final String colorHex;
  final String image;
  final String season;
  final String brand;
  final List<String> tags;
  final String status;
  final String? laundryStartedAt;
  final int laundryDurationMinutes;

  ClothingItem copyWith({
    String? status,
    String? brand,
    List<String>? tags,
    String? laundryStartedAt,
    bool clearLaundryStartedAt = false,
    int? laundryDurationMinutes,
  }) =>
      ClothingItem(
        id: id,
        name: name,
        category: category,
        color: color,
        colorHex: colorHex,
        image: image,
        season: season,
        brand: brand ?? this.brand,
        tags: tags ?? this.tags,
        status: status ?? this.status,
        laundryStartedAt: clearLaundryStartedAt ? null : laundryStartedAt ?? this.laundryStartedAt,
        laundryDurationMinutes: laundryDurationMinutes ?? this.laundryDurationMinutes,
      );

  factory ClothingItem.fromJson(Map<String, dynamic> json) => ClothingItem(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Untitled piece',
        category: json['category'] as String? ?? 'Top',
        color: json['color'] as String? ?? 'custom',
        colorHex: json['colorHex'] as String? ?? '#59745C',
        image: json['image'] as String? ?? '',
        season: json['season'] as String? ?? 'All season',
        brand: json['brand'] as String? ?? '',
        tags: (json['tags'] as List<dynamic>? ?? const []).whereType<String>().toList(),
        status: json['status'] == 'Washing'
            ? 'Laundry'
            : const {'Clean', 'Worn', 'Laundry'}.contains(json['status'])
                ? json['status'] as String
                : 'Clean',
        laundryStartedAt: json['laundryStartedAt'] as String?,
        laundryDurationMinutes: (json['laundryDurationMinutes'] as num?)?.toInt() ?? 45,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'color': color,
        'colorHex': colorHex,
        'image': image,
        'season': season,
        'brand': brand,
        'tags': tags,
        'status': status,
        'laundryStartedAt': laundryStartedAt,
        'laundryDurationMinutes': laundryDurationMinutes,
      };
}

class PlannedLook {
  const PlannedLook({required this.title, required this.items, this.note = '', this.event = '', this.eventTime = ''});

  final String title;
  final List<String> items;
  final String note;
  final String event;
  final String eventTime;

  factory PlannedLook.fromJson(Map<String, dynamic> json) => PlannedLook(
        title: json['title'] as String? ?? 'A new look',
        items: (json['items'] as List<dynamic>? ?? const []).cast<String>(),
        note: json['note'] as String? ?? '',
        event: json['event'] as String? ?? '',
        eventTime: json['eventTime'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'title': title, 'items': items, 'note': note, 'event': event, 'eventTime': eventTime};
}

class WardrobeData {
  WardrobeData({
    List<ClothingItem>? items,
    Map<String, PlannedLook>? looks,
    Map<String, dynamic>? settings,
  })  : items = items ?? [],
        looks = looks ?? {},
        settings = {
          'weekStarts': 0,
          'showLookNames': true,
          'accent': 'forest',
          'city': '',
          'profileName': '',
          'stylePreference': 'Everyday',
          'colorBlindMode': 'None',
          'auraIntensity': 0.65,
          'timerMinutes': 20,
          ...?settings,
        };

  final List<ClothingItem> items;
  final Map<String, PlannedLook> looks;
  final Map<String, dynamic> settings;

  factory WardrobeData.fromJson(Map<String, dynamic> json) => WardrobeData(
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((item) => ClothingItem.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        looks: (json['looks'] as Map<String, dynamic>? ?? const {}).map(
          (key, value) => MapEntry(key, PlannedLook.fromJson(Map<String, dynamic>.from(value as Map))),
        ),
        settings: Map<String, dynamic>.from(json['settings'] as Map? ?? const {}),
      );

  Map<String, dynamic> toJson() => {
        'items': items.map((item) => item.toJson()).toList(),
        'looks': looks.map((key, look) => MapEntry(key, look.toJson())),
        'settings': settings,
      };

  String encode() => jsonEncode(toJson());

  factory WardrobeData.decode(String value) => WardrobeData.fromJson(jsonDecode(value) as Map<String, dynamic>);
}
