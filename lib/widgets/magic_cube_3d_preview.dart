import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../magic_manager.dart';

/// 3D Preview service for magic cube visualization
class MagicCube3DPreview extends StatefulWidget {
  final String projectPath;
  final String templatePath;
  final double width;
  final double height;

  const MagicCube3DPreview({
    super.key,
    required this.projectPath,
    required this.templatePath,
    this.width = 300,
    this.height = 300,
  });

  @override
  State<MagicCube3DPreview> createState() => _MagicCube3DPreviewState();
}

class _MagicCube3DPreviewState extends State<MagicCube3DPreview>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  List<ui.Image> _sliceImages = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _scaleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _loadSliceImages();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _loadSliceImages() async {
    try {
      setState(() => _isLoading = true);

      final images = <ui.Image>[];

      // Load first few slices from the project for preview
      // We'll sample from different sources to show variety
      for (int sourceId = 1; sourceId <= 4; sourceId++) {
        for (int sliceId = 1; sliceId <= 3; sliceId++) {
          try {
            final sliceImage = await MagicManager.instance.loadSlice(
              widget.projectPath,
              sourceId,
              sliceId,
            );
            if (sliceImage != null) {
              images.add(sliceImage);
              if (images.length >= 8) break; // Limit for performance
            }
          } catch (e) {
            // Slice doesn't exist, continue
          }
        }
        if (images.length >= 8) break;
      }

      if (images.isEmpty) {
        setState(() {
          _error = 'No processed slices found for preview';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _sliceImages = images;
        _isLoading = false;
      });

      // Start scale animation
      _scaleController.forward();
    } catch (e) {
      setState(() {
        _error = 'Error loading preview: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading 3D preview...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadSliceImages,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        // Toggle rotation speed on tap
        if (_rotationController.isAnimating) {
          _rotationController.stop();
        } else {
          _rotationController.repeat();
        }
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: RadialGradient(
            colors: [
              Colors.blue.shade100,
              Colors.blue.shade300,
            ],
          ),
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([_rotationController, _scaleController]),
          builder: (context, child) {
            return CustomPaint(
              painter: MagicCube3DPainter(
                sliceImages: _sliceImages,
                rotationX: _rotationController.value * 2 * math.pi,
                rotationY: _rotationController.value * 2 * math.pi * 0.7,
                scale: _scaleController.value,
              ),
              child: Container(),
            );
          },
        ),
      ),
    );
  }
}

/// Custom painter for 3D magic cube visualization
class MagicCube3DPainter extends CustomPainter {
  final List<ui.Image> sliceImages;
  final double rotationX;
  final double rotationY;
  final double scale;

