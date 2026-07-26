import 'dart:math';
import '../services/settings_service.dart';
import 'collage_models.dart';

class CollageGenerator {
  static final Random _random = Random();
  static final SettingsService _settings = SettingsService();

  static CollageLayout generate({
    required List<PhotoItem> photos,
    required String templateName,
    required double canvasWidth,
    required double canvasHeight,
  }) {
    if (photos.isEmpty) {
      return CollageLayout(
        templateName: templateName,
        width: canvasWidth,
        height: canvasHeight,
        items: [],
      );
    }

    final double imageScale = _settings.getImageScale(templateName);
    final double u = canvasWidth / 25.0; // Base unit (40px on 1000px width canvas)

    List<CollageItem> items = [];

    // Precompute item sizes (normalized width and height) for each photo
    List<_SizedPhoto> sizedPhotos = [];
    for (var photo in photos) {
      double w, h;
      if (photo.isLandscape) {
        w = 7.0 * u * imageScale;
        h = 4.0 * u * imageScale;
      } else {
        w = 4.0 * u * imageScale;
        h = 7.0 * u * imageScale;
      }

      sizedPhotos.add(_SizedPhoto(
        photo: photo,
        width: w / canvasWidth,
        height: h / canvasHeight,
      ));
    }

    switch (templateName.toLowerCase()) {
      case 'basic grid':
        items = _generateBasicGrid(sizedPhotos);
        break;
      case 'random collage':
        items = _generateRandomCollage(sizedPhotos);
        break;
      case 'throw down':
        items = _generateThrowDown(sizedPhotos);
        break;
      case 'circular spiral':
      case 'circular':
        items = _generateCircularSpiral(sizedPhotos);
        break;
      case 'tiled varied':
      case 'titled':
        items = _generateTiledVaried(sizedPhotos);
        break;
      default:
        items = _generateBasicGrid(sizedPhotos);
    }

    return CollageLayout(
      templateName: templateName,
      width: canvasWidth,
      height: canvasHeight,
      items: items,
    );
  }

  // 1. Basic Grid Layout (Flow Row Packing abutting next to each other)
  static List<CollageItem> _generateBasicGrid(List<_SizedPhoto> photos) {
    final int count = photos.length;
    List<_PlacedPhoto> placed = [];

    double currentX = 0.0;
    double currentY = 0.0;
    double maxRowHeight = 0.0;
    final double gap = 0.015; // 1.5% gap between items

    List<_PlacedPhoto> currentRow = [];

    for (int i = 0; i < count; i++) {
      final photoW = photos[i].width;
      final photoH = photos[i].height;

      // If it doesn't fit on this row, wrap
      if (currentX + photoW > 1.0 && currentX > 0) {
        _centerRow(currentRow, gap);
        placed.addAll(currentRow);
        currentRow.clear();

        currentY += maxRowHeight + gap;
        currentX = 0.0;
        maxRowHeight = 0.0;
      }

      currentRow.add(_PlacedPhoto(
        photo: photos[i].photo,
        x: currentX,
        y: currentY,
        width: photoW,
        height: photoH,
        index: i,
      ));

      currentX += photoW + gap;
      maxRowHeight = max(maxRowHeight, photoH);
    }

    if (currentRow.isNotEmpty) {
      _centerRow(currentRow, gap);
      placed.addAll(currentRow);
    }

    final double totalHeight = currentY + maxRowHeight;
    final double scaleY = totalHeight > 1.0 ? (1.0 / totalHeight) : 1.0;
    final double verticalOffset = totalHeight < 1.0 ? ((1.0 - totalHeight) / 2) : 0.0;

    List<CollageItem> items = [];
    for (var p in placed) {
      double finalY = p.y * scaleY + verticalOffset;
      items.add(CollageItem(
        id: p.photo.id,
        imagePath: p.photo.url,
        x: p.x.clamp(0.0, 1.0 - p.width),
        y: finalY.clamp(0.0, 1.0 - p.height),
        width: p.width,
        height: p.height,
        rotation: 0.0,
        zIndex: p.index,
        isLocal: p.photo.isLocal,
      ));
    }

    // Run repulsion step to distribute any overlaps uniformly
    items = _resolveCollisions(items: items, repulsionFactor: 0.8, iterations: 20);

    return items;
  }

  static void _centerRow(List<_PlacedPhoto> row, double gap) {
    if (row.isEmpty) return;
    final double lastPhotoRight = row.last.x + row.last.width;
    final double emptySpace = 1.0 - lastPhotoRight;
    if (emptySpace > 0) {
      final double offset = emptySpace / 2;
      for (var i = 0; i < row.length; i++) {
        row[i] = row[i].copyWith(x: row[i].x + offset);
      }
    }
  }

