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
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! < 0) {
            _onSwipe(1);
          } else if (details.primaryVelocity! > 0) {
            _onSwipe(-1);
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (int i = 0; i < count; i++)
              _buildItem(i, count),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(int index, int count) {
    final double offset = index - _currentIndex;
    final double angle = offset * 0.35;
    final double scale = math.max(0.7, 1 - offset.abs() * 0.18);
    final double opacity = math.max(0.3, 1 - offset.abs() * 0.45);
    return IgnorePointer(
      ignoring: index != _currentIndex,
      child: AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        left: MediaQuery.of(context).size.width / 2 - widget.itemWidth / 2 + offset * widget.itemWidth * 0.7,
        top: 0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: opacity,
          child: Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, widget.perspective)
              ..rotateY(angle),
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
                child: widget.items[index].image.isNotEmpty
                    ? Image.network(widget.items[index].image, fit: BoxFit.cover)
                    : Container(color: Color(int.parse(widget.items[index].colorHex.replaceFirst('#', '0xff')))),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
