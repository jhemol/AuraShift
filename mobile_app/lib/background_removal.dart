import 'dart:typed_data';

import 'package:image/image.dart' as img;

Uint8List removeFlatBackground(Uint8List bytes, {double tolerance = 38}) {
  final image = img.decodeImage(bytes);
  if (image == null) throw const FormatException('That photo could not be opened.');
  final scale = image.width > 900 || image.height > 900 ? 900 / (image.width > image.height ? image.width : image.height) : 1.0;
  final resized = scale < 1 ? img.copyResize(image, width: (image.width * scale).round(), height: (image.height * scale).round()) : image;
  final output = img.Image(width: resized.width, height: resized.height, numChannels: 4);
  for (var y = 0; y < resized.height; y++) {
    for (var x = 0; x < resized.width; x++) {
      final pixel = resized.getPixel(x, y);
      output.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, pixel.a);
    }
  }
  final width = output.width;
  final height = output.height;
  final corners = [output.getPixel(0, 0), output.getPixel(width - 1, 0), output.getPixel(0, height - 1), output.getPixel(width - 1, height - 1)];
  final background = [
    corners.map((pixel) => pixel.r).reduce((a, b) => a + b) / corners.length,
    corners.map((pixel) => pixel.g).reduce((a, b) => a + b) / corners.length,
    corners.map((pixel) => pixel.b).reduce((a, b) => a + b) / corners.length,
  ];
  final visited = Uint8List(width * height);
  final queue = Int32List(width * height);
  var head = 0;
  var tail = 0;
  void add(int index) {
    if (index < 0 || index >= width * height || visited[index] != 0) return;
    final pixel = output.getPixel(index % width, index ~/ width);
    final dr = pixel.r - background[0], dg = pixel.g - background[1], db = pixel.b - background[2];
    if (dr * dr + dg * dg + db * db > tolerance * tolerance) return;
    visited[index] = 1;
    queue[tail++] = index;
  }

  for (var x = 0; x < width; x++) {
    add(x);
    add((height - 1) * width + x);
  }
  for (var y = 1; y < height - 1; y++) {
    add(y * width);
    add(y * width + width - 1);
  }
  while (head < tail) {
    final index = queue[head++];
    output.setPixelRgba(index % width, index ~/ width, 0, 0, 0, 0);
    final x = index % width;
    if (x > 0) add(index - 1);
    if (x + 1 < width) add(index + 1);
    add(index - width);
    add(index + width);
  }
  return Uint8List.fromList(img.encodePng(output));
}
