import 'dart:math' as math;

import 'wardrobe_models.dart';
import 'weather_service.dart';

const wardrobeCategories = ['Top', 'Bottom', 'Dress', 'Layer', 'Shoes', 'Accessory'];
const garmentStatuses = ['Clean', 'Worn', 'Laundry'];

String? nextGarmentStatus(String status) => switch (status) {
      'Clean' => 'Worn',
      'Worn' => 'Laundry',
      'Laundry' => 'Clean',
      _ => null,
    };

int laundryMinutesLeft(ClothingItem item, DateTime now) {
  final started = DateTime.tryParse(item.laundryStartedAt ?? '');
  if (started == null) return item.laundryDurationMinutes;
  final elapsed = now.difference(started).inSeconds;
  final duration = math.max(1, item.laundryDurationMinutes) * 60;
  return math.max(0, (duration - elapsed + 59) ~/ 60).toInt();
}

class WardrobeAnalytics {
  const WardrobeAnalytics({
    required this.totalItems,
    required this.plannedLooks,
    required this.statusCounts,
    required this.categoryCounts,
  });

  final int totalItems;
  final int plannedLooks;
  final Map<String, int> statusCounts;
  final Map<String, int> categoryCounts;

  factory WardrobeAnalytics.from(WardrobeData data) {
    final statuses = {for (final status in garmentStatuses) status: 0};
    final categories = {for (final category in wardrobeCategories) category: 0};
    for (final item in data.items) {
      if (statuses.containsKey(item.status)) statuses[item.status] = statuses[item.status]! + 1;
      if (categories.containsKey(item.category)) categories[item.category] = categories[item.category]! + 1;
    }
    return WardrobeAnalytics(
      totalItems: data.items.length,
      plannedLooks: data.looks.length,
      statusCounts: statuses,
      categoryCounts: categories,
    );
  }
}

class PaletteHarmony {
  const PaletteHarmony({required this.score, required this.label});

  final int score;
  final String label;
}

PaletteHarmony coordinatePalette(Iterable<ClothingItem> items) {
  final colors = <String, List<int>>{};
  for (final item in items) {
    final name = item.color.trim().toLowerCase();
    if (name.isEmpty || colors.containsKey(name)) continue;
    colors[name] = _rgbForColor(name, item.colorHex);
  }
  if (colors.length < 2) return const PaletteHarmony(score: 100, label: 'Add a second color');

  final values = colors.values.toList();
  var totalDistance = 0.0;
  var pairs = 0;
  for (var left = 0; left < values.length; left++) {
    for (var right = left + 1; right < values.length; right++) {
      final distance = math.sqrt(List.generate(3, (index) {
        final difference = values[left][index] - values[right][index];
        return difference * difference;
      }).reduce((sum, value) => sum + value));
      totalDistance += distance;
      pairs++;
    }
  }
  final averageDistance = totalDistance / pairs;
  return PaletteHarmony(
    score: (100 - averageDistance / 4.42).round().clamp(0, 100).toInt(),
    label: averageDistance > 270 ? 'High contrast' : 'In harmony',
  );
}

List<int> _rgbForColor(String color, String fallbackHex) {
  const namedColors = {
    'black': '#252525',
    'white': '#F4F1E9',
    'cream': '#E8DFCE',
    'navy': '#27374D',
    'blue': '#6487A5',
    'denim': '#53718C',
    'red': '#B94D43',
    'burgundy': '#713A49',
    'green': '#6F8069',
    'olive': '#858252',
    'yellow': '#D3AA57',
    'pink': '#D49A9D',
    'brown': '#84634E',
    'gray': '#969995',
  };
  final hex = (namedColors[color] ?? fallbackHex).replaceFirst('#', '');
  if (!RegExp(r'^[\da-fA-F]{6}$').hasMatch(hex)) return const [89, 116, 92];
  return [
    int.parse(hex.substring(0, 2), radix: 16),
    int.parse(hex.substring(2, 4), radix: 16),
    int.parse(hex.substring(4, 6), radix: 16),
  ];
}

class OutfitSuggestion {
  const OutfitSuggestion({required this.id, required this.title, required this.items, required this.note});

  final String id;
  final String title;
  final List<String> items;
  final String note;
}

List<OutfitSuggestion> suggestOutfits(List<ClothingItem> items, String occasion) {
  final available = items.where((item) => item.status == 'Clean').toList();
  final tops = available.where((item) => item.category == 'Top').toList();
  final bottoms = available.where((item) => item.category == 'Bottom').toList();
  final layers = available.where((item) => item.category == 'Layer').toList();
  final shoes = available.where((item) => item.category == 'Shoes').toList();
  final dresses = available.where((item) => item.category == 'Dress').toList();
  const titles = {
    'Casual': ['Easy casual layers', 'Off-duty favorite'],
    'Semi-casual': ['Relaxed polish', 'A little more put-together'],
    'Work': ['A considered workday', 'Ready for the office'],
    'Everyday': ['An easy everyday uniform', 'A familiar favorite'],
  };
  final options = titles[occasion] ?? titles['Everyday']!;
  final suggestions = <OutfitSuggestion>[];

  for (var index = 0; index < dresses.length; index++) {
    final dress = dresses[index];
    final shoe = shoes.isEmpty ? null : shoes[index % shoes.length];
    suggestions.add(OutfitSuggestion(
      id: 'dress-${dress.id}',
      title: '${options[index % options.length]} in one piece',
      items: [dress.id, if (shoe != null) shoe.id],
      note: '$occasion styling built around your ${dress.color} dress.',
    ));
  }
  for (var index = 0; index < tops.length && bottoms.isNotEmpty; index++) {
    final top = tops[index];
    final bottom = bottoms[index % bottoms.length];
    final layer = layers.isNotEmpty && occasion != 'Casual' ? layers[index % layers.length] : null;
    final shoe = shoes.isEmpty ? null : shoes[index % shoes.length];
    suggestions.add(OutfitSuggestion(
      id: 'pair-${top.id}-${bottom.id}',
      title: options[index % options.length],
      items: [top.id, bottom.id, if (layer != null) layer.id, if (shoe != null) shoe.id],
      note: '$occasion styling with your ${top.color} top and ${bottom.color} bottoms.',
    ));
  }
  return suggestions.take(6).toList();
}

class WeatherAdvice {
  const WeatherAdvice({required this.title, required this.detail, required this.items, required this.matched});

  final String title;
  final String detail;
  final List<ClothingItem> items;
  final bool matched;
}

WeatherAdvice getWeatherSuggestions(List<ClothingItem> items, WeatherSnapshot? weather, {int limit = 4}) {
  final cleanItems = items.where((item) => item.status == 'Clean').toList();
  if (weather == null) {
    return WeatherAdvice(
      title: 'Weather-based suggestions',
      detail: 'Add your city in Settings to get picks for local conditions.',
      items: cleanItems.take(limit).toList(),
      matched: false,
    );
  }

  final description = weather.description.toLowerCase();
  final isRainy = weather.precipitation > 0 || RegExp(r'rain|shower|storm|snow').hasMatch(description);
  final isCold = !isRainy && weather.temperature <= 12;
  final isHot = !isRainy && !isCold && weather.temperature >= 28;
  final title = isRainy ? 'Rain-ready picks' : isCold ? 'Warm layers' : isHot ? 'Light and breathable' : 'Comfortable-weather picks';
  final detail = isRainy
      ? 'Rain is expected. Prioritize waterproof or quick-dry pieces.'
      : isCold
          ? 'It is chilly. Look for warm, cozy, or insulating pieces.'
          : isHot
              ? 'It is warm. Choose breathable fabrics and lighter layers.'
              : 'Conditions are mild in ${weather.city}. Choose any clean pieces you love.';
  if (!isRainy && !isCold && !isHot) {
    return WeatherAdvice(title: title, detail: detail, items: cleanItems.take(limit).toList(), matched: false);
  }

  final tagPattern = isRainy
      ? RegExp(r'rain|waterproof|water-resistant|water resistant|quick-dry|umbrella', caseSensitive: false)
      : isCold
          ? RegExp(r'warm|wool|thermal|knit|coat|jacket|sweater|fleece', caseSensitive: false)
          : RegExp(r'breathable|lightweight|linen|cotton|summer|sleeveless|sun', caseSensitive: false);
  final categories = isRainy
      ? const {'Layer', 'Shoes'}
      : isCold
          ? const {'Layer'}
          : const {'Top', 'Dress', 'Shoes', 'Accessory'};
  final ranked = cleanItems.indexed.map((entry) {
    final tagsMatch = entry.$2.tags.any(tagPattern.hasMatch);
    final categoryMatch = categories.contains(entry.$2.category);
    return (item: entry.$2, index: entry.$1, score: (tagsMatch ? 3 : 0) + (categoryMatch ? 1 : 0), tagsMatch: tagsMatch);
  }).toList()
    ..sort((left, right) {
      final scoreOrder = right.score.compareTo(left.score);
      return scoreOrder == 0 ? left.index.compareTo(right.index) : scoreOrder;
    });
  final matched = ranked.any((entry) => entry.tagsMatch);
  return WeatherAdvice(
    title: title,
    detail: matched ? detail : '$detail Showing clean items; tag weather-ready pieces for more tailored picks.',
    items: ranked.take(limit).map((entry) => entry.item).toList(),
    matched: matched,
  );
}

