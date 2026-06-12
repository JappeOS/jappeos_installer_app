import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:jovial_svg/jovial_svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class TimezoneMap extends StatefulWidget {
  final String? selectedTimezone;

  final List<String>? availableTimezones;

  final ValueChanged<String> onTimezoneSelected;

  const TimezoneMap({
    super.key,
    required this.selectedTimezone,
    this.availableTimezones,
    required this.onTimezoneSelected,
  });

  @override
  State<TimezoneMap> createState() => _TimezoneMapState();
}

class _TimezoneMapState extends State<TimezoneMap> {
  late final Future<_TimezoneMapData> _dataFuture = _TimezoneMapData.load();

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.border;

    return FutureBuilder<_TimezoneMapData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;

        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: Theme.of(context).borderRadiusLg,
          ),
          child: ClipRRect(
            borderRadius: Theme.of(context).borderRadiusLg,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: AspectRatio(
                    aspectRatio: _TimezoneProjection.aspectRatio,
                    child: data == null
                        ? const Center(child: CircularProgressIndicator())
                        : _InteractiveTimezoneMap(
                            data: data,
                            selectedTimezone: widget.selectedTimezone,
                            availableTimezones: widget.availableTimezones,
                            onTimezoneSelected: widget.onTimezoneSelected,
                          ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _InteractiveTimezoneMap extends StatelessWidget {
  final _TimezoneMapData data;

  final String? selectedTimezone;

  final List<String>? availableTimezones;

  final ValueChanged<String> onTimezoneSelected;

  const _InteractiveTimezoneMap({
    required this.data,
    required this.selectedTimezone,
    required this.availableTimezones,
    required this.onTimezoneSelected,
  });

  @override
  Widget build(BuildContext context) {
    final available = availableTimezones == null
        ? null
        : Set<String>.unmodifiable(availableTimezones!);
    final selectedFeature = selectedTimezone == null
        ? null
        : data.featureByTimezone[selectedTimezone];

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final projection = _TimezoneProjection(size);
            final coordinate = projection.offsetToCoordinate(
              details.localPosition,
            );
            final feature = data.hitTest(coordinate);
            if (feature == null) {
              return;
            }
            if (available != null && !available.contains(feature.timezoneId)) {
              return;
            }

            onTimezoneSelected(feature.timezoneId);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              ScalableImageWidget.fromSISource(
                si: ScalableImageSource.fromSvg(
                  rootBundle,
                  'assets/maps/world.svg',
                  compact: true,
                  warnF: (_) {},
                ),
                fit: BoxFit.fill,
              ),
              CustomPaint(
                painter: _TimezonePainter(
                  features: data.features,
                  selectedFeature: selectedFeature,
                ),
              ),
              if (selectedFeature != null)
                CustomPaint(
                  painter: _TimezoneMarkerPainter(feature: selectedFeature),
                ),
            ],
          ),
        );
      },
    );
  }
}

class TimezoneFeature {
  final String timezoneId;

  final Rect bounds;

  final Offset centroid;

  final List<TimezonePolygon> polygons;

  const TimezoneFeature({
    required this.timezoneId,
    required this.bounds,
    required this.centroid,
    required this.polygons,
  });

  bool contains(Offset coordinate) {
    if (!bounds.contains(coordinate)) {
      return false;
    }

    for (final polygon in polygons) {
      if (polygon.contains(coordinate)) {
        return true;
      }
    }

    return false;
  }
}

class TimezonePolygon {
  final List<List<Offset>> rings;

  const TimezonePolygon({required this.rings});

  bool contains(Offset coordinate) {
    if (rings.isEmpty || !_ringContains(rings.first, coordinate)) {
      return false;
    }

    for (final hole in rings.skip(1)) {
      if (_ringContains(hole, coordinate)) {
        return false;
      }
    }

    return true;
  }
}

class _TimezoneMapData {
  final List<TimezoneFeature> features;

  final Map<String, TimezoneFeature> featureByTimezone;

  const _TimezoneMapData({
    required this.features,
    required this.featureByTimezone,
  });

  static Future<_TimezoneMapData> load() async {
    final source = await rootBundle.loadString(
      'assets/timezones/combined_simplified.json',
    );
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    final rawFeatures = decoded['features'] as List<dynamic>;

    final features = rawFeatures
        .map((raw) {
          final feature = raw as Map<String, dynamic>;
          final bbox = (feature['bbox'] as List<dynamic>)
              .map((value) => (value as num).toDouble())
              .toList();
          final centroid = (feature['centroid'] as List<dynamic>)
              .map((value) => (value as num).toDouble())
              .toList();
          final rawPolygons = feature['polygons'] as List<dynamic>;

          return TimezoneFeature(
            timezoneId: feature['tzid'] as String,
            bounds: Rect.fromLTRB(bbox[0], bbox[1], bbox[2], bbox[3]),
            centroid: Offset(centroid[0], centroid[1]),
            polygons: rawPolygons.map((rawPolygon) {
              final rawRings = rawPolygon as List<dynamic>;
              return TimezonePolygon(
                rings: rawRings.map((rawRing) {
                  final rawPoints = rawRing as List<dynamic>;
                  return rawPoints.map((rawPoint) {
                    final point = rawPoint as List<dynamic>;
                    return Offset(
                      (point[0] as num).toDouble(),
                      (point[1] as num).toDouble(),
                    );
                  }).toList();
                }).toList(),
              );
            }).toList(),
          );
        })
        .toList(growable: false);

    return _TimezoneMapData(
      features: features,
      featureByTimezone: {
        for (final feature in features) feature.timezoneId: feature,
      },
    );
  }