  MagicCube3DPainter({
    required this.sliceImages,
    required this.rotationX,
    required this.rotationY,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (sliceImages.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.translate(center.dx, center.dy);

    // Apply scale animation
    canvas.scale(0.3 + scale * 0.7);

    _drawMagicCube(canvas, size);
  }

  void _drawMagicCube(Canvas canvas, Size size) {
    // Define cube vertices in 3D space
    final cubeSize = 100.0;
    final vertices = [
      Vector3(-cubeSize, -cubeSize, -cubeSize), // 0: back-bottom-left
      Vector3(cubeSize, -cubeSize, -cubeSize), // 1: back-bottom-right
      Vector3(cubeSize, cubeSize, -cubeSize), // 2: back-top-right
      Vector3(-cubeSize, cubeSize, -cubeSize), // 3: back-top-left
      Vector3(-cubeSize, -cubeSize, cubeSize), // 4: front-bottom-left
      Vector3(cubeSize, -cubeSize, cubeSize), // 5: front-bottom-right
      Vector3(cubeSize, cubeSize, cubeSize), // 6: front-top-right
      Vector3(-cubeSize, cubeSize, cubeSize), // 7: front-top-left
    ];

    // Apply rotation to vertices
    final rotatedVertices =
        vertices.map((v) => _rotateVertex(v, rotationX, rotationY)).toList();

    // Project 3D vertices to 2D screen coordinates
    final projectedVertices =
        rotatedVertices.map((v) => _projectVertex(v)).toList();

    // Define cube faces (indices into vertex array)
    final faces = [
      [0, 1, 2, 3], // back face
      [4, 7, 6, 5], // front face
      [0, 4, 5, 1], // bottom face
      [2, 6, 7, 3], // top face
      [0, 3, 7, 4], // left face
      [1, 5, 6, 2], // right face
    ];

    // Sort faces by depth (z-coordinate) for proper rendering order
    final faceDepths = faces.asMap().entries.map((entry) {
      final faceVertices = entry.value;
      final avgZ = faceVertices
              .map((i) => rotatedVertices[i].z)
              .reduce((a, b) => a + b) /
          4;
      return MapEntry(entry.key, avgZ);
    }).toList();

    faceDepths.sort((a, b) => a.value.compareTo(b.value));

    // Draw faces from back to front
    for (final entry in faceDepths) {
      final faceIndex = entry.key;
      final faceVertices = faces[faceIndex];
      _drawFace(canvas, projectedVertices, faceVertices, faceIndex);
    }

    // Draw wireframe edges for better 3D effect
    _drawWireframe(canvas, projectedVertices);
  }

  Vector3 _rotateVertex(Vector3 vertex, double rotX, double rotY) {
    // Rotate around X axis
    final cosX = math.cos(rotX);
    final sinX = math.sin(rotX);
    final y1 = vertex.y * cosX - vertex.z * sinX;
    final z1 = vertex.y * sinX + vertex.z * cosX;

    // Rotate around Y axis
    final cosY = math.cos(rotY);
    final sinY = math.sin(rotY);
    final x2 = vertex.x * cosY + z1 * sinY;
    final z2 = -vertex.x * sinY + z1 * cosY;

    return Vector3(x2, y1, z2);
  }

  Offset _projectVertex(Vector3 vertex) {
    // Simple perspective projection
    final distance = 400.0;
    final scale = distance / (distance + vertex.z);
    return Offset(vertex.x * scale, vertex.y * scale);
  }

  void _drawFace(Canvas canvas, List<Offset> vertices, List<int> faceVertices,
      int faceIndex) {
    if (sliceImages.isEmpty) return;

    // Create path for the face
    final path = Path();
    path.moveTo(vertices[faceVertices[0]].dx, vertices[faceVertices[0]].dy);
    for (int i = 1; i < faceVertices.length; i++) {
      path.lineTo(vertices[faceVertices[i]].dx, vertices[faceVertices[i]].dy);
    }
    path.close();

    // Fill face with gradient
    final gradient = LinearGradient(
      colors: [
        _getFaceColor(faceIndex).withOpacity(0.7),
        _getFaceColor(faceIndex).withOpacity(0.9),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final bounds = path.getBounds();
    final paint = Paint()
      ..shader = gradient.createShader(bounds)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // Draw slice image if available
    if (faceIndex < sliceImages.length) {
      _drawSliceOnFace(canvas, vertices, faceVertices, sliceImages[faceIndex]);
    }
  }

  void _drawSliceOnFace(Canvas canvas, List<Offset> vertices,
      List<int> faceVertices, ui.Image image) {
    // Calculate face bounds
    final facePoints = faceVertices.map((i) => vertices[i]).toList();

    // Find bounding rectangle of the face
    double minX = facePoints[0].dx;
    double maxX = facePoints[0].dx;
    double minY = facePoints[0].dy;
    double maxY = facePoints[0].dy;

    for (final point in facePoints) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }

    final faceRect = Rect.fromLTRB(minX, minY, maxX, maxY);

    // Draw image scaled to fit the face
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..filterQuality = FilterQuality.medium;

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      faceRect,
      paint,
    );
  }

  Color _getFaceColor(int faceIndex) {
    final colors = [
      Colors.red, // back
      Colors.blue, // front
      Colors.green, // bottom
      Colors.yellow, // top
      Colors.purple, // left
      Colors.orange, // right
    ];
    return colors[faceIndex % colors.length];
  }

  void _drawWireframe(Canvas canvas, List<Offset> vertices) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Define edges of the cube
    final edges = [
      [0, 1], [1, 2], [2, 3], [3, 0], // back face
      [4, 5], [5, 6], [6, 7], [7, 4], // front face
      [0, 4], [1, 5], [2, 6], [3, 7], // connecting edges
    ];

    for (final edge in edges) {
      canvas.drawLine(
        vertices[edge[0]],
        vertices[edge[1]],
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MagicCube3DPainter oldDelegate) {
    return rotationX != oldDelegate.rotationX ||
        rotationY != oldDelegate.rotationY ||
        scale != oldDelegate.scale ||
        sliceImages != oldDelegate.sliceImages;
  }
}

/// Simple 3D vector class
class Vector3 {
  final double x;
  final double y;
  final double z;

  Vector3(this.x, this.y, this.z);
}

/// 3D Preview Screen for full-screen viewing
class MagicCube3DScreen extends StatelessWidget {
  final String projectPath;
  final String templatePath;
  final String projectName;

  const MagicCube3DScreen({
    super.key,
    required this.projectPath,
    required this.templatePath,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('3D Preview - $projectName'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfo(context),
          ),
        ],
      ),
      body: Center(
        child: MagicCube3DPreview(
          projectPath: projectPath,
          templatePath: templatePath,
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
        ),
      ),
      bottomSheet: Container(
        color: Colors.black.withOpacity(0.8),
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Tap the cube to pause/resume rotation\nThis preview shows your processed slices in 3D',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('3D Preview Info'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🎯 Interactive 3D visualization of your magic cube'),
            SizedBox(height: 8),
            Text('✨ Features:'),
            Text('  • Auto-rotating cube display'),
            Text('  • Real slice images on faces'),
            Text('  • Tap to pause/resume rotation'),
            Text('  • Perspective 3D projection'),
            SizedBox(height: 8),
            Text('📝 Note:'),
            Text('  This preview uses your processed slices'),
            Text('  Make sure to process your images first!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}