List<ClothingItem> filterClosetItems(
  List<ClothingItem> items, {
  String category = 'All',
  String query = '',
  bool rainReadyOnly = false,
  String sort = 'recent',
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final filtered = items.where((item) {
    if (category != 'All' && item.category != category) return false;
    if (rainReadyOnly && !item.tags.any((tag) => RegExp(r'rain|waterproof', caseSensitive: false).hasMatch(tag))) return false;
    if (normalizedQuery.isEmpty) return true;
    return [item.name, item.brand, item.color, ...item.tags].any((value) => value.toLowerCase().contains(normalizedQuery));
  }).toList();
  int compare(String first, String second) => first.toLowerCase().compareTo(second.toLowerCase());
  if (sort == 'name') filtered.sort((a, b) => compare(a.name, b.name));
  if (sort == 'category') filtered.sort((a, b) {
    final order = compare(a.category, b.category);
    return order == 0 ? compare(a.name, b.name) : order;
  });
  if (sort == 'color') filtered.sort((a, b) {
    final order = compare(a.color, b.color);
    return order == 0 ? compare(a.name, b.name) : order;
  });
  if (sort == 'status') filtered.sort((a, b) {
    final order = compare(a.status, b.status);
    return order == 0 ? compare(a.name, b.name) : order;
  });
  return filtered;
}

String buildWardrobeReportCsv(WardrobeData data, WeatherSnapshot? weather, {DateTime? generatedAt}) {
  String cell(Object? value) => '"${(value ?? '').toString().replaceAll('"', '""')}"';
  final analytics = WardrobeAnalytics.from(data);
  final rows = <List<Object?>>[
    ['Section', 'Metric', 'Value', 'Details'],
    ['Summary', 'Generated', (generatedAt ?? DateTime.now()).toUtc().toIso8601String(), ''],
    ['Summary', 'Wardrobe pieces', analytics.totalItems, ''],
    ['Summary', 'Planned looks', analytics.plannedLooks, ''],
    ...garmentStatuses.map((status) => ['Status', status, analytics.statusCounts[status], '']),
    ...wardrobeCategories.map((category) => ['Category', category, analytics.categoryCounts[category], '']),
    ['Weather', 'City', weather?.city ?? '', ''],
    ['Weather', 'Conditions', weather?.description ?? '', ''],
    ['Weather', 'Temperature (°C)', weather?.temperature ?? '', ''],
    ['Weather', 'Precipitation (mm)', weather?.precipitation ?? '', ''],
    ...data.items.map((item) => [
          'Item',
          item.name,
          item.status,
          [item.category, item.color, item.season, ...item.tags].where((value) => value.isNotEmpty).join('; '),
        ]),
  ];
  return rows.map((row) => row.map(cell).join(',')).join('\r\n');
}

const dailyApproaches = [
  ('Ease into the week', 'Reach for a familiar favorite and let it set the tone.'),
  ('Stay in one color family', 'Try nearby shades for a quiet, considered palette.'),
  ('Make one small contrast', 'Let one unexpected color do the talking.'),
  ('Dress by texture', 'Pair smooth, soft, and structured pieces.'),
  ('Take a favorite further', 'Rework a piece you already love in a new way.'),
  ('Add a playful detail', 'Choose one accessory that feels a little unlike you.'),
  ('Choose room to breathe', 'Keep it simple, comfortable, and entirely your own.'),
];
