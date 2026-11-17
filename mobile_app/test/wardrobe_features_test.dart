import 'package:flutter_test/flutter_test.dart';
import 'package:thread_wardrobe/wardrobe_features.dart';
import 'package:thread_wardrobe/wardrobe_models.dart';
import 'package:thread_wardrobe/weather_service.dart';

ClothingItem _item({
  required String id,
  required String name,
  required String category,
  String color = 'cream',
  String status = 'Clean',
  List<String> tags = const [],
  String? laundryStartedAt,
}) =>
    ClothingItem(
      id: id,
      name: name,
      category: category,
      color: color,
      colorHex: '#D9CDB8',
      image: '',
      status: status,
      tags: tags,
      laundryStartedAt: laundryStartedAt,
    );

void main() {
  test('garment care advances through the web workflow and estimates remaining time', () {
    final item = _item(
      id: 'top',
      name: 'Linen top',
      category: 'Top',
      status: 'Laundry',
      laundryStartedAt: '2026-11-17T10:00:00.000Z',
    );

    expect(nextGarmentStatus('Clean'), 'Worn');
    expect(nextGarmentStatus('Worn'), 'Laundry');
    expect(nextGarmentStatus('Laundry'), 'Clean');
    expect(laundryMinutesLeft(item, DateTime.parse('2026-11-17T10:20:00.000Z')), 25);
    expect(laundryMinutesLeft(item, DateTime.parse('2026-11-17T11:00:00.000Z')), 0);
  });

  test('style suggestions only use clean pieces and adapt to the selected occasion', () {
    final items = [
      _item(id: 'top', name: 'Top', category: 'Top'),
      _item(id: 'bottom', name: 'Bottom', category: 'Bottom'),
      _item(id: 'layer', name: 'Layer', category: 'Layer'),
      _item(id: 'shoe', name: 'Shoes', category: 'Shoes'),
      _item(id: 'worn', name: 'Worn top', category: 'Top', status: 'Worn'),
    ];

    final idea = suggestOutfits(items, 'Work').single;
    expect(idea.items, ['top', 'bottom', 'layer', 'shoe']);
    expect(idea.title, 'A considered workday');
  });

  test('weather suggestions prioritize matching clean pieces', () {
    final items = [
      _item(id: 'tee', name: 'Tee', category: 'Top'),
      _item(id: 'raincoat', name: 'Raincoat', category: 'Layer', tags: ['waterproof']),
      _item(id: 'wet-shoes', name: 'Wet shoes', category: 'Shoes', status: 'Worn'),
    ];

    final advice = getWeatherSuggestions(
      items,
      const WeatherSnapshot(city: 'Manila', temperature: 25, precipitation: 3, description: 'Rain'),
    );

    expect(advice.title, 'Rain-ready picks');
    expect(advice.items.map((item) => item.id).toList(), ['raincoat', 'tee']);
    expect(advice.matched, isTrue);
  });

  test('closet filters by category, metadata, rain tags, and supported sort orders', () {
    final items = [
      _item(id: 'shirt-b', name: 'Bravo shirt', category: 'Top', tags: ['rain-ready']),
      _item(id: 'shirt-a', name: 'Alpha shirt', category: 'Top', status: 'Worn'),
      _item(id: 'pants', name: 'Linen pants', category: 'Bottom'),
    ];

    expect(filterClosetItems(items, category: 'Top', query: 'alpha').single.id, 'shirt-a');
    expect(filterClosetItems(items, rainReadyOnly: true).map((item) => item.id), ['shirt-b']);
    expect(filterClosetItems(items, sort: 'name').map((item) => item.id), ['shirt-a', 'shirt-b', 'pants']);
  });

  test('wardrobe analytics and CSV contain shared care, category, look, and weather data', () {
    final data = WardrobeData(
      items: [
        _item(id: 'top', name: 'Top, "special"', category: 'Top', status: 'Laundry'),
      ],
      looks: {'2026-11-17': const PlannedLook(title: 'Easy layers', items: ['top'])},
    );
    const weather = WeatherSnapshot(city: 'Manila', temperature: 30, precipitation: 0, description: 'Clear skies');

    final analytics = WardrobeAnalytics.from(data);
    final report = buildWardrobeReportCsv(data, weather, generatedAt: DateTime.utc(2026, 11, 17));

    expect(analytics.totalItems, 1);
    expect(analytics.statusCounts['Laundry'], 1);
    expect(analytics.categoryCounts['Top'], 1);
    expect(analytics.plannedLooks, 1);
    expect(report, contains('"Item","Top, ""special""","Laundry","Top; cream; All season"'));
    expect(report, contains('"Weather","City","Manila",""'));
  });
}
