import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() {
  runApp(
    const MaterialApp(home: CyberspaceApp(), debugShowCheckedModeBanner: false),
  );
}

enum RenderMode { gpu, cpu }

enum ShaderType { aperture, chords, cyberspace }

class CyberspaceApp extends StatefulWidget {
  const CyberspaceApp({super.key});

  @override
  State<CyberspaceApp> createState() => _CyberspaceAppState();
}

class _CyberspaceAppState extends State<CyberspaceApp>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _time = 0.0;
  ui.FragmentProgram? _program;
  RenderMode _mode = RenderMode.gpu;
  ShaderType _shaderType = ShaderType.aperture;
  bool _showButtons = true;

  @override
  void initState() {
    super.initState();
    _loadShader(_shaderType);
    _ticker = createTicker((elapsed) {
      setState(() {
        _time = elapsed.inMilliseconds / 1000.0;
      });
    });
    _ticker.start();
  }

  String _getShaderPath(ShaderType type) {
    switch (type) {
      case ShaderType.aperture:
        return 'shaders/aperture.frag';
      case ShaderType.chords:
        return 'shaders/chords.frag';
      case ShaderType.cyberspace:
        return 'shaders/cyberspace.frag';
    }
  }

  Future<void> _loadShader(ShaderType type) async {
    try {
      final program = await ui.FragmentProgram.fromAsset(_getShaderPath(type));
      setState(() {
        _program = program;
        _shaderType = type;
      });
    } catch (e) {
      debugPrint('Error loading shader: $e');
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onDoubleTap: () {
              setState(() {
                _showButtons = true;
              });
            },
            child: SizedBox.expand(child: _buildPainter()),
          ),
          if (_showButtons)
            Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: _buildShaderSelector(),
            ),
        ],
      ),
    );
  }

  Widget _buildShaderSelector() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildShaderButton(ShaderType.aperture, '1'),
          _buildShaderButton(ShaderType.chords, '2'),
          _buildShaderButton(ShaderType.cyberspace, '3'),
          _buildCpuToggle(),
          GestureDetector(
            onTap: () {
              setState(() {
                _showButtons = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShaderButton(ShaderType type, String label) {
    final isSelected = _shaderType == type;
    return GestureDetector(
      onTap: () => _loadShader(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCpuToggle() {
    final isCpuMode = _mode == RenderMode.cpu;
    return GestureDetector(
      onTap: () {
        setState(() {
          _mode = isCpuMode ? RenderMode.gpu : RenderMode.cpu;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isCpuMode ? Colors.orangeAccent : Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isCpuMode ? 'CPU' : 'GPU',
          style: TextStyle(
            color: isCpuMode ? Colors.white : Colors.white70,
            fontWeight: isCpuMode ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPainter() {
    if (_mode == RenderMode.gpu) {
      if (_program == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return CustomPaint(
        painter: ShaderPainter(shader: _program!.fragmentShader(), time: _time),
      );
    } else {
      return CustomPaint(painter: CpuRaymarchPainter(time: _time));
    }
  }
}

// --- GPU Implementation ---

class ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;

  ShaderPainter({required this.shader, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant ShaderPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.shader != shader;
  }
}

// --- CPU Implementation ---

/// A Painter that simulates a GLSL raymarching shader on the CPU.
class CpuRaymarchPainter extends CustomPainter {
  final double time;

  /// Controls the resolution.
  /// 1.0 = 1:1 pixel match (EXTREMELY SLOW on CPU).
  /// 8.0 = 1 rendered pixel represents an 8x8 block (Recommended for realtime).
  final double pixelSize;

  CpuRaymarchPainter({required this.time, this.pixelSize = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // We draw points with a specific thickness to simulate pixels
    final Paint paint = Paint()..strokeWidth = pixelSize;

    // Pre-allocate lists for batch drawing (much faster than individual drawRect calls)
    final List<ui.Offset> points = [];
    final List<ui.Color> colors = [];

    // Loop through the canvas coordinates based on pixelSize
    for (double y = 0; y < h; y += pixelSize) {
      for (double x = 0; x < w; x += pixelSize) {
        // --- Start of Shader Logic ---

        // Equivalent to: vec2 r = uSize;
        // Equivalent to: vec2 FC = gl_FragCoord.xy;
        // In shader, (0,0) is usually bottom-left. In Flutter, top-left.
        // We flip Y to match GLSL coordinates if desired, but here we stick to Flutter's.

        // Normalize Ray Direction
        // vec3 p = abs(z * normalize(vec3(FC, 0.0) * 2.0 - vec3(r.x, r.y, r.y)));

        // Calculate the vector inside the normalize() first:
        // vec3(FC, 0.0) * 2.0 -> (2*x, 2*y, 0)
        // - vec3(w, h, h)
        double dirX = (x * 2.0) - w;
        double dirY = (y * 2.0) - h;
        double dirZ = -h;

        // Normalize
        double len = math.sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ);
        if (len != 0) {
          dirX /= len;
          dirY /= len;
          dirZ /= len;
        }

        // Variables for the raymarch loop
        // vec4 o = vec4(0.0);
        double oR = 0, oG = 0, oB = 0, oA = 0;

        double i = 0.0;
        double z = 0.0;
        double d = 0.0;

        // Outer Loop: for (int iter = 0; iter < 100; iter++)
        for (int iter = 0; iter < 100; iter++) {
          if (z + i >= 70.0) break;
          i += 1.0;

          // vec3 p = abs(z * normalize(...));
          // We already computed normalized dir in (dirX, dirY, dirZ)
          double pX = (z * dirX).abs();
          double pY = (z * dirY).abs();
          double pZ = (z * dirZ).abs();

          // p.z += t * 5.0;
          pZ += time * 5.0;

          // p += sin(p + p); -> sin(2*p)
          pX += math.sin(2 * pX);
          pY += math.sin(2 * pY);
          pZ += math.sin(2 * pZ);

          // Inner Loop: 9 iterations
          d = 0.0;
          for (int j = 0; j < 9; j++) {
            d += 1.0;

            // vec3 angle = round(0.2 * d * p) + 0.2 * t;
            double agX = (0.2 * d * pX).roundToDouble() + 0.2 * time;
            double agY = (0.2 * d * pY).roundToDouble() + 0.2 * time;
            double agZ = (0.2 * d * pZ).roundToDouble() + 0.2 * time;

            // p += 0.4 * cos(angle).zxy;
            // Swizzle .zxy mapping:
            // New X adds cos(angle.z)
            // New Y adds cos(angle.x)
            // New Z adds cos(angle.y)

            double cX = math.cos(agX);
            double cY = math.cos(agY);
            double cZ = math.cos(agZ);

            pX += 0.4 * cZ;
            pY += 0.4 * cX;
            pZ += 0.4 * cY;
          }

          // z += d = 0.1 * sqrt(length(p.xyy * p.yxy));
          // p.xyy = (pX, pY, pY)
          // p.yxy = (pY, pX, pY)
          // Multiply components: (pX*pY, pY*pX, pY*pY)
          double v1 = pX * pY;
          double v2 = pY * pX; // Same as v1
          double v3 = pY * pY;

          // length of that vector
          double lenVal = math.sqrt(v1 * v1 + v2 * v2 + v3 * v3);

          d = 0.1 * math.sqrt(lenVal);
          z += d;

          // o += vec4(z, 1.0, 9.0, 1.0) / max(d, 0.0001);
          double div = math.max(d, 0.0001);
          oR += z / div;
          oG += 1.0 / div;
          oB += 9.0 / div;
          oA += 1.0 / div;
        }

        // fragColor = tanh_safe(o / 7000.0);
        // Apply scale
        oR /= 7000.0;
        oG /= 7000.0;
        oB /= 7000.0;
        // oA /= 7000.0; // Alpha usually ignored for opaque canvas painting, assuming 1.0

        // Tanh and clamp to 0..1 range for display
        double r = _tanh(oR).clamp(0.0, 1.0);
        double g = _tanh(oG).clamp(0.0, 1.0);
        double b = _tanh(oB).clamp(0.0, 1.0);

        // --- End of Shader Logic ---

        // Store point data
        points.add(Offset(x, y));
        // Convert to Flutter Color (ARGB)
        colors.add(
          Color.fromARGB(
            255,
            (r * 255).toInt(),
            (g * 255).toInt(),
            (b * 255).toInt(),
          ),
        );
      }
    }

    // Draw all points at once using vertices for better CPU performance
    final vertices = ui.Vertices(
      ui
          .VertexMode
          .triangleFan, // Using points mode via raw Points helper below would be easier, but this is standard
      points,
      colors: colors,
    );

    // Since drawVertices with point mode isn't directly exposed easily without indices setup,
    // and drawPoints doesn't support per-point colors, we iterate.
    // NOTE: For maximum performance in Dart, you'd generate a raw image buffer.
    // For this 'Painter' implementation, we loop drawPoints (slow) or simulated pixels.

    for (int k = 0; k < points.length; k++) {
      paint.color = colors[k];
      // Draw a small square to fill the gap
      canvas.drawRect(
        Rect.fromLTWH(points[k].dx, points[k].dy, pixelSize, pixelSize + 0.5),
        paint,
      );
    }
  }

  // Helper for Tanh: (e^2x - 1) / (e^2x + 1)
  double _tanh(double x) {
    if (x > 20.0) return 1.0;
    if (x < -20.0) return -1.0;
    double e2x = math.exp(2.0 * x);
    return (e2x - 1.0) / (e2x + 1.0);
  }

  @override
  bool shouldRepaint(covariant CpuRaymarchPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.pixelSize != pixelSize;
  }
}

class RaymarchParams extends StatefulWidget {
  const RaymarchParams({super.key});

  @override
  State<RaymarchParams> createState() => _RaymarchParamsState();
}

class _RaymarchParamsState extends State<RaymarchParams>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: CpuRaymarchPainter(
            time: _controller.value * 10.0, // Speed multiplier
            pixelSize: 8.0, // Increased for performance (10x10 blocks)
          ),
          size: Size.infinite,
        );
      },
    );
  }
}