  // 2. Random Collage Layout
  static List<CollageItem> _generateRandomCollage(List<_SizedPhoto> photos) {
    List<CollageItem> items = [];
    final int count = photos.length;

    // Initial random positions
    for (int i = 0; i < count; i++) {
      final photoW = photos[i].width;
      final photoH = photos[i].height;

      final double x = _random.nextDouble() * (1.0 - photoW);
      final double y = _random.nextDouble() * (1.0 - photoH);

      items.add(CollageItem(
        id: photos[i].photo.id,
        imagePath: photos[i].photo.url,
        x: x,
        y: y,
        width: photoW,
        height: photoH,
        rotation: 0.0,
        zIndex: i,
        isLocal: photos[i].photo.isLocal,
      ));
    }

    // Resolve overlaps
    items = _resolveCollisions(items: items, repulsionFactor: 1.0, iterations: 60);

    // Apply small rotation after overlap resolution
    for (int i = 0; i < count; i++) {
      final double rotation = (_random.nextDouble() * 20.0) - 10.0; // -10 to 10 degrees
      items[i] = items[i].copyWith(rotation: rotation);
    }

    return items;
  }

  // 3. Throw Down Layout
  static List<CollageItem> _generateThrowDown(List<_SizedPhoto> photos) {
    List<CollageItem> items = [];
    final int count = photos.length;

    // Place randomly centered in the middle area [0.15, 0.85]
    for (int i = 0; i < count; i++) {
      final photoW = photos[i].width;
      final photoH = photos[i].height;

      final double minCenterX = 0.25;
      final double maxCenterX = 0.75;
      final double minCenterY = 0.25;
      final double maxCenterY = 0.75;

      final double centerX = minCenterX + _random.nextDouble() * (maxCenterX - minCenterX);
      final double centerY = minCenterY + _random.nextDouble() * (maxCenterY - minCenterY);

      final double x = (centerX - photoW / 2).clamp(0.0, 1.0 - photoW);
      final double y = (centerY - photoH / 2).clamp(0.0, 1.0 - photoH);

      items.add(CollageItem(
        id: photos[i].photo.id,
        imagePath: photos[i].photo.url,
        x: x,
        y: y,
        width: photoW,
        height: photoH,
        rotation: 0.0,
        zIndex: i,
        isLocal: photos[i].photo.isLocal,
      ));
    }

    // Resolve overlaps with slightly weaker repulsion for organic stacking
    items = _resolveCollisions(items: items, repulsionFactor: 0.65, iterations: 40);

    // Apply larger rotation
    for (int i = 0; i < count; i++) {
      final double rotation = (_random.nextDouble() * 40.0) - 20.0; // -20 to 20 degrees
      items[i] = items[i].copyWith(rotation: rotation);
    }

    return items;
  }

  // 4. Circular Spiral Layout
  static List<CollageItem> _generateCircularSpiral(List<_SizedPhoto> photos) {
    List<CollageItem> items = [];
    final int count = photos.length;

    final double thetaStep = 2.4;

    for (int i = 0; i < count; i++) {
      final progress = i / max(1, count - 1);
      final double r = 0.05 + 0.35 * progress;
      final double theta = i * thetaStep;

      final photoW = photos[i].width;
      final photoH = photos[i].height;

      final double centerX = 0.5 + r * cos(theta);
      final double centerY = 0.5 + r * sin(theta);

      final double x = (centerX - photoW / 2).clamp(0.0, 1.0 - photoW);
      final double y = (centerY - photoH / 2).clamp(0.0, 1.0 - photoH);

      items.add(CollageItem(
        id: photos[i].photo.id,
        imagePath: photos[i].photo.url,
        x: x,
        y: y,
        width: photoW,
        height: photoH,
        rotation: 0.0,
        zIndex: i,
        isLocal: photos[i].photo.isLocal,
      ));
    }

    // Resolve collisions to push out spiral items organically
    items = _resolveCollisions(items: items, repulsionFactor: 1.0, iterations: 40);

    // Apply tangent aligned rotation
    for (int i = 0; i < count; i++) {
      final double theta = i * thetaStep;
      final double tangentAngle = (theta + pi / 2) * (180.0 / pi);
      final double rotation = tangentAngle + (_random.nextDouble() * 16.0 - 8.0);
      items[i] = items[i].copyWith(rotation: rotation);
    }

    return items;
  }

  // 5. Tiled Varied (Center inside partitioned BSP cells)
  static List<CollageItem> _generateTiledVaried(List<_SizedPhoto> photos) {
    final int count = photos.length;
    List<Rect> boxes = [];

    _partition(
      rect: const Rect(0.05, 0.05, 0.9, 0.9),
      count: count,
      outputList: boxes,
    );

    if (boxes.length < count) {
      return _generateBasicGrid(photos);
    }

    List<CollageItem> items = [];
    for (int i = 0; i < count; i++) {
      final box = boxes[i];
      final photoW = photos[i].width;
      final photoH = photos[i].height;

      // Center the fixed-sized photo inside the BSP cell
      final double x = box.x + (box.width - photoW) / 2;
      final double y = box.y + (box.height - photoH) / 2;

      items.add(CollageItem(
        id: photos[i].photo.id,
        imagePath: photos[i].photo.url,
        x: x.clamp(0.0, 1.0 - photoW),
        y: y.clamp(0.0, 1.0 - photoH),
        width: photoW,
        height: photoH,
        rotation: 0.0,
        zIndex: i,
        isLocal: photos[i].photo.isLocal,
      ));
    }

    // Resolve grid overflows slightly
    items = _resolveCollisions(items: items, repulsionFactor: 0.8, iterations: 30);

    return items;
  }

