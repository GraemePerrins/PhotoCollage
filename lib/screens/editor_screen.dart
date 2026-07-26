import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import '../engine/collage_models.dart';
import '../engine/collage_generator.dart';
import '../services/settings_service.dart';
import '../theme/theme.dart';

class EditorScreen extends StatefulWidget {
  final CollageLayout layout;
  final List<dynamic> selectedPhotos; // Keep original Photos list to allow regeneration
  final String templateName;
  final double canvasWidth;
  final double canvasHeight;
  final bool initialWhiteBorderOn;
  final double initialBorderSizeMm;
  final String selectedOrientation;
  
  final Function(CollageLayout) onLayoutChanged;
  final VoidCallback onBack;
  final Function(String template, List<dynamic> photos) onRegenerate;
  final Function(String) onSelectOrientation;

  const EditorScreen({
    super.key,
    required this.layout,
    required this.selectedPhotos,
    required this.templateName,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.initialWhiteBorderOn,
    required this.initialBorderSizeMm,
    required this.selectedOrientation,
    required this.onLayoutChanged,
    required this.onBack,
    required this.onRegenerate,
    required this.onSelectOrientation,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final SettingsService _settings = SettingsService();

  // Selected item ID for swapping
  String? _selectedItemId;

  // Editor states (local copies)
  late bool _whiteBorderOn;
  late double _borderSizeMm;
  late double _imageScale;
  late Color _canvasBgColor;
  double _cornerRadius = 4.0;
  double _zoomScale = 1.0;

  final FocusNode _focusNode = FocusNode();

  // Rotation states
  bool _isRotating = false;
  double _initialAngle = 0.0;
  double _initialRotation = 0.0;

  @override
  void initState() {
    super.initState();
    _whiteBorderOn = widget.initialWhiteBorderOn;
    _borderSizeMm = widget.initialBorderSizeMm;
    _imageScale = _settings.getImageScale(widget.layout.templateName);
    _canvasBgColor = Color(_settings.getCanvasBgColor(widget.layout.templateName));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onItemTap(String itemId) {
    setState(() {
      if (_selectedItemId == null) {
        // First selection
        _selectedItemId = itemId;
      } else if (_selectedItemId == itemId) {
        // Deselect
        _selectedItemId = null;
      } else {
        // Swap!
        _swapItems(_selectedItemId!, itemId);
        _selectedItemId = null;
      }
    });
  }

  void _removeImage(String itemId) {
    setState(() {
      final index = widget.layout.items.indexWhere((e) => e.id == itemId);
      if (index >= 0) {
        final item = widget.layout.items[index];
        // Remove from selectedPhotos pool in parent
        widget.selectedPhotos.removeWhere((p) => p.url == item.imagePath);
        // Remove from active layout items
        widget.layout.items.removeAt(index);
      }
      _selectedItemId = null;
    });
    // Propagate changes to parent layout
    widget.onLayoutChanged(widget.layout);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Removed image from collage.'),
        backgroundColor: StitchTheme.outline,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _swapItems(String id1, String id2) {
    final list = List<CollageItem>.from(widget.layout.items);
    final idx1 = list.indexWhere((item) => item.id == id1);
    final idx2 = list.indexWhere((item) => item.id == id2);

    if (idx1 >= 0 && idx2 >= 0) {
      final item1 = list[idx1];
      final item2 = list[idx2];

      // Exchange image properties but preserve layout coordinates/rotation/depth
      list[idx1] = item1.copyWith(
        imagePath: item2.imagePath,
        isLocal: item2.isLocal,
      );
      list[idx2] = item2.copyWith(
        imagePath: item1.imagePath,
        isLocal: item1.isLocal,
      );

      final updatedLayout = widget.layout.copyWith(items: list);
      widget.onLayoutChanged(updatedLayout);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Swapped image positions successfully.'),
          backgroundColor: StitchTheme.primaryContainer,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Export collage to a high-res PNG file
  Future<void> _exportCollage() async {
    try {
      // Find RenderRepaintBoundary
      final RenderRepaintBoundary? boundary = 
          _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('RepaintBoundary render object not found.');
      }

      // Convert to Image with pixel ratio 3.0 for high resolution print
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to serialize image to byte data.');
      }

      final pngBytes = byteData.buffer.asUint8List();

      // Retrieve save path from Settings
      String outputDir = _settings.getOutputFolder();
      if (outputDir.isEmpty) {
        final docDir = await getApplicationDocumentsDirectory();
        outputDir = docDir.path;
      }

      // Ensure directory exists
      final dir = Directory(outputDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // Format filename with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final filePath = '$outputDir/collage_$timestamp.png';

      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      // Save to History (mock DB)
      _saveToHistory(filePath);

      // Show success popup
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: StitchTheme.surfaceContainer,
            title: const Text('Export Successful', style: TextStyle(color: StitchTheme.primary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your collage has been saved at:'),
                const SizedBox(height: 8),
                SelectableText(
                  filePath,
                  style: StitchTheme.codeSm(color: StitchTheme.onSurface),
                ),
                const SizedBox(height: 12),
                const Text('Resolution: High-Res Print (3.0x pixel scale)'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: StitchTheme.primary)),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export collage: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _saveToHistory(String path) {
    // Append to list of recent collages saved in SharedPreferences
    final List<String> list = [];
    // Real implementation can add to shared preferences list of exported paths
  }

  @override
  Widget build(BuildContext context) {
    final aspect = widget.layout.width / widget.layout.height;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.delete ||
              event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_selectedItemId != null) {
              _removeImage(_selectedItemId!);
            }
          }
        }
      },
      child: Column(
      children: [
        // Editor Header Tools
        Container(
          height: 48,
          decoration: const BoxDecoration(
            color: StitchTheme.surfaceContainer,
            border: Border(bottom: BorderSide(color: StitchTheme.outlineVariant)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back, size: 20, color: StitchTheme.onSurface),
                    tooltip: 'Back to Photo Library',
                  ),
                  const SizedBox(width: 12),
                  const SizedBox.shrink(),
                  if (_selectedItemId != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _removeImage(_selectedItemId!),
                      icon: const Icon(Icons.delete_outline, color: StitchTheme.error, size: 20),
                      tooltip: 'Remove selected image from collage',
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => widget.onRegenerate(widget.templateName, widget.selectedPhotos),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Regenerate'),
                    style: TextButton.styleFrom(
                      foregroundColor: StitchTheme.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  VerticalDivider(color: StitchTheme.outlineVariant.withOpacity(0.5), indent: 12, endIndent: 12),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _exportCollage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StitchTheme.secondary,
                      foregroundColor: StitchTheme.onSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Export Collage', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Workspace Canvas Area with Right Side Settings Panel
        Expanded(
          child: Row(
            children: [
              // Canvas Workspace (fluid)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedItemId = null;
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: const Color(0xFF141518), // Very dark workspace
                    child: Stack(
                      children: [
                        // Grid background
                        Positioned.fill(
                          child: CustomPaint(
                            painter: DotGridPainter(
                              dotColor: const Color(0xFF8E94A5),
                              spacing: 24.0,
                              dotRadius: 1.2,
                            ),
                          ),
                        ),
                      // Collage Render Area
                      Center(
                        child: InteractiveViewer(
                          maxScale: 3.0,
                          minScale: 0.5,
                          child: Transform.scale(
                            scale: _zoomScale,
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
                                        blurRadius: 24,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: RepaintBoundary(
                                    key: _repaintKey,
                                    child: Container(
                                      width: widget.canvasWidth,
                                      height: widget.canvasHeight,
                                      decoration: BoxDecoration(
                                        color: _canvasBgColor,
                                        border: Border.all(
                                          color: const Color(0xFF64748B), // Clearer border
                                          width: 2.0,
                                        ),
                                      ),
                                      child: Stack(
                                        children: widget.layout.items.map((item) {
                                          final isSelected = _selectedItemId == item.id;
                                          return _buildCollageWidget(item, isSelected);
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      ],
                    ),
                  ),
                ),
              ),

              // Sidebar Control Panel (fixed 260px)
              Container(
                width: 260,
                decoration: const BoxDecoration(
                  color: StitchTheme.surfaceContainerLow,
                  border: Border(left: BorderSide(color: StitchTheme.outlineVariant)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('COLLAGE SETTINGS', style: StitchTheme.labelCaps()),
                                const Icon(Icons.tune, size: 16, color: StitchTheme.primary),
                              ],
                            ),
                    const SizedBox(height: 16),

                    const Text('PAGE ORIENTATION', style: TextStyle(fontSize: 10, color: StitchTheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: StitchTheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: StitchTheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _buildOrientationButton('Portrait')),
                          Expanded(child: _buildOrientationButton('Landscape')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Border switch
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('White Border', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        Switch(
                          value: _whiteBorderOn,
                          activeColor: StitchTheme.primary,
                          onChanged: (val) async {
                            setState(() => _whiteBorderOn = val);
                            await _settings.setWhiteBorderOn(widget.layout.templateName, val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Border size slider
                    if (_whiteBorderOn) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('BORDER SIZE', style: TextStyle(fontSize: 10, color: StitchTheme.onSurfaceVariant)),
                          Text('${_borderSizeMm.toStringAsFixed(1)} mm', style: const TextStyle(fontSize: 10, color: StitchTheme.primary)),
                        ],
                      ),
                      Slider(
                        value: _borderSizeMm,
                        min: 0.5,
                        max: 5.0,
                        divisions: 9,
                        activeColor: StitchTheme.primary,
                        onChanged: (val) async {
                          setState(() => _borderSizeMm = val);
                          await _settings.setBorderSizeMm(widget.layout.templateName, val);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Image scale slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('IMAGE SCALE', style: TextStyle(fontSize: 10, color: StitchTheme.onSurfaceVariant)),
                        Text('${(_imageScale * 100).toInt()}%', style: const TextStyle(fontSize: 10, color: StitchTheme.primary)),
                      ],
                    ),
                    Slider(
                      value: _imageScale,
                      min: 0.4,
                      max: 1.0,
                      divisions: 12,
                      activeColor: StitchTheme.primary,
                      onChanged: (val) => setState(() => _imageScale = val),
                      onChangeEnd: (val) async {
                        await _settings.setImageScale(widget.layout.templateName, val);
                        widget.onRegenerate(widget.layout.templateName, widget.selectedPhotos);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Corner radius slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('CORNER RADIUS', style: TextStyle(fontSize: 10, color: StitchTheme.onSurfaceVariant)),
                        Text('${_cornerRadius.toInt()} px', style: const TextStyle(fontSize: 10, color: StitchTheme.primary)),
                      ],
                    ),
                    Slider(
                      value: _cornerRadius,
                      min: 0.0,
                      max: 24.0,
                      divisions: 24,
                      activeColor: StitchTheme.primary,
                      onChanged: (val) => setState(() => _cornerRadius = val),
                    ),
                    const SizedBox(height: 20),
                    const Text('COLLAGE BACKGROUND COLOUR', style: TextStyle(fontSize: 10, color: StitchTheme.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    Center(
                      child: SizedBox(
                        width: 120,
                        height: 36,
                        child: GestureDetector(
                          onTap: () async {
                            final pickedColor = await showDialog<Color>(
                              context: context,
                              builder: (context) => _ColorPickerDialog(initialColor: _canvasBgColor),
                            );
                            if (pickedColor != null) {
                              setState(() => _canvasBgColor = pickedColor);
                              await _settings.setCanvasBgColor(widget.layout.templateName, pickedColor.value);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _canvasBgColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _canvasBgColor == Colors.white ? Colors.grey[400]! : StitchTheme.outlineVariant,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: StitchTheme.outlineVariant),
                    const SizedBox(height: 12),
                    const Text('GESTURE INSTRUCTIONS', style: TextStyle(fontSize: 10, color: StitchTheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    _buildInstructionRow(
                      graphic: const SwapInstructionGraphic(),
                      title: 'Swap Images',
                      desc: 'Tap two different images to exchange their locations.',
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionRow(
                      graphic: const MoveInstructionGraphic(),
                      title: 'Move Images',
                      desc: 'Click and drag any image to adjust its position.',
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionRow(
                      graphic: const RotateInstructionGraphic(),
                      title: 'Rotate Images',
                      desc: 'Hold Ctrl + drag with Left Mouse to rotate about center.',
                    ),
                    if (_selectedItemId != null) ...[
                      const SizedBox(height: 20),
                      const Divider(color: StitchTheme.outlineVariant),
                      const SizedBox(height: 12),
                      const Text('SELECTED IMAGE TOOLS', style: TextStyle(fontSize: 10, color: StitchTheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _removeImage(_selectedItemId!),
                          icon: const Icon(Icons.delete_outline, size: 16, color: StitchTheme.error),
                          label: const Text('Remove Photo', style: TextStyle(color: StitchTheme.error, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: StitchTheme.error),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

                    // Zoom Box controls
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: StitchTheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: StitchTheme.outlineVariant),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            onPressed: () => setState(() => _zoomScale = max(0.5, _zoomScale - 0.1)),
                            icon: const Icon(Icons.remove, size: 20),
                          ),
                          Text('${(_zoomScale * 100).toInt()}%', style: StitchTheme.codeSm(color: StitchTheme.onSurface)),
                          IconButton(
                            onPressed: () => setState(() => _zoomScale = min(3.0, _zoomScale + 0.1)),
                            icon: const Icon(Icons.add, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildOrientationButton(String orient) {
    final isSelected = widget.selectedOrientation == orient;
    return GestureDetector(
      onTap: () {
        widget.onSelectOrientation(orient);
        widget.onRegenerate(widget.templateName, widget.selectedPhotos);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? StitchTheme.primaryContainer.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          orient,
          style: StitchTheme.labelCaps(
            color: isSelected ? StitchTheme.primary : StitchTheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionRow({
    required Widget graphic,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        graphic,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: StitchTheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 10,
                  color: StitchTheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollageWidget(CollageItem item, bool isSelected) {
    // Math coordinates scaled from normalized [0..1] to canvas dimensions
    final double left = item.x * widget.canvasWidth;
    final double top = item.y * widget.canvasHeight;
    final double width = item.width * widget.canvasWidth;
    final double height = item.height * widget.canvasHeight;

    // Convert border size in mm to pixels
    // Assume standard 96 DPI, so 1 inch = 25.4 mm = 96 pixels.
    // 1 mm = 3.78 pixels.
    final double borderPx = _whiteBorderOn ? _borderSizeMm * 3.78 : 0.0;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () => _onItemTap(item.id),
        onPanStart: (details) {
          setState(() {
            _selectedItemId = item.id;
          });
          final isControlPressed = HardwareKeyboard.instance.isControlPressed;
          if (isControlPressed) {
            _isRotating = true;
            final double localCenterX = width / 2;
            final double localCenterY = height / 2;
            final double dx = details.localPosition.dx - localCenterX;
            final double dy = details.localPosition.dy - localCenterY;
            _initialAngle = atan2(dy, dx);
            _initialRotation = item.rotation;
          } else {
            _isRotating = false;
          }
        },
        onPanUpdate: (details) {
          if (_isRotating) {
            final double localCenterX = width / 2;
            final double localCenterY = height / 2;
            final double dx = details.localPosition.dx - localCenterX;
            final double dy = details.localPosition.dy - localCenterY;
            final double currentAngle = atan2(dy, dx);
            final double angleDiffRad = currentAngle - _initialAngle;
            final double angleDiffDeg = angleDiffRad * (180.0 / pi);
            final index = widget.layout.items.indexWhere((e) => e.id == item.id);
            if (index >= 0) {
              setState(() {
                final current = widget.layout.items[index];
                widget.layout.items[index] = current.copyWith(rotation: _initialRotation + angleDiffDeg);
              });
            }
          } else {
            final double deltaX = (details.delta.dx / _zoomScale) / widget.canvasWidth;
            final double deltaY = (details.delta.dy / _zoomScale) / widget.canvasHeight;
            final index = widget.layout.items.indexWhere((e) => e.id == item.id);
            if (index >= 0) {
              setState(() {
                final current = widget.layout.items[index];
                double newX = (current.x + deltaX).clamp(0.0, 1.0 - current.width);
                double newY = (current.y + deltaY).clamp(0.0, 1.0 - current.height);
                widget.layout.items[index] = current.copyWith(x: newX, y: newY);
              });
            }
          }
        },
        onPanEnd: (_) {
          widget.onLayoutChanged(widget.layout);
          _isRotating = false;
        },
        onPanCancel: () {
          _isRotating = false;
        },
        child: Transform.rotate(
          angle: item.rotation * (pi / 180.0), // degrees to radians
          child: Container(
            decoration: BoxDecoration(
              color: _whiteBorderOn ? Colors.white : StitchTheme.surfaceContainerLow,
              border: Border.all(
                color: isSelected 
                    ? (_whiteBorderOn ? StitchTheme.primary : Colors.white) 
                    : Colors.transparent,
                width: isSelected ? 3 : 0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            padding: EdgeInsets.all(borderPx),
            child: Container(
              color: Colors.white,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_cornerRadius),
                child: Stack(
                  children: [
                    // The Image
                    Positioned.fill(
                      child: Image.file(
                        File(item.imagePath),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.image, color: StitchTheme.outline),
                        ),
                      ),
                    ),

                    // Hover selection highlights
                    if (isSelected)
                      Positioned.fill(
                        child: Container(
                          color: StitchTheme.primaryContainer.withOpacity(0.3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const _ColorPickerDialog({required this.initialColor});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = 0.5; // Default brightness to 50%
  }

  Color _getCurrentColor() {
    return HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
  }

  void _updateColorFromPosition(Offset localPos, double radius) {
    final double centerX = radius;
    final double centerY = radius;
    final double dx = localPos.dx - centerX;
    final double dy = localPos.dy - centerY;
    
    final double distance = sqrt(dx * dx + dy * dy);
    final double saturation = (distance / radius).clamp(0.0, 1.0);
    
    double angle = atan2(dy, dx);
    double hue = angle * (180.0 / pi);
    if (hue < 0) hue += 360.0;

    setState(() {
      _hue = hue;
      _saturation = saturation;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _getCurrentColor();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: const Color(0xFF201F1F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF353534)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header with X
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Background Colour',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20, color: Colors.white70),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF353534), height: 1),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
              child: Column(
                children: [
                  // Color Selection Circle (Wheel)
                  Center(
                    child: SizedBox(
                      width: 180,
                      height: 180,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double radius = constraints.maxWidth / 2;
                          final double angleRad = _hue * (pi / 180.0);
                          final double indicatorX = radius + cos(angleRad) * _saturation * radius;
                          final double indicatorY = radius + sin(angleRad) * _saturation * radius;

                          return GestureDetector(
                            onPanUpdate: (details) {
                              _updateColorFromPosition(details.localPosition, radius);
                            },
                            onPanDown: (details) {
                              _updateColorFromPosition(details.localPosition, radius);
                            },
                            child: Stack(
                              children: [
                                // Painted Color Wheel
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _ColorWheelPainter(),
                                  ),
                                ),
                                // Selection cursor indicator
                                Positioned(
                                  left: indicatorX - 8,
                                  top: indicatorY - 8,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.0),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 4,
                                        )
                                      ],
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
                  const SizedBox(height: 24),

                  // Brightness Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('BRIGHTNESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF918FA1))),
                      Text('${(_value * 100).toInt()}%', style: const TextStyle(fontSize: 10, color: StitchTheme.primary)),
                    ],
                  ),
                  Slider(
                    value: _value,
                    min: 0.0,
                    max: 1.0,
                    activeColor: StitchTheme.primary,
                    onChanged: (val) => setState(() => _value = val),
                  ),
                  const SizedBox(height: 12),

                  // Active Selected Color Preview Strip
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: currentColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF353534)),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Color(0xFF353534), height: 1),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(currentColor),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC3C0FF),
                      foregroundColor: const Color(0xFF1D00A5),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(radius, radius);

    final List<Color> colors = [
      const Color(0xFFFF0000), // Red
      const Color(0xFFFFFF00), // Yellow
      const Color(0xFF00FF00), // Green
      const Color(0xFF00FFFF), // Cyan
      const Color(0xFF0000FF), // Blue
      const Color(0xFFFF00FF), // Magenta
      const Color(0xFFFF0000), // Red
    ];

    final paint = Paint()
      ..shader = SweepGradient(colors: colors).createShader(ui.Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);

    // Fade to white at the center (saturation)
    final whitePaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, Colors.white.withOpacity(0.0)],
        stops: const [0.0, 1.0],
      ).createShader(ui.Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom Instruction Graphics & Painters
class SwapInstructionGraphic extends StatelessWidget {
  const SwapInstructionGraphic({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: StitchTheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
        color: StitchTheme.surfaceContainerHigh,
      ),
      child: CustomPaint(
        painter: _SwapGraphicPainter(),
      ),
    );
  }
}

class MoveInstructionGraphic extends StatelessWidget {
  const MoveInstructionGraphic({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: StitchTheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
        color: StitchTheme.surfaceContainerHigh,
      ),
      child: CustomPaint(
        painter: _MoveGraphicPainter(),
      ),
    );
  }
}

class RotateInstructionGraphic extends StatelessWidget {
  const RotateInstructionGraphic({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: StitchTheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
        color: StitchTheme.surfaceContainerHigh,
      ),
      child: CustomPaint(
        painter: _RotateGraphicPainter(),
      ),
    );
  }
}

class _SwapGraphicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = StitchTheme.onSurfaceVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    // Draw two boxes side by side
    canvas.drawRect(const ui.Rect.fromLTWH(4, 11, 10, 10), paint);
    canvas.drawRect(const ui.Rect.fromLTWH(18, 11, 10, 10), paint);
    
    // Draw double swap arrow between them
    final arrowPaint = Paint()
      ..color = StitchTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    
    // Left-to-right arrow
    canvas.drawLine(const Offset(11, 7), const Offset(21, 7), arrowPaint);
    canvas.drawLine(const Offset(19, 5), const Offset(21, 7), arrowPaint);
    canvas.drawLine(const Offset(19, 9), const Offset(21, 7), arrowPaint);
    
    // Right-to-left arrow
    canvas.drawLine(const Offset(21, 25), const Offset(11, 25), arrowPaint);
    canvas.drawLine(const Offset(13, 23), const Offset(11, 25), arrowPaint);
    canvas.drawLine(const Offset(13, 27), const Offset(11, 25), arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MoveGraphicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = StitchTheme.onSurfaceVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    // Draw a small box in the center
    final rect = ui.Rect.fromLTWH(9, 9, 14, 14);
    canvas.drawRect(rect, paint);
    
    // Draw 4 directional arrows on the box
    // Up arrow
    canvas.drawLine(const Offset(16, 9), const Offset(16, 4), paint);
    canvas.drawLine(const Offset(14, 6), const Offset(16, 4), paint);
    canvas.drawLine(const Offset(18, 6), const Offset(16, 4), paint);
    
    // Down arrow
    canvas.drawLine(const Offset(16, 23), const Offset(16, 28), paint);
    canvas.drawLine(const Offset(14, 26), const Offset(16, 28), paint);
    canvas.drawLine(const Offset(18, 26), const Offset(16, 28), paint);
    
    // Left arrow
    canvas.drawLine(const Offset(9, 16), const Offset(4, 16), paint);
    canvas.drawLine(const Offset(6, 14), const Offset(4, 16), paint);
    canvas.drawLine(const Offset(6, 18), const Offset(4, 16), paint);
    
    // Right arrow
    canvas.drawLine(const Offset(23, 16), const Offset(28, 16), paint);
    canvas.drawLine(const Offset(26, 14), const Offset(28, 16), paint);
    canvas.drawLine(const Offset(26, 18), const Offset(28, 16), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RotateGraphicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = StitchTheme.onSurfaceVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    // Draw a small rotated box in the center
    canvas.save();
    canvas.translate(16, 16);
    canvas.rotate(0.4); // rotate slightly
    final rect = ui.Rect.fromCenter(center: Offset.zero, width: 12, height: 12);
    canvas.drawRect(rect, paint);
    canvas.restore();
    
    // Draw a curved rotation arrow outline around it
    final arrowPaint = Paint()
      ..color = StitchTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    final arcRect = ui.Rect.fromCircle(center: const Offset(16, 16), radius: 10);
    canvas.drawArc(arcRect, -1.2, 4.0, false, arrowPaint);
    
    // Draw arrowhead
    canvas.save();
    canvas.translate(24, 11);
    canvas.rotate(0.8);
    canvas.drawLine(Offset.zero, const Offset(-3, 3), arrowPaint);
    canvas.drawLine(Offset.zero, const Offset(-3, -3), arrowPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
