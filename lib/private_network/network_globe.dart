import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Uses the same land data, orthographic projection and city routes as the website.
class NetworkGlobe extends StatefulWidget {
  const NetworkGlobe({super.key, this.connected = false});
  final bool connected;
  @override
  State<NetworkGlobe> createState() => _NetworkGlobeState();
}

class _NetworkGlobeState extends State<NetworkGlobe> with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(vsync: this, duration: const Duration(seconds: 120));
  static Future<List<List<List<double>>>>? _cachedLand;
  late final Future<List<List<List<double>>>> _land = _cachedLand ??= _loadLand();

  static Future<List<List<List<double>>>> _loadLand() async {
    final data = jsonDecode(await rootBundle.loadString('assets/private_network/land.geojson')) as Map<String, dynamic>;
    final rings = <List<List<double>>>[];
    for (final feature in data['features'] as List) {
      final geometry = (feature as Map)['geometry'] as Map;
      final coordinates = geometry['coordinates'] as List;
      final polygons = geometry['type'] == 'Polygon' ? [coordinates] : coordinates;
      for (final polygon in polygons) {
        final ring = (polygon as List).first as List;
        rings.add(ring.map((point) => (point as List).take(2).map((n) => (n as num).toDouble()).toList()).toList());
      }
    }
    return rings;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _rotation.stop();
    } else if (!_rotation.isAnimating) {
      _rotation.repeat();
    }
  }

  @override
  void dispose() { _rotation.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '地球与城市间的网络连线', image: true,
    child: RepaintBoundary(child: AspectRatio(aspectRatio: 1, child: FutureBuilder<List<List<List<double>>>>(
      future: _land,
      builder: (context, snapshot) => AnimatedBuilder(
        animation: _rotation,
        builder: (context, _) => CustomPaint(painter: _GlobePainter(
          _rotation.value, snapshot.data ?? const [], Theme.of(context).brightness == Brightness.dark, widget.connected,
        )),
      ),
    ))),
  );
}

class _GlobePainter extends CustomPainter {
  _GlobePainter(this.progress, this.land, this.dark, this.connected);
  final double progress;
  final List<List<List<double>>> land;
  final bool dark;
  final bool connected;
  static const cities = <(double, double)>[
    (101.69, 3.14), (103.82, 1.35), (114.17, 22.32), (121.57, 25.03),
    (139.69, 35.68), (126.98, 37.57), (151.21, -33.87), (-0.13, 51.51),
    (2.35, 48.86), (-74.01, 40.71), (-118.24, 34.05),
  ];
  static const routes = [(0, 1), (0, 2), (1, 3), (2, 4), (3, 5), (1, 6), (7, 8), (7, 9), (9, 10)];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .405;
    final rotation = progress * 360 - 100;
    (Offset, double) project(double longitude, double latitude) {
      final lon = (longitude + rotation) * math.pi / 180;
      final lat = latitude * math.pi / 180;
      return (center + Offset(radius * math.cos(lat) * math.sin(lon), -radius * math.sin(lat)), math.cos(lat) * math.cos(lon));
    }
    final outline = Paint()..color = dark ? const Color(0xff555555) : const Color(0xffcccccc)
      ..style = PaintingStyle.stroke..strokeWidth = 1;
    final globePath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, Paint()..color = dark ? const Color(0xff202020) : const Color(0xfff7f7f7));
    canvas.save();
    canvas.clipPath(globePath);
    final fill = Paint()..color = dark ? const Color(0xff484848) : const Color(0xffbfc2c3);
    for (final ring in land) {
      final points = ring.map((point) => project(point[0], point[1])).toList();
      if (!points.any((point) => point.$2 > 0)) continue;
      final path = Path();
      for (var index = 0; index < points.length; index++) {
        var point = points[index].$1;
        if (points[index].$2 < 0) {
          final delta = point - center;
          point = center + delta / (delta.distance == 0 ? 1 : delta.distance) * radius;
        }
        if (index == 0) { path.moveTo(point.dx, point.dy); } else { path.lineTo(point.dx, point.dy); }
      }
      canvas.drawPath(path..close(), fill);
    }
    canvas.restore();
    canvas.drawCircle(center, radius, outline);
    final routePaint = Paint()..color = dark ? const Color(0xffaaaaaa) : const Color(0xff777777)
      ..style = PaintingStyle.stroke..strokeWidth = 1;
    final dotPaint = Paint()..color = dark ? Colors.white : const Color(0xff333333);
    for (var index = 0; index < routes.length; index++) {
      final route = routes[index];
      final start = project(cities[route.$1].$1, cities[route.$1].$2);
      final end = project(cities[route.$2].$1, cities[route.$2].$2);
      if (start.$2 < .1 || end.$2 < .1) continue;
      final middle = (start.$1 + end.$1) / 2 - Offset(0, math.min(radius * .25, (start.$1 - end.$1).distance * .25));
      final path = Path()..moveTo(start.$1.dx, start.$1.dy)
        ..quadraticBezierTo(middle.dx, middle.dy, end.$1.dx, end.$1.dy);
      for (final metric in path.computeMetrics()) {
        for (var distance = 0.0; distance < metric.length; distance += 7) {
          canvas.drawPath(metric.extractPath(distance, math.min(distance + 3, metric.length)), routePaint);
        }
        final tangent = metric.getTangentForOffset(metric.length * ((progress * 24 + index / routes.length) % 1));
        if (tangent != null) {
          canvas.save(); canvas.translate(tangent.position.dx, tangent.position.dy); canvas.rotate(tangent.angle);
          canvas.drawPath(Path()..moveTo(5, 0)..lineTo(-3, -3)..lineTo(-1, 0)..lineTo(-3, 3)..close(), dotPaint);
          canvas.restore();
        }
      }
      canvas.drawCircle(start.$1, connected ? 2.5 : 2, dotPaint);
      canvas.drawCircle(end.$1, connected ? 2.5 : 2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter old) => progress != old.progress ||
    land != old.land || dark != old.dark || connected != old.connected;
}
