import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class EasterEggBackground extends StatefulWidget {
  final Widget child;
  final Color color;

  const EasterEggBackground({
    super.key,
    required this.child,
    this.color = Colors.deepPurple,
  });

  @override
  State<EasterEggBackground> createState() => _EasterEggBackgroundState();
}

class _EasterEggBackgroundState extends State<EasterEggBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  ui.Image? _logoImage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _loadLogoImage();
  }

  Future<void> _loadLogoImage() async {
    final imageProvider = const AssetImage('assets/images/logo.png');
    final imageStream = imageProvider.resolve(const ImageConfiguration());
    imageStream.addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _logoImage = info.image;
          });
        }
      }),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated diagonal grid of logos
        if (_logoImage != null)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: DiagonalLogoGridPainter(
                  color: widget.color,
                  animationValue: _controller.value,
                  logoImage: _logoImage!,
                ),
                child: Container(),
              );
            },
          ),
        // Actual content
        widget.child,
      ],
    );
  }
}

class DiagonalLogoGridPainter extends CustomPainter {
  final Color color;
  final double animationValue;
  final ui.Image logoImage;

  DiagonalLogoGridPainter({
    required this.color,
    required this.animationValue,
    required this.logoImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.015);

    final logoSize = 100.0;
    final spacing = 150.0; // Distance between logos

    // Calculate diagonal offset (moving towards bottom-right)
    final totalDistance = spacing * 1.5;
    final offsetX = (animationValue * totalDistance) % spacing;
    final offsetY = (animationValue * totalDistance) % spacing;

    // Calculate how many logos we need to cover the screen diagonally
    final numCols = (size.width / spacing).ceil() + 2;
    final numRows = (size.height / spacing).ceil() + 2;

    // Draw logos in a diagonal grid pattern
    for (int row = -1; row < numRows; row++) {
      for (int col = -1; col < numCols; col++) {
        // Position logos diagonally
        final x = col * spacing + offsetX - spacing;
        final y = row * spacing + offsetY - spacing;

        final srcRect = Rect.fromLTWH(
          0,
          0,
          logoImage.width.toDouble(),
          logoImage.height.toDouble(),
        );

        final dstRect = Rect.fromLTWH(
          x,
          y,
          logoSize,
          logoSize,
        );

        // Save canvas state
        canvas.saveLayer(dstRect, paint);

        // Draw the logo
        canvas.drawImageRect(
          logoImage,
          srcRect,
          dstRect,
          Paint(),
        );

        // Restore canvas (applies the alpha)
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(DiagonalLogoGridPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color ||
        oldDelegate.logoImage != logoImage;
  }
}