  // Recursive partition function for Tiled Varied layout
  static void _partition({
    required Rect rect,
    required int count,
    required List<Rect> outputList,
  }) {
    if (count <= 1) {
      outputList.add(rect);
      return;
    }

    final bool splitVertically = rect.width > rect.height;
    final int countLeft = count ~/ 2;
    final int countRight = count - countLeft;
    final double splitRatio = countLeft / count;

    final double dev = (_random.nextDouble() * 0.08) - 0.04;
    final double finalRatio = (splitRatio + dev).clamp(0.25, 0.75);

    if (splitVertically) {
      final double leftWidth = rect.width * finalRatio;
      final double rightWidth = rect.width - leftWidth;

      _partition(
        rect: Rect(rect.x, rect.y, leftWidth, rect.height),
        count: countLeft,
        outputList: outputList,
      );
      _partition(
        rect: Rect(rect.x + leftWidth, rect.y, rightWidth, rect.height),
        count: countRight,
        outputList: outputList,
      );
    } else {
      final double topHeight = rect.height * finalRatio;
      final double bottomHeight = rect.height - topHeight;

      _partition(
        rect: Rect(rect.x, rect.y, rect.width, topHeight),
        count: countLeft,
        outputList: outputList,
      );
      _partition(
        rect: Rect(rect.x, rect.y + topHeight, rect.width, bottomHeight),
        count: countRight,
        outputList: outputList,
      );
    }
  }

  // Bounding box Collision Avoidance Repulsion step
  static List<CollageItem> _resolveCollisions({
    required List<CollageItem> items,
    double repulsionFactor = 1.0,
    int iterations = 50,
  }) {
    List<CollageItem> resolved = List.from(items);
    final int count = resolved.length;

    for (int iter = 0; iter < iterations; iter++) {
      bool changed = false;
      for (int i = 0; i < count; i++) {
        for (int j = i + 1; j < count; j++) {
          final a = resolved[i];
          final b = resolved[j];

          // Compute overlap in normalized coordinates
          final double overlapX = _getOverlap(a.x, a.width, b.x, b.width);
          final double overlapY = _getOverlap(a.y, a.height, b.y, b.height);

          if (overlapX > 0 && overlapY > 0) {
            changed = true;
            // Push apart along the axis of minimum penetration
            if (overlapX < overlapY) {
              final double push = overlapX * 0.5 * repulsionFactor;
              final double sign = (a.x + a.width / 2) < (b.x + b.width / 2) ? -1.0 : 1.0;
              resolved[i] = a.copyWith(x: (a.x + sign * push).clamp(0.0, 1.0 - a.width));
              resolved[j] = b.copyWith(x: (b.x - sign * push).clamp(0.0, 1.0 - b.width));
            } else {
              final double push = overlapY * 0.5 * repulsionFactor;
              final double sign = (a.y + a.height / 2) < (b.y + b.height / 2) ? -1.0 : 1.0;
              resolved[i] = a.copyWith(y: (a.y + sign * push).clamp(0.0, 1.0 - a.height));
              resolved[j] = b.copyWith(y: (b.y - sign * push).clamp(0.0, 1.0 - b.height));
            }
          }
        }
      }
      if (!changed) break; // Early exit if no overlaps remain
    }
    return resolved;
  }

  static double _getOverlap(double pos1, double size1, double pos2, double size2) {
    final double min1 = pos1;
    final double max1 = pos1 + size1;
    final double min2 = pos2;
    final double max2 = pos2 + size2;
    final double minMax = min(max1, max2);
    final double maxMin = max(min1, min2);
    return max(0.0, minMax - maxMin);
  }
}

class _SizedPhoto {
  final PhotoItem photo;
  final double width;
  final double height;

  _SizedPhoto({
    required this.photo,
    required this.width,
    required this.height,
  });
}

class Rect {
  final double x;
  final double y;
  final double width;
  final double height;

  const Rect(this.x, this.y, this.width, this.height);
}

class _PlacedPhoto {
  final PhotoItem photo;
  final double x;
  final double y;
  final double width;
  final double height;
  final int index;

  _PlacedPhoto({
    required this.photo,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.index,
  });

  _PlacedPhoto copyWith({double? x, double? y}) {
    return _PlacedPhoto(
      photo: photo,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width,
      height: height,
      index: index,
    );
  }
}