  TimezoneFeature? hitTest(Offset coordinate) {
    for (final feature in features.reversed) {
      if (feature.contains(coordinate)) {
        return feature;
      }
    }

    return null;
  }
}

class _TimezonePainter extends CustomPainter {
  final List<TimezoneFeature> features;

  final TimezoneFeature? selectedFeature;

  const _TimezonePainter({
    required this.features,
    required this.selectedFeature,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final projection = _TimezoneProjection(size);
    final borderPaint = Paint()
      ..color = Colors.black.withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.55;
    final selectedFillPaint = Paint()
      ..color = Colors.green.withAlpha(120)
      ..style = PaintingStyle.fill;
    final selectedBorderPaint = Paint()
      ..color = Colors.green.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    for (final feature in features) {
      for (final polygon in feature.polygons) {
        canvas.drawPath(_pathForPolygon(polygon, projection), borderPaint);
      }
    }

    final selected = selectedFeature;
    if (selected == null) {
      return;
    }

    for (final polygon in selected.polygons) {
      final path = _pathForPolygon(polygon, projection);
      canvas.drawPath(path, selectedFillPaint);
      canvas.drawPath(path, selectedBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimezonePainter oldDelegate) {
    return features != oldDelegate.features ||
        selectedFeature != oldDelegate.selectedFeature;
  }
}

class _TimezoneMarkerPainter extends CustomPainter {
  final TimezoneFeature feature;

  const _TimezoneMarkerPainter({required this.feature});

  @override
  void paint(Canvas canvas, Size size) {
    final projection = _TimezoneProjection(size);
    final center = projection.coordinateToOffset(feature.centroid);
    final radius = math.max(4.0, size.shortestSide * 0.008);
    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final markerPaint = Paint()
      ..color = Colors.green.shade700
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius + 2, ringPaint);
    canvas.drawCircle(center, radius, markerPaint);
  }

  @override
  bool shouldRepaint(covariant _TimezoneMarkerPainter oldDelegate) {
    return feature != oldDelegate.feature;
  }
}

class _TimezoneProjection {
  static const aspectRatio = 1570.2 / 759.36;
  static const _centralMeridian = 15.0;
  static const _topLatitude = 84.0;
  static const _bottomLatitude = -90.0;

  final Size size;

  const _TimezoneProjection(this.size);

  Offset coordinateToOffset(Offset coordinate) {
    final normalizedLongitude = (coordinate.dx - _centralMeridian + 180) % 360;
    final x = (normalizedLongitude / 360) * size.width;
    final y =
        ((_topLatitude - coordinate.dy) / (_topLatitude - _bottomLatitude)) *
        size.height;
    return Offset(x, y);
  }

  Offset offsetToCoordinate(Offset offset) {
    final longitude = _normalizeLongitude(
      (offset.dx / size.width) * 360 + _centralMeridian - 180,
    );
    final latitude =
        _topLatitude -
        (offset.dy / size.height) * (_topLatitude - _bottomLatitude);
    return Offset(longitude.clamp(-180, 180), latitude.clamp(-90, 90));
  }
}

double _normalizeLongitude(double longitude) {
  var normalized = longitude;
  while (normalized < -180) {
    normalized += 360;
  }
  while (normalized > 180) {
    normalized -= 360;
  }
  return normalized;
}

Path _pathForPolygon(TimezonePolygon polygon, _TimezoneProjection projection) {
  final path = Path()..fillType = PathFillType.evenOdd;
  final seamThreshold = projection.size.width / 2;

  for (final ring in polygon.rings) {
    if (ring.isEmpty) {
      continue;
    }

    var previous = projection.coordinateToOffset(ring.first);
    var crossesSeam = false;
    path.moveTo(previous.dx, previous.dy);
    for (final coordinate in ring.skip(1)) {
      final point = projection.coordinateToOffset(coordinate);
      if ((point.dx - previous.dx).abs() > seamThreshold) {
        crossesSeam = true;
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      previous = point;
    }
    if (!crossesSeam) {
      path.close();
    }
  }

  return path;
}

bool _ringContains(List<Offset> ring, Offset coordinate) {
  var inside = false;
  var j = ring.length - 1;

  for (var i = 0; i < ring.length; i++) {
    final pi = ring[i];
    final pj = ring[j];
    final intersects =
        (pi.dy > coordinate.dy) != (pj.dy > coordinate.dy) &&
        coordinate.dx <
            (pj.dx - pi.dx) *
                    (coordinate.dy - pi.dy) /
                    ((pj.dy - pi.dy) == 0 ? 1e-12 : pj.dy - pi.dy) +
                pi.dx;
    if (intersects) {
      inside = !inside;
    }
    j = i;
  }

  return inside;
}
