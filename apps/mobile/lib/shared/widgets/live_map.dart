import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/config/env.dart';
import '../../core/theme/brand_tokens.dart';
import '../launcher.dart';

/// What a point on the map represents. Only the icon and colour differ; the
/// semantics matter for the accessibility label.
enum MapPointKind { rider, customer, store }

/// One pin. Immutable so the map can diff cheaply between rebuilds — a rider
/// position arrives every few seconds and must not cause a full marker rebuild.
@immutable
class MapPoint {
  const MapPoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.kind,
    this.caption,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String label;
  final MapPointKind kind;
  final String? caption;

  LatLng get position => LatLng(latitude, longitude);

  @override
  bool operator ==(Object other) =>
      other is MapPoint &&
      other.id == id &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.label == label &&
      other.kind == kind &&
      other.caption == caption;

  @override
  int get hashCode => Object.hash(id, latitude, longitude, label, kind, caption);
}

/// An embedded map showing where things are right now.
///
/// Two behaviours in one widget, deliberately:
///
///  * With a Maps key, a real map with pins and a straight line between the first
///    and last point. The line is intentionally not a driving route — we would
///    have to pay the Directions API per request and refresh it on every GPS fix,
///    for a visual that a rider does not use to navigate. Turn-by-turn hands off
///    to the phone's own maps app, which is what riders actually use.
///  * Without a key, a compact panel carrying the same information plus a
///    hand-off button. Nothing in the product depends on the embedded map, so a
///    build with no Maps billing configured still works end to end.
class LiveMap extends StatefulWidget {
  const LiveMap({
    required this.points,
    this.height = 200,
    this.followFirstPoint = true,
    this.emptyMessage = 'Waiting for a location…',
    super.key,
  });

  final List<MapPoint> points;
  final double height;

  /// Keeps the camera on the first point (the moving one) instead of refitting
  /// the whole route on every update, which would jitter the view.
  final bool followFirstPoint;
  final String emptyMessage;

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> {
  final Completer<GoogleMapController> _controller = Completer();
  bool _fittedOnce = false;

  @override
  void didUpdateWidget(LiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) _moveCamera();
  }

  Future<void> _moveCamera() async {
    if (widget.points.isEmpty) return;
    final controller = await _controller.future;
    if (!mounted) return;

    // Fit everything once so the customer sees the whole journey, then follow the
    // rider so the pin never drifts off screen.
    if (!_fittedOnce && widget.points.length > 1) {
      _fittedOnce = true;
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(_bounds(widget.points), 56),
      );
      return;
    }

    if (widget.followFirstPoint) {
      await controller.animateCamera(
        CameraUpdate.newLatLng(widget.points.first.position),
      );
    }
  }

  static LatLngBounds _bounds(List<MapPoint> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // A zero-area bounds makes newLatLngBounds throw, so pad a degenerate box.
    const padding = 0.002;
    return LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    if (widget.points.isEmpty) {
      return _MapShell(
        height: widget.height,
        child: Center(
          child: Text(
            widget.emptyMessage,
            style: TextStyle(fontSize: 13, color: brand.inkMuted),
          ),
        ),
      );
    }

    if (!Env.mapsEnabled) {
      return _MapFallback(points: widget.points);
    }

    final markers = widget.points
        .map(
          (point) => Marker(
            markerId: MarkerId(point.id),
            position: point.position,
            icon: BitmapDescriptor.defaultMarkerWithHue(_hueFor(point.kind)),
            infoWindow: InfoWindow(title: point.label, snippet: point.caption),
          ),
        )
        .toSet();

    return _MapShell(
      height: widget.height,
      child: Semantics(
        label: 'Map showing ${widget.points.map((point) => point.label).join(' and ')}',
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.points.first.position,
            zoom: 15,
          ),
          markers: markers,
          polylines: widget.points.length < 2
              ? const {}
              : {
                  Polyline(
                    polylineId: const PolylineId('journey'),
                    points: [
                      widget.points.first.position,
                      widget.points.last.position,
                    ],
                    color: brand.primary.withValues(alpha: 0.55),
                    width: 4,
                    patterns: [PatternItem.dash(18), PatternItem.gap(10)],
                  ),
                },
          // A map inside a scrolling list should not steal vertical drags.
          scrollGesturesEnabled: false,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          liteModeEnabled: false,
          compassEnabled: false,
          onMapCreated: (controller) {
            if (!_controller.isCompleted) _controller.complete(controller);
            _moveCamera();
          },
        ),
      ),
    );
  }

  double _hueFor(MapPointKind kind) => switch (kind) {
        MapPointKind.rider => BitmapDescriptor.hueOrange,
        MapPointKind.customer => BitmapDescriptor.hueRed,
        MapPointKind.store => BitmapDescriptor.hueAzure,
      };
}

class _MapShell extends StatelessWidget {
  const _MapShell({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return ClipRRect(
      borderRadius: BorderRadius.circular(brand.radiusMd),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: brand.surfaceMuted,
          border: Border.all(color: brand.hairline),
          borderRadius: BorderRadius.circular(brand.radiusMd),
        ),
        child: child,
      ),
    );
  }
}

/// Shown when the build carries no Maps key. Same information, no billing.
class _MapFallback extends StatelessWidget {
  const _MapFallback({required this.points});

  final List<MapPoint> points;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final primary = points.first;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(brand.radiusMd),
        border: Border.all(color: brand.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    switch (point.kind) {
                      MapPointKind.rider => Icons.two_wheeler_rounded,
                      MapPointKind.customer => Icons.location_on_rounded,
                      MapPointKind.store => Icons.storefront_rounded,
                    },
                    size: 17,
                    color: brand.inkMuted,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      point.caption == null
                          ? point.label
                          : '${point.label} · ${point.caption}',
                      style: TextStyle(fontSize: 13, color: brand.ink),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Launcher.showOnMap(
                latitude: primary.latitude,
                longitude: primary.longitude,
                label: primary.label,
              ),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Open in maps'),
            ),
          ),
        ],
      ),
    );
  }
}
