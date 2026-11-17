import 'package:flutter_test/flutter_test.dart';
import 'package:thread_wardrobe/wardrobe_store.dart';

void main() {
  test('wardrobe API base URL removes trailing slashes', () {
    final store = WardrobeStore(apiBaseUrl: 'https://aurashift.example.com///');

    expect(store.apiBaseUrl, 'https://aurashift.example.com');
  });
}
