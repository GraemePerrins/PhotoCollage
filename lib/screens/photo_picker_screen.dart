import 'dart:async';
import 'dart:io';
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

  Future<void> _loadSavedFolders() async {
    setState(() => _isLoading = true);
    _loadingGeneration++;
    final int currentGen = _loadingGeneration;
    final saved = _settings.getSelectedFolders();
    _selectedFolderPaths = List.from(saved);

    for (var path in _selectedFolderPaths) {
      if (currentGen != _loadingGeneration) return;
      final dir = Directory(path);
      if (dir.existsSync()) {
        try {
          final list = dir.listSync();
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
            items.add(PhotoItem(
              id: file.path,
              url: file.path,
              title: filename,
              albumId: path,
              isLocal: true,
            ));
          }
          _folderItems[path] = items;

          // Asynchronously resolve image sizes
          for (var item in items) {
            if (currentGen != _loadingGeneration) return;
            _resolveImageSize(item, currentGen);
          }
        } catch (_) {}
      }
    }
    if (currentGen == _loadingGeneration) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addLocalFolder() async {
    try {
      final String? selectedDirectory = await FilePicker.getDirectoryPath();
      if (selectedDirectory != null) {
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
        if (dir.existsSync()) {
          final list = dir.listSync();
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
          items.add(PhotoItem(
            id: file.path,
            url: file.path,
            title: filename,
            albumId: selectedDirectory,
            isLocal: true,
          ));
        }

        if (currentGen != _loadingGeneration) return;

        setState(() {
          _selectedFolderPaths.add(selectedDirectory);
          _folderItems[selectedDirectory] = items;
          _isLoading = false;
        });

        await _settings.setSelectedFolders(_selectedFolderPaths);

        for (var item in items) {
          if (currentGen != _loadingGeneration) return;
          _resolveImageSize(item, currentGen);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error picking directory: $e');
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

  Future<void> _resolveImageSize(PhotoItem item, int generation) async {
    if (generation != _loadingGeneration) return;

    if (_sizeCache.containsKey(item.url)) {
      final size = _sizeCache[item.url]!;
      _updateItemSize(item, size.width, size.height, generation);
      return;
    }

    try {
      final completer = Completer<Size>();
      final fileImage = FileImage(File(item.url));
      final stream = fileImage.resolve(const ImageConfiguration());
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool _) {
          completer.complete(Size(info.image.width.toDouble(), info.image.height.toDouble()));
          stream.removeListener(listener);
        },
        onError: (exception, stackTrace) {
          completer.complete(const Size(800.0, 600.0));
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      final size = await completer.future;

      if (generation != _loadingGeneration) return;

      _sizeCache[item.url] = size;
      _updateItemSize(item, size.width, size.height, generation);
    } catch (_) {
      if (generation != _loadingGeneration) return;
      _sizeCache[item.url] = const Size(800.0, 600.0);
      _updateItemSize(item, 800.0, 600.0, generation);
    }
  }

  void _updateItemSize(PhotoItem item, double width, double height, int generation) {
    if (!mounted) return;
    if (generation != _loadingGeneration) return;
    setState(() {
      final list = _folderItems[item.albumId];
      if (list != null) {
        final index = list.indexWhere((e) => e.url == item.url);
        if (index >= 0) {
          list[index] = list[index].copyWith(width: width, height: height);
        }
      }
      final selectedIndex = widget.selectedPhotos.indexWhere((e) => e.url == item.url);
      if (selectedIndex >= 0) {
        final updated = List<PhotoItem>.from(widget.selectedPhotos);
        updated[selectedIndex] = updated[selectedIndex].copyWith(width: width, height: height);
        widget.onPhotosChanged(updated);
      }
    });
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
        Row(
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
        ),
        const SizedBox(height: 24),

        // Folders List / Empty State
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: StitchTheme.primary),
                )
              : _selectedFolderPaths.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: _selectedFolderPaths.length,
                      itemBuilder: (context, index) {
                        final path = _selectedFolderPaths[index];
                        final items = _folderItems[path] ?? [];
                        return _buildFolderSection(path, items);
                      },
                    ),
        ),

        // Horizontal scrollable tray of selected images
        _buildSelectedImagesTray(),
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

  Widget _buildFolderSection(String folderPath, List<PhotoItem> items) {
    final folderName = folderPath.split(Platform.pathSeparator).last;
    final allSelected = _isFolderAllSelected(folderPath);
    final isCollapsed = _collapsedFolders.contains(folderPath);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: StitchTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StitchTheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
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
          if (!isCollapsed) ...[
            const Divider(height: 1, color: StitchTheme.outlineVariant),

            // Images Grid
            Padding(
              padding: const EdgeInsets.all(16),
              child: items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No image files found in this folder.',
                          style: TextStyle(color: StitchTheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isSelected = widget.selectedPhotos.any((p) => p.url == item.url);
                        return _buildImageTile(item, isSelected);
                      },
                    ),
            ),
          ],
        ],
      ),
    );
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
                errorBuilder: (_, __, ___) => Container(
                  color: StitchTheme.surfaceContainerLow,
                  child: const Icon(Icons.broken_image, color: StitchTheme.outline),
                ),
              ),
            ),
            if (isSelected) ...[
              Positioned.fill(
                child: Container(color: StitchTheme.primaryContainer.withOpacity(0.2)),
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
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
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
                              errorBuilder: (_, __, ___) => Container(
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
