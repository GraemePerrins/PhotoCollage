import 'dart:io';
import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../theme/theme.dart';

class RecentCollagesScreen extends StatefulWidget {
  const RecentCollagesScreen({super.key});

  @override
  State<RecentCollagesScreen> createState() => _RecentCollagesScreenState();
}

class _RecentCollagesScreenState extends State<RecentCollagesScreen> {
  final SettingsService _settings = SettingsService();
  List<File> _collages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecentCollages();
  }

  Future<void> _loadRecentCollages() async {
    setState(() => _isLoading = true);
    try {
      final folderPath = _settings.getOutputFolder();
      if (folderPath.isNotEmpty) {
        final dir = Directory(folderPath);
        if (dir.existsSync()) {
          final List<FileSystemEntity> files = dir.listSync();
          final List<File> pngFiles = files
              .whereType<File>()
              .where((file) {
                final name = file.path.split('/').last.toLowerCase();
                return name.startsWith('collage_') && name.endsWith('.png');
              })
              .toList();

          // Sort by date modified descending
          pngFiles.sort((a, b) {
            try {
              return b.lastModifiedSync().compareTo(a.lastModifiedSync());
            } catch (_) {
              return 0;
            }
          });

          setState(() {
            _collages = pngFiles;
          });
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  void _previewCollage(File file) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Image.file(file),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Collages',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.96,
                    color: StitchTheme.onSurface,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Browse and preview collages generated and saved on your system.',
                  style: TextStyle(color: StitchTheme.onSurfaceVariant),
                ),
              ],
            ),
            IconButton(
              onPressed: _loadRecentCollages,
              icon: const Icon(Icons.refresh, color: StitchTheme.primary),
              tooltip: 'Refresh Gallery',
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Gallery list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: StitchTheme.primary))
              : _collages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo_library_outlined, size: 64, color: StitchTheme.outline),
                          const SizedBox(height: 16),
                          const Text(
                            'No saved collages found.',
                            style: TextStyle(color: StitchTheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Exported collages in ${_settings.getOutputFolder()} will appear here.',
                            style: StitchTheme.codeSm(color: StitchTheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: _collages.length,
                      itemBuilder: (context, index) {
                        final file = _collages[index];
                        final filename = file.path.split('/').last;
                        
                        String dateStr = '';
                        try {
                          final modified = file.lastModifiedSync();
                          dateStr = '${modified.year}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')}';
                        } catch (_) {}

                        return GestureDetector(
                          onTap: () => _previewCollage(file),
                          child: Container(
                            decoration: BoxDecoration(
                              color: StitchTheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: StitchTheme.outlineVariant),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Thumbnail Image
                                Expanded(
                                  child: Container(
                                    color: StitchTheme.surfaceContainerLowest,
                                    child: Image.file(
                                      file,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                                    ),
                                  ),
                                ),
                                // Metadata
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  color: StitchTheme.surfaceContainerLow,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        filename,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            dateStr,
                                            style: StitchTheme.codeSm(color: StitchTheme.onSurfaceVariant),
                                          ),
                                          const Icon(Icons.open_in_full, size: 12, color: StitchTheme.primary),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
