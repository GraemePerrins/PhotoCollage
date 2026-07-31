import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../engine/collage_models.dart';
import '../services/settings_service.dart';
import '../theme/theme.dart';

class PhotoPickerScreen extends StatefulWidget {
  final List<PhotoItem> selectedPhotos;
  final Function(List<PhotoItem>) onPhotosChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const PhotoPickerScreen({
    super.key,
    required this.selectedPhotos,
    required this.onPhotosChanged,
    required this.onBack,
    required this.onNext,
  });

  @override
  State<PhotoPickerScreen> createState() => _PhotoPickerScreenState();
}

class _PhotoPickerScreenState extends State<PhotoPickerScreen> {
  final SettingsService _settings = SettingsService();

  List<String> _selectedFolderPaths = [];
  final Map<String, List<PhotoItem>> _folderItems = {};
  final Map<String, Size> _sizeCache = {};
  bool _isLoading = false;
  int _loadingGeneration = 0;

  final ScrollController _trayScrollController = ScrollController();
  final Set<String> _collapsedFolders = {};

  @override
  void initState() {
    super.initState();
    _loadSavedFolders();
  }

  @override
  void dispose() {
    _trayScrollController.dispose();
    super.dispose();
  }

  /// Fast binary header-based size reader for JPEG, PNG, WebP, and BMP images.
  /// Runs in microseconds without decoding pixel buffers into memory.
  Future<Size> _getImageSizeFromHeader(String path) async {
    if (_sizeCache.containsKey(path)) {
      return _sizeCache[path]!;
    }
    try {
      final file = File(path);
      final length = await file.length();
      if (length < 30) return const Size(800.0, 600.0);

      final randomAccess = await file.open(mode: FileMode.read);
      try {
        final bytes = await randomAccess.read(min(1024, length));
        if (bytes.length >= 24) {
          // PNG: 89 50 4E 47 0D 0A 1A 0A
          if (bytes[0] == 0x89 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x4E &&
              bytes[3] == 0x47) {
            final width = (bytes[16] << 24) |
                (bytes[17] << 16) |
                (bytes[18] << 8) |
                bytes[19];
            final height = (bytes[20] << 24) |
                (bytes[21] << 16) |
                (bytes[22] << 8) |
                bytes[23];
            if (width > 0 && height > 0) {
              return Size(width.toDouble(), height.toDouble());
            }
          }

          // BMP: 42 4D ('BM')
          if (bytes[0] == 0x42 && bytes[1] == 0x4D && bytes.length >= 26) {
            final width = bytes[18] |
                (bytes[19] << 8) |
                (bytes[20] << 16) |
                (bytes[21] << 24);
            final height = (bytes[22] |
                    (bytes[23] << 8) |
                    (bytes[24] << 16) |
                    (bytes[25] << 24))
                .abs();
            if (width > 0 && height > 0) {
              return Size(width.toDouble(), height.toDouble());
            }
          }

          // WebP: RIFF .... WEBP
          if (bytes[0] == 0x52 &&
              bytes[1] == 0x49 &&
              bytes[2] == 0x46 &&
              bytes[3] == 0x46 &&
              bytes[8] == 0x57 &&
              bytes[9] == 0x45 &&
              bytes[10] == 0x42 &&
              bytes[11] == 0x50 &&
              bytes.length >= 30) {
            final chunkType = String.fromCharCodes(bytes.sublist(12, 16));
            if (chunkType == 'VP8X' && bytes.length >= 30) {
              final w = 1 + (bytes[24] | (bytes[25] << 8) | (bytes[26] << 16));
              final h = 1 + (bytes[27] | (bytes[28] << 8) | (bytes[29] << 16));
              return Size(w.toDouble(), h.toDouble());
            } else if (chunkType == 'VP8 ' && bytes.length >= 30) {
              final w = (bytes[26] | (bytes[27] << 8)) & 0x3FFF;
              final h = (bytes[28] | (bytes[29] << 8)) & 0x3FFF;
              return Size(w.toDouble(), h.toDouble());
            } else if (chunkType == 'VP8L' && bytes.length >= 25) {
              final w = 1 + ((bytes[21] | ((bytes[22] & 0x3F) << 8)));
              final h = 1 +
                  (((bytes[22] >> 6) |
                      (bytes[23] << 2) |
                      ((bytes[24] & 0x03) << 10)));
              return Size(w.toDouble(), h.toDouble());
            }
          }

          // JPEG: FF D8 FF
          if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
            int offset = 2;
            while (offset < bytes.length - 8) {
              if (bytes[offset] != 0xFF) {
                offset++;
                continue;
              }
              final marker = bytes[offset + 1];
              // SOF0..SOF3, SOF5..SOF7, SOF9..SOF11, SOF13..SOF15
              if ((marker >= 0xC0 && marker <= 0xC3) ||
                  (marker >= 0xC5 && marker <= 0xC7) ||
                  (marker >= 0xC9 && marker <= 0xCB) ||
                  (marker >= 0xCD && marker <= 0xCF)) {
                if (offset + 8 < bytes.length) {
                  final height = (bytes[offset + 5] << 8) | bytes[offset + 6];
                  final width = (bytes[offset + 7] << 8) | bytes[offset + 8];
                  if (width > 0 && height > 0) {
                    return Size(width.toDouble(), height.toDouble());
                  }
                }
                break;
              } else {
                if (offset + 3 < bytes.length) {
                  final blockLength =
                      (bytes[offset + 2] << 8) | bytes[offset + 3];
                  offset += 2 + blockLength;
                } else {
                  break;
                }
              }
            }
          }
        }
      } finally {
        await randomAccess.close();
      }
    } catch (_) {}
    return const Size(800.0, 600.0);
  }

  Future<void> _loadSavedFolders() async {
    setState(() => _isLoading = true);
    _loadingGeneration++;
    final int currentGen = _loadingGeneration;
    final saved = _settings.getSelectedFolders();
    _selectedFolderPaths = List.from(saved);

    final Map<String, List<PhotoItem>> loadedFolderItems = {};

    for (var path in _selectedFolderPaths) {
      if (currentGen != _loadingGeneration) return;
      final dir = Directory(path);
      if (await dir.exists()) {
        try {
          final List<FileSystemEntity> list = await dir.list().toList();
          final List<File> files = [];
          for (var entity in list) {
            if (currentGen != _loadingGeneration) return;
            if (entity is File) {
              final ePath = entity.path.toLowerCase();
              if (ePath.endsWith('.jpg') ||
                  ePath.endsWith('.jpeg') ||
                  ePath.endsWith('.png') ||
                  ePath.endsWith('.webp') ||
                  ePath.endsWith('.bmp')) {
                files.add(entity);
              }
            }
          }
          files.sort((a, b) => a.path.compareTo(b.path));

          final List<PhotoItem> items = [];
          for (var file in files) {
            if (currentGen != _loadingGeneration) return;
            final filename = file.path.split(Platform.pathSeparator).last;
            final size = await _getImageSizeFromHeader(file.path);
            _sizeCache[file.path] = size;

            items.add(PhotoItem(
              id: file.path,
              url: file.path,
              title: filename,
              albumId: path,
              isLocal: true,
              width: size.width,
              height: size.height,
            ));
          }
          loadedFolderItems[path] = items;
        } catch (_) {}
      }
    }
    if (currentGen == _loadingGeneration && mounted) {
      setState(() {
        _folderItems.clear();
        _folderItems.addAll(loadedFolderItems);
        _isLoading = false;
      });
    }
  }

  Future<void> _addLocalFolder() async {
    try {
      final String? selectedDirectory = await FilePicker.getDirectoryPath();
      if (selectedDirectory != null) {
        if (!mounted) return;
        if (_selectedFolderPaths.contains(selectedDirectory)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Folder is already added.'),
              backgroundColor: StitchTheme.outline,
            ),
          );
          return;
        }

        // Cancel previous loading tasks immediately
        _loadingGeneration++;
        final int currentGen = _loadingGeneration;

        setState(() {
          _isLoading = true;
        });

        final dir = Directory(selectedDirectory);
        final List<File> files = [];
        if (await dir.exists()) {
          final list = await dir.list().toList();
          for (var entity in list) {
            if (currentGen != _loadingGeneration) return;
            if (entity is File) {
              final path = entity.path.toLowerCase();
              if (path.endsWith('.jpg') ||
                  path.endsWith('.jpeg') ||
                  path.endsWith('.png') ||
                  path.endsWith('.webp') ||
                  path.endsWith('.bmp')) {
                files.add(entity);
              }
            }
          }
        }

        files.sort((a, b) => a.path.compareTo(b.path));

        final List<PhotoItem> items = [];
        for (var file in files) {
          if (currentGen != _loadingGeneration) return;
          final filename = file.path.split(Platform.pathSeparator).last;
          final size = await _getImageSizeFromHeader(file.path);
          _sizeCache[file.path] = size;

          items.add(PhotoItem(
            id: file.path,
            url: file.path,
            title: filename,
            albumId: selectedDirectory,
            isLocal: true,
            width: size.width,
            height: size.height,
          ));
        }

        if (currentGen != _loadingGeneration || !mounted) return;

        setState(() {
          _selectedFolderPaths.add(selectedDirectory);
          _folderItems[selectedDirectory] = items;
          _isLoading = false;
        });

        await _settings.setSelectedFolders(_selectedFolderPaths);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _removeFolder(String folderPath) {
    _loadingGeneration++; // Cancel any active loading tasks immediately
    setState(() {
      _selectedFolderPaths.remove(folderPath);
      _folderItems.remove(folderPath);
    });
    _settings.setSelectedFolders(_selectedFolderPaths);

    final updated = List<PhotoItem>.from(widget.selectedPhotos);
    updated.removeWhere((p) => p.albumId == folderPath);
    widget.onPhotosChanged(updated);
  }

  void _clearAllFolders() {
    _loadingGeneration++; // Cancel any active loading tasks immediately
    setState(() {
      _selectedFolderPaths.clear();
      _folderItems.clear();
    });
    _settings.setSelectedFolders([]);
    widget.onPhotosChanged([]);
  }

  void _togglePhotoSelection(PhotoItem photo) {
    final updated = List<PhotoItem>.from(widget.selectedPhotos);
    final index = updated.indexWhere((p) => p.url == photo.url);

    if (index >= 0) {
      updated.removeAt(index);
    } else {
      final cachedSize = _sizeCache[photo.url];
      updated.add(photo.copyWith(
        width: cachedSize?.width ?? photo.width,
        height: cachedSize?.height ?? photo.height,
      ));
    }
    widget.onPhotosChanged(updated);
  }

  bool _isFolderAllSelected(String folderPath) {
    final items = _folderItems[folderPath] ?? [];
    if (items.isEmpty) return false;
    return items.every((item) => widget.selectedPhotos.any((p) => p.url == item.url));
  }

  void _toggleSelectAllFolder(String folderPath, bool selectAll) {
    final items = _folderItems[folderPath] ?? [];
    final updated = List<PhotoItem>.from(widget.selectedPhotos);

    if (selectAll) {
      for (var item in items) {
        if (!updated.any((p) => p.url == item.url)) {
          final cachedSize = _sizeCache[item.url];
          updated.add(item.copyWith(
            width: cachedSize?.width ?? item.width,
            height: cachedSize?.height ?? item.height,
          ));
        }
      }
    } else {
      for (var item in items) {
        updated.removeWhere((p) => p.url == item.url);
      }
    }
    widget.onPhotosChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Header with Action Buttons
        _buildTopHeader(),
        const SizedBox(height: 24),

        // Virtualized Slivers Workspace
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: StitchTheme.primary),
                )
              : _selectedFolderPaths.isEmpty
                  ? _buildEmptyState()
                  : CustomScrollView(
                      slivers: [
                        for (var folderPath in _selectedFolderPaths)
                          ..._buildFolderSlivers(folderPath),
                      ],
                    ),
        ),

        // Horizontal scrollable tray of selected images
        _buildSelectedImagesTray(),
      ],
    );
  }

  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Image Library',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.96,
                color: StitchTheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select folders containing photos from your device to compose your collage.',
              style: TextStyle(color: StitchTheme.onSurfaceVariant),
            ),
          ],
        ),
        Row(
          children: [
            if (widget.selectedPhotos.isNotEmpty) ...[
              TextButton.icon(
                onPressed: () => widget.onPhotosChanged([]),
                icon: const Icon(Icons.deselect, size: 16, color: StitchTheme.onSurfaceVariant),
                label: const Text('Deselect Images', style: TextStyle(color: StitchTheme.onSurfaceVariant)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (_selectedFolderPaths.isNotEmpty) ...[
              TextButton.icon(
                onPressed: _clearAllFolders,
                icon: const Icon(Icons.clear_all, size: 16, color: StitchTheme.error),
                label: const Text('Clear All', style: TextStyle(color: StitchTheme.error)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(width: 12),
            ],
            ElevatedButton.icon(
              onPressed: _addLocalFolder,
              icon: const Icon(Icons.create_new_folder_outlined, size: 16, color: StitchTheme.onPrimary),
              label: const Text('Add Folder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: StitchTheme.primary,
                foregroundColor: StitchTheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: StitchTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: StitchTheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open_outlined, size: 64, color: StitchTheme.outline),
            const SizedBox(height: 24),
            const Text(
              'No Folders Selected',
              style: TextStyle(
                color: StitchTheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select one or more folders containing JPEG, PNG, WebP or BMP images to compile your collage.',
              textAlign: TextAlign.center,
              style: TextStyle(color: StitchTheme.onSurfaceVariant, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addLocalFolder,
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('Select a Folder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: StitchTheme.primary,
                foregroundColor: StitchTheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFolderSlivers(String folderPath) {
    final folderName = folderPath.split(Platform.pathSeparator).last;
    final items = _folderItems[folderPath] ?? [];
    final allSelected = _isFolderAllSelected(folderPath);
    final isCollapsed = _collapsedFolders.contains(folderPath);

    return [
      // Folder Section Header Card
      SliverToBoxAdapter(
        child: Container(
          margin: EdgeInsets.only(top: 16, bottom: isCollapsed ? 16 : 0),
          decoration: BoxDecoration(
            color: StitchTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: Radius.circular(isCollapsed ? 12 : 0),
            ),
            border: Border.all(color: StitchTheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isCollapsed ? Icons.chevron_right : Icons.expand_more,
                        color: StitchTheme.onSurfaceVariant,
                      ),
                      onPressed: () {
                        setState(() {
                          if (isCollapsed) {
                            _collapsedFolders.remove(folderPath);
                          } else {
                            _collapsedFolders.add(folderPath);
                          }
                        });
                      },
                    ),
                    const Icon(Icons.folder, color: StitchTheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folderName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: StitchTheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          folderPath,
                          style: StitchTheme.codeSm(color: StitchTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(
                      value: allSelected,
                      onChanged: (val) => _toggleSelectAllFolder(folderPath, val ?? false),
                      activeColor: StitchTheme.primary,
                    ),
                    const Text('Select All', style: TextStyle(color: StitchTheme.onSurface, fontSize: 13)),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: StitchTheme.error, size: 20),
                      onPressed: () => _removeFolder(folderPath),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),

      if (!isCollapsed)
        if (items.isEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: const BoxDecoration(
                color: StitchTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                border: Border(
                  left: BorderSide(color: StitchTheme.outlineVariant),
                  right: BorderSide(color: StitchTheme.outlineVariant),
                  bottom: BorderSide(color: StitchTheme.outlineVariant),
                ),
              ),
              child: const Center(
                child: Text(
                  'No image files found in this folder.',
                  style: TextStyle(color: StitchTheme.onSurfaceVariant),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = items[index];
                  final isSelected = widget.selectedPhotos.any((p) => p.url == item.url);
                  return _buildImageTile(item, isSelected);
                },
                childCount: items.length,
              ),
            ),
          ),
    ];
  }

  Widget _buildImageTile(PhotoItem item, bool isSelected) {
    return GestureDetector(
      onTap: () => _togglePhotoSelection(item),
      child: Container(
        decoration: BoxDecoration(
          color: StitchTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.white : StitchTheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.file(
                File(item.url),
                fit: BoxFit.contain,
                cacheWidth: 300,
                cacheHeight: 300,
                errorBuilder: (_, _, _) => Container(
                  color: StitchTheme.surfaceContainerLow,
                  child: const Icon(Icons.broken_image, color: StitchTheme.outline),
                ),
              ),
            ),
            if (isSelected) ...[
              Positioned.fill(
                child: Container(color: StitchTheme.primaryContainer.withValues(alpha: 0.2)),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: StitchTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 12, color: StitchTheme.onPrimary),
                ),
              ),
            ] else ...[
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedImagesTray() {
    if (widget.selectedPhotos.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: StitchTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StitchTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tray Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.collections, color: StitchTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Selected Images (${widget.selectedPhotos.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: StitchTheme.onSurface,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => widget.onPhotosChanged([]),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Clear Selection',
                    style: StitchTheme.labelCaps(color: StitchTheme.primary),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: StitchTheme.outlineVariant),
          
          // Scrollable Multi-row List
          Container(
            height: 180,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Scrollbar(
              controller: _trayScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _trayScrollController,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 8),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: widget.selectedPhotos.map((photo) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Thumbnail image
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: StitchTheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: StitchTheme.outlineVariant),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.file(
                              File(photo.url),
                              fit: BoxFit.contain,
                              cacheWidth: 150,
                              cacheHeight: 150,
                              errorBuilder: (_, _, _) => Container(
                                color: StitchTheme.surfaceContainerHigh,
                                child: const Icon(Icons.broken_image, size: 20, color: StitchTheme.outline),
                              ),
                            ),
                          ),
                          // Deselect button on top-right
                          Positioned(
                            top: -4,
                            right: -4,
                            child: GestureDetector(
                              onTap: () => _togglePhotoSelection(photo),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: StitchTheme.error,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(
                                  Icons.close,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
