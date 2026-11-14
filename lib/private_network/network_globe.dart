import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/private_network/portal_api.dart';

/// An interactive globe that plots the locations returned by the account API.
class NetworkGlobe extends StatefulWidget {
  const NetworkGlobe({super.key, this.nodes = const [], this.onNodeSelected});
  final List<PortalNode> nodes;
  final ValueChanged<int>? onNodeSelected;

  @override
  State<NetworkGlobe> createState() => _NetworkGlobeState();
}

class _NetworkGlobeState extends State<NetworkGlobe> with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(vsync: this, duration: const Duration(seconds: 120));
  static Future<List<List<List<double>>>>? _cachedLand;
  late final Future<List<List<List<double>>>> _land = _cachedLand ??= _loadLand();
  double _manualRotation = 0;
  double _tilt = 0;
  double _zoom = 1.1;
  double _gestureZoom = 1.1;
  final _touches = <int, Offset>{};
  double _pinchDistance = 0;
  int? _selectedNode;

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
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  void _pickNode(Offset point, Size size, double progress) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .405 * _zoom;
    final autoDegrees = progress * 360 - 100 + _manualRotation;
    final yaw = autoDegrees * math.pi / 180;
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final cosTilt = math.cos(_tilt);
    final sinTilt = math.sin(_tilt);
    final markers = <(int, Offset, double)>[];
    for (var index = 0; index < widget.nodes.length; index++) {
      final node = widget.nodes[index];
      if (node.longitude == null || node.latitude == null) continue;
      final longitude = node.longitude! * math.pi / 180;
      final latitude = node.latitude! * math.pi / 180;
      final x = math.cos(latitude) * math.sin(longitude);
      final y = math.sin(latitude);
      final z = math.cos(latitude) * math.cos(longitude);
      final rotatedX = x * cosYaw + z * sinYaw;
      final rotatedZ = z * cosYaw - x * sinYaw;
      final projectedY = y * cosTilt - rotatedZ * sinTilt;
      final depth = y * sinTilt + rotatedZ * cosTilt;
      if (depth > .04) {
        final stackOffset = (index - (widget.nodes.length - 1) / 2) * 48.0;
        final position = center + Offset(rotatedX * radius + stackOffset, -projectedY * radius);
        markers.add((index, position, depth));
      }
    }
    markers.sort((a, b) => (point - a.$2).distanceSquared.compareTo((point - b.$2).distanceSquared));
    for (final marker in markers) {
      if ((point - marker.$2).distance <= 28) {
        setState(() => _selectedNode = marker.$1);
        widget.onNodeSelected?.call(marker.$1);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '可拖动和缩放的地球节点地图',
    image: true,
    child: RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 1,
        child: FutureBuilder<List<List<List<double>>>>(
          future: _land,
          builder: (context, snapshot) => AnimatedBuilder(
            animation: _rotation,
            builder: (context, _) => LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) {},
                  onPanUpdate: (_) {},
                  onTapUp: (details) => _pickNode(details.localPosition, size, _rotation.value),
                  child: Listener(
                    onPointerDown: (event) {
                      _rotation.stop();
                      _touches[event.pointer] = event.localPosition;
                      if (_touches.length == 2) {
                        _pinchDistance = (_touches.values.first - _touches.values.last).distance;
                        _gestureZoom = _zoom;
                      }
                    },
                    onPointerMove: (event) {
                      final previous = _touches[event.pointer];
                      _touches[event.pointer] = event.localPosition;
                      setState(() {
                        if (_touches.length == 2 && _pinchDistance > 0) {
                          _zoom =
                              (_gestureZoom * (_touches.values.first - _touches.values.last).distance / _pinchDistance)
                                  .clamp(.65, 5.0);
                        } else if (_touches.length == 1 && previous != null) {
                          final delta = event.localPosition - previous;
                          _manualRotation += delta.dx / size.shortestSide * 360;
                          _tilt = (_tilt + delta.dy / size.shortestSide * math.pi).clamp(-1.15, 1.15);
                        }
                      });
                    },
                    onPointerUp: (event) => _touches.remove(event.pointer),
                    onPointerCancel: (event) => _touches.remove(event.pointer),
                    child: CustomPaint(
                      painter: _GlobePainter(
                        progress: _rotation.value,
                        land: snapshot.data ?? const [],
                        dark: Theme.of(context).brightness == Brightness.dark,
                        nodes: widget.nodes,
                        selectedNode: _selectedNode,
                        rotation: _manualRotation,
                        tilt: _tilt,
                        zoom: _zoom,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class _GlobePainter extends CustomPainter {
  _GlobePainter({
    required this.progress,
    required this.land,
    required this.dark,
    required this.nodes,
    required this.selectedNode,
    required this.rotation,
    required this.tilt,
    required this.zoom,
  });
  final double progress;
  final List<List<List<double>>> land;
  final bool dark;
  final List<PortalNode> nodes;
  final int? selectedNode;
  final double rotation;
  final double tilt;
  final double zoom;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .405 * zoom;
    final yaw = (progress * 360 - 100 + rotation) * math.pi / 180;
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final cosTilt = math.cos(tilt);
    final sinTilt = math.sin(tilt);
    (Offset, double) project(double longitude, double latitude) {
      final lon = longitude * math.pi / 180;
      final lat = latitude * math.pi / 180;
      final x = math.cos(lat) * math.sin(lon);
      final y = math.sin(lat);
      final z = math.cos(lat) * math.cos(lon);
      final rotatedX = x * cosYaw + z * sinYaw;
      final rotatedZ = z * cosYaw - x * sinYaw;
      final projectedY = y * cosTilt - rotatedZ * sinTilt;
      final depth = y * sinTilt + rotatedZ * cosTilt;
      return (center + Offset(radius * rotatedX, -radius * projectedY), depth);
    }

    if (!dark) {
      final shadowRect = Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * 0.96),
        width: radius * 1.5,
        height: radius * 0.24,
      );
      canvas.drawOval(
        shadowRect,
        Paint()..shader = const RadialGradient(colors: [Color(0x30000000), Color(0x00000000)]).createShader(shadowRect),
      );
    }

    final outline = Paint()
      ..color = dark ? const Color(0xff383c44) : const Color(0xffb8bfc8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final globePath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));

    final sphereRect = Rect.fromCircle(center: center, radius: radius);
    final spherePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.25),
        radius: 0.95,
        colors: dark
            ? const [Color(0xff24272d), Color(0xff181a1d), Color(0xff101114)]
            : const [Color(0xffe8ebf0), Color(0xffd2d7df), Color(0xffbcc2cb)],
      ).createShader(sphereRect);
    canvas.drawCircle(center, radius, spherePaint);

    canvas.save();
    canvas.clipPath(globePath);

    final graticule = Paint()
      ..color = dark ? const Color(0x22ffffff) : const Color(0x26000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;

    for (final latDeg in const [-60.0, -30.0, 0.0, 30.0, 60.0]) {
      Path? latPath;
      for (var lonDeg = -180.0; lonDeg <= 180.0; lonDeg += 5.0) {
        final pt = project(lonDeg, latDeg);
        if (pt.$2 > 0) {
          if (latPath == null) {
            latPath = Path()..moveTo(pt.$1.dx, pt.$1.dy);
          } else {
            latPath.lineTo(pt.$1.dx, pt.$1.dy);
          }
        } else {
          if (latPath != null) {
            canvas.drawPath(latPath, graticule);
            latPath = null;
          }
        }
      }
      if (latPath != null) {
        canvas.drawPath(latPath, graticule);
      }
    }

    for (var lonDeg = -180.0; lonDeg < 180.0; lonDeg += 30.0) {
      Path? lonPath;
      for (var latDeg = -85.0; latDeg <= 85.0; latDeg += 5.0) {
        final pt = project(lonDeg, latDeg);
        if (pt.$2 > 0) {
          if (lonPath == null) {
            lonPath = Path()..moveTo(pt.$1.dx, pt.$1.dy);
          } else {
            lonPath.lineTo(pt.$1.dx, pt.$1.dy);
          }
        } else {
          if (lonPath != null) {
            canvas.drawPath(lonPath, graticule);
            lonPath = null;
          }
        }
      }
      if (lonPath != null) {
        canvas.drawPath(lonPath, graticule);
      }
    }

    final fill = Paint()..color = dark ? const Color(0xff3f444d) : const Color(0xff9ea5af);
    for (final ring in land) {
      final vertexCount = ring.length - 1;
      if (vertexCount < 3) continue;
      final points = List.generate(vertexCount, (index) => project(ring[index][0], ring[index][1]));
      if (!points.any((point) => point.$2 > 0)) continue;
      if (points.every((point) => point.$2 > 0)) {
        final path = Path()..moveTo(points.first.$1.dx, points.first.$1.dy);
        for (final point in points.skip(1)) {
          path.lineTo(point.$1.dx, point.$1.dy);
        }
        canvas.drawPath(path..close(), fill);
        continue;
      }
      final start = points.indexWhere((point) => point.$2 <= 0);
      final visibleSegment = <Offset>[];
      void drawVisibleSegment() {
        if (visibleSegment.length >= 3) {
          final path = Path()..moveTo(visibleSegment.first.dx, visibleSegment.first.dy);
          for (final point in visibleSegment.skip(1)) {
            path.lineTo(point.dx, point.dy);
          }
          // Close along the spherical horizon instead of cutting across the globe.
          final from = visibleSegment.last - center;
          final to = visibleSegment.first - center;
          final startAngle = math.atan2(from.dy, from.dx);
          var sweep = math.atan2(to.dy, to.dx) - startAngle;
          while (sweep > math.pi) {
            sweep -= 2 * math.pi;
          }
          while (sweep < -math.pi) {
            sweep += 2 * math.pi;
          }
          path.arcTo(Rect.fromCircle(center: center, radius: radius), startAngle, sweep, false);
          canvas.drawPath(path..close(), fill);
        }
        visibleSegment.clear();
      }

      Offset horizonPoint(int index, int nextIndex, bool currentIsVisible) {
        var low = 0.0;
        var high = 1.0;
        final current = ring[index];
        final next = ring[nextIndex];
        for (var step = 0; step < 16; step++) {
          final fraction = (low + high) / 2;
          final longitude = current[0] + (next[0] - current[0]) * fraction;
          final latitude = current[1] + (next[1] - current[1]) * fraction;
          if ((project(longitude, latitude).$2 > 0) == currentIsVisible) {
            low = fraction;
          } else {
            high = fraction;
          }
        }
        final fraction = (low + high) / 2;
        final longitude = current[0] + (next[0] - current[0]) * fraction;
        final latitude = current[1] + (next[1] - current[1]) * fraction;
        return project(longitude, latitude).$1;
      }

      // Begin on the hidden side so every visible run is a separate clipped
      // polygon instead of connecting distant far-side vertices across land.
      for (var step = 0; step < vertexCount; step++) {
        final index = (start + step) % vertexCount;
        final nextIndex = (index + 1) % vertexCount;
        final currentVisible = points[index].$2 > 0;
        final nextVisible = points[nextIndex].$2 > 0;
        if (currentVisible && nextVisible) {
          if (visibleSegment.isEmpty) visibleSegment.add(points[index].$1);
          visibleSegment.add(points[nextIndex].$1);
        } else if (currentVisible && !nextVisible) {
          if (visibleSegment.isEmpty) visibleSegment.add(points[index].$1);
          visibleSegment.add(horizonPoint(index, index + 1, true));
          drawVisibleSegment();
        } else if (!currentVisible && nextVisible) {
          visibleSegment
            ..add(horizonPoint(index, index + 1, false))
            ..add(points[nextIndex].$1);
        }
      }
      drawVisibleSegment();
    }
    canvas.restore();
    canvas.drawCircle(center, radius, outline);
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      if (node.longitude == null || node.latitude == null) continue;
      final point = project(node.longitude!, node.latitude!);
      if (point.$2 <= .04) continue;
      final position = point.$1 + Offset((index - (nodes.length - 1) / 2) * 48.0, 0);
      final selected = selectedNode == index;
      if (selected) {
        canvas.drawCircle(
          position,
          19,
          Paint()
            ..color = dark ? Colors.white38 : Colors.black26
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      canvas.drawCircle(position, selected ? 14 : 11, Paint()..color = dark ? Colors.white : Colors.black);
      canvas.drawCircle(position, selected ? 6 : 4, Paint()..color = dark ? Colors.black : Colors.white);
      if (selected) {
        final text = TextPainter(
          text: TextSpan(
            text: node.name,
            style: TextStyle(color: dark ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: size.width * .55);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(position.dx - text.width / 2 - 9, position.dy - 48, text.width + 18, text.height + 8),
          const Radius.circular(12),
        );
        canvas.drawRRect(rect, Paint()..color = dark ? Colors.white : Colors.black);
        text.paint(canvas, Offset(rect.left + 9, rect.top + 4));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlobePainter old) =>
      progress != old.progress ||
      land != old.land ||
      dark != old.dark ||
      nodes != old.nodes ||
      selectedNode != old.selectedNode ||
      rotation != old.rotation ||
      tilt != old.tilt ||
      zoom != old.zoom;
}
