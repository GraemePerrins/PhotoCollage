class CollageItem {
  final String id;
  final String imagePath;
  final double x; // Normalized X coordinate (0.0 to 1.0)
  final double y; // Normalized Y coordinate (0.0 to 1.0)
  final double width; // Normalized width (0.0 to 1.0)
  final double height; // Normalized height (0.0 to 1.0)
  final double rotation; // Rotation angle in degrees
  final int zIndex; // Layer order (lower is below)
  final bool isLocal;

  CollageItem({
    required this.id,
    required this.imagePath,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotation,
    required this.zIndex,
    this.isLocal = false,
  });

  CollageItem copyWith({
    String? id,
    String? imagePath,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    int? zIndex,
    bool? isLocal,
  }) {
    return CollageItem(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      zIndex: zIndex ?? this.zIndex,
      isLocal: isLocal ?? this.isLocal,
    );
  }
}

class CollageLayout {
  final String templateName;
  final double width; // Output aspect ratio width
  final double height; // Output aspect ratio height
  final List<CollageItem> items;

  CollageLayout({
    required this.templateName,
    required this.width,
    required this.height,
    required this.items,
  });

  CollageLayout copyWith({
    String? templateName,
    double? width,
    double? height,
    List<CollageItem>? items,
  }) {
    return CollageLayout(
      templateName: templateName ?? this.templateName,
      width: width ?? this.width,
      height: height ?? this.height,
      items: items ?? this.items,
    );
  }
}

class PhotoItem {
  final String id;
  final String url;
  final String title;
  final String albumId;
  final bool isLocal;
  final double width;
  final double height;

  PhotoItem({
    required this.id,
    required this.url,
    required this.title,
    required this.albumId,
    this.isLocal = true,
    this.width = 800.0,
    this.height = 600.0,
  });

  bool get isLandscape => width >= height;

  PhotoItem copyWith({
    String? id,
    String? url,
    String? title,
    String? albumId,
    bool? isLocal,
    double? width,
    double? height,
  }) {
    return PhotoItem(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      albumId: albumId ?? this.albumId,
      isLocal: isLocal ?? this.isLocal,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}
