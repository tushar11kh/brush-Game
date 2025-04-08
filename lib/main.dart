import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Offset _brushPosition = Offset.zero;
  List<Offset> _erasedPoints = [];
  ui.Image? _sketchImage;
  Rect? _imageRect;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _loadSketchImage();
  }

  Future<void> _loadSketchImage() async {
    final data = await rootBundle.load('assets/sketch.jpg');
    final bytes = data.buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    setState(() {
      _sketchImage = frame.image;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white, // White background for padding areas
        body: Padding(
          padding: const EdgeInsets.all(20.0), // White padding around content
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate the image rect once when the sketch image is loaded
              if (_sketchImage != null && (_imageRect == null || _isFirstLoad)) {
                final imageWidth = _sketchImage!.width.toDouble();
                final imageHeight = _sketchImage!.height.toDouble();
                final availableWidth = constraints.maxWidth;
                final availableHeight = constraints.maxHeight;
                
                // Calculate aspect ratios
                final imageAspect = imageWidth / imageHeight;
                final screenAspect = availableWidth / availableHeight;
                
                // Calculate the rect that maintains aspect ratio while fitting the available space
                if (screenAspect > imageAspect) {
                  // Available space is wider than image - fit to height
                  final width = imageAspect * availableHeight;
                  _imageRect = Rect.fromLTWH(
                    (availableWidth - width) / 2,
                    0,
                    width,
                    availableHeight,
                  );
                } else {
                  // Available space is taller than image - fit to width
                  final height = availableWidth / imageAspect;
                  _imageRect = Rect.fromLTWH(
                    0,
                    (availableHeight - height) / 2,
                    availableWidth,
                    height,
                  );
                }
                
                if (_isFirstLoad) {
                  // Initialize brush position to center of the image
                  _brushPosition = _imageRect!.center;
                  _isFirstLoad = false;
                }
              }

              return GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _brushPosition = details.localPosition;
                    if (_imageRect != null && _imageRect!.contains(details.localPosition)) {
                      _erasedPoints.add(details.localPosition - Offset(_imageRect!.left, _imageRect!.top));
                    }
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _brushPosition = details.localPosition;
                    if (_imageRect != null && _imageRect!.contains(details.localPosition)) {
                      _erasedPoints.add(details.localPosition - Offset(_imageRect!.left, _imageRect!.top));
                    }
                  });
                },
                child: Stack(
                  children: [
                    // Background colored image
                    if (_imageRect != null)
                      Positioned.fromRect(
                        rect: _imageRect!,
                        child: Image.asset(
                          'assets/colored.jpeg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    // Sketch layer with eraser effect applied
                    if (_sketchImage != null && _imageRect != null)
                      Positioned.fromRect(
                        rect: _imageRect!,
                        child: CustomPaint(
                          painter: SketchEraserPainter(
                            sketchImage: _sketchImage!,
                            erasedPoints: _erasedPoints,
                          ),
                        ),
                      ),
                    // Brush Icon (always follows touch)
                    Positioned(
                      left: _brushPosition.dx - (MediaQuery.of(context).size.width * 0.40) / 2,
                      top: _brushPosition.dy - (MediaQuery.of(context).size.height * 0.40) / 2,
                      child: IgnorePointer(
                        child: Image.asset(
                          'assets/brush_icon.png',
                          width: MediaQuery.of(context).size.width * 0.40,
                          height: MediaQuery.of(context).size.height * 0.40,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class SketchEraserPainter extends CustomPainter {
  final ui.Image sketchImage;
  final List<Offset> erasedPoints;

  SketchEraserPainter({
    required this.sketchImage,
    required this.erasedPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the sketch image scaled to the available size.
    final src = Rect.fromLTWH(
      0,
      0,
      sketchImage.width.toDouble(),
      sketchImage.height.toDouble(),
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);

    // Create a new layer so that we can clear parts of the sketch image.
    canvas.saveLayer(dst, Paint());
    canvas.drawImageRect(sketchImage, src, dst, Paint());

    // Eraser paint using dstOut blend mode to clear portions of the sketch.
    final eraser = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.fill;

    // Draw circles at each erased point.
    for (final point in erasedPoints) {
      canvas.drawCircle(point, size.width * 0.05, eraser);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SketchEraserPainter oldDelegate) {
    return oldDelegate.erasedPoints != erasedPoints ||
        oldDelegate.sketchImage != sketchImage;
  }
}