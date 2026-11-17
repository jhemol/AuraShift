import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'wardrobe_models.dart';

/// A simple 3D carousel for outfit preview.
class Carousel3D extends StatefulWidget {
  final List<ClothingItem> items;
  final double height;
  final double itemWidth;
  final double perspective;
  final int initialIndex;
  final void Function(int)? onChanged;

  const Carousel3D({
    super.key,
    required this.items,
    this.height = 140,
    this.itemWidth = 90,
    this.perspective = 0.003,
    this.initialIndex = 0,
    this.onChanged,
  });

  @override
  State<Carousel3D> createState() => _Carousel3DState();
}

class _Carousel3DState extends State<Carousel3D> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onSwipe(int direction) {
    setState(() {
      _currentIndex = (_currentIndex + direction) % widget.items.length;
      if (_currentIndex < 0) _currentIndex += widget.items.length;
      widget.onChanged?.call(_currentIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null || count < 2) return;
            if (details.primaryVelocity! < 0) {
              _onSwipe(1);
            } else if (details.primaryVelocity! > 0) {
              _onSwipe(-1);
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (int i = 0; i < count; i++) _buildItem(i, count, constraints.maxWidth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index, int count, double width) {
    final double offset = (index - _currentIndex).toDouble();
    final double angle = offset * 0.35;
    final double scale = math.max(0.7, 1 - offset.abs() * 0.18);
    final double opacity = math.max(0.3, 1 - offset.abs() * 0.45);
    return IgnorePointer(
      ignoring: index != _currentIndex,
      child: AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        left: width / 2 - widget.itemWidth / 2 + offset * widget.itemWidth * 0.7,
        top: 0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: opacity,
          child: Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, widget.perspective)
              ..rotateY(angle)
              ..scale(scale),
            alignment: Alignment.center,
            child: Container(
              width: widget.itemWidth,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _image(widget.items[index]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _image(ClothingItem item) {
    final value = item.colorHex.replaceFirst('#', '');
    final fallback = Container(
      color: Color(int.tryParse(value.length == 6 ? 'FF$value' : value, radix: 16) ?? 0xFF59745C),
      child: const Center(child: Icon(Icons.checkroom_rounded, color: Colors.white)),
    );
    if (item.image.isEmpty) return fallback;
    if (item.image.startsWith('data:image/')) {
      final separator = item.image.indexOf(',');
      if (separator < 0) return fallback;
      try {
        return Image.memory(base64Decode(item.image.substring(separator + 1)), fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
      } on FormatException {
        return fallback;
      }
    }
    return Image.network(item.image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
  }
}
