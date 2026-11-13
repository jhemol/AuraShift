import 'package:flutter_test/flutter_test.dart';
import 'package:thread_wardrobe/wardrobe_models.dart';

void main() {
  test('wardrobe data round-trips through the API JSON shape', () {
    final original = WardrobeData(
      items: const [
        ClothingItem(
          id: 'top-1',
          name: 'Linen shirt',
          category: 'Top',
          color: 'cream',
          colorHex: '#D9CDB8',
          image: 'https://example.test/shirt.jpg',
          brand: 'Atelier',
          tags: ['rain-ready'],
          status: 'Laundry',
          laundryStartedAt: '2026-09-30T08:00:00.000Z',
        ),
      ],
      looks: {
        '2026-09-30': const PlannedLook(
          title: 'Easy layers',
          items: ['top-1'],
          note: 'Light and easy',
          event: 'Studio meeting',
          eventTime: '09:30',
        ),
      },
    );

    final decoded = WardrobeData.decode(original.encode());
    expect(decoded.items.single.name, 'Linen shirt');
    expect(decoded.looks['2026-09-30']?.items, ['top-1']);
    expect(decoded.looks['2026-09-30']?.note, 'Light and easy');
    expect(decoded.items.single.brand, 'Atelier');
    expect(decoded.items.single.tags, ['rain-ready']);
    expect(decoded.items.single.status, 'Laundry');
    expect(decoded.looks['2026-09-30']?.event, 'Studio meeting');
    expect(decoded.looks['2026-09-30']?.eventTime, '09:30');
  });

  test('legacy wardrobe JSON receives safe defaults for AuraShift fields', () {
    final decoded = WardrobeData.decode('{"items":[{"id":"legacy","name":"Shirt","category":"Top","color":"blue","colorHex":"#6487A5","image":"","status":"Washing"}],"looks":{},"settings":{}}');
    expect(decoded.items.single.status, 'Laundry');
    expect(decoded.items.single.brand, isEmpty);
    expect(decoded.settings['colorBlindMode'], 'None');
    expect(decoded.settings['timerMinutes'], 20);
  });
}
