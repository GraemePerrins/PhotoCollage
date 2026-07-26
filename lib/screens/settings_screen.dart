import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/settings_service.dart';
import '../theme/theme.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onSaved;

  const SettingsScreen({super.key, required this.onSaved});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();

  String _outputFolder = '';
  String _defaultSize = 'A4 Paper';
  String _defaultOrientation = 'Landscape';

  @override
  void initState() {
    super.initState();
    _outputFolder = _settings.getOutputFolder();
    _defaultSize = _settings.getDefaultSize();
    _defaultOrientation = _settings.getDefaultOrientation();
  }

  Future<void> _pickOutputFolder() async {
    try {
      String? result = await FilePicker.getDirectoryPath();
      if (result != null) {
        setState(() {
          _outputFolder = result;
        });
        await _settings.setOutputFolder(result);
        widget.onSaved();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        const Text(
          'Configuration',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.96,
            color: StitchTheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Manage output destinations and sizing metrics.',
          style: TextStyle(color: StitchTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),

        // Settings scrollable area
        Expanded(
          child: ListView(
            children: [
              // Output Destination Section
              _buildSection(
                title: 'Output Destination',
                icon: Icons.folder_open,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: StitchTheme.surfaceContainerLowest,
                              border: Border.all(color: StitchTheme.outlineVariant),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _outputFolder.isEmpty ? 'Not set (using default)' : _outputFolder,
                              style: StitchTheme.codeSm(color: StitchTheme.onSurface),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _pickOutputFolder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: StitchTheme.surfaceContainerHigh,
                            foregroundColor: StitchTheme.onSurface,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          child: const Text('Change Folder'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Generated collages will be automatically saved to this location with a timestamp.',
                      style: TextStyle(color: StitchTheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Layout Defaults Section
              _buildSection(
                title: 'Layout Defaults',
                icon: Icons.aspect_ratio,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DEFAULT SIZE', style: TextStyle(fontSize: 10, color: StitchTheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _defaultSize,
                      dropdownColor: StitchTheme.surfaceContainer,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: ['A4 Paper', 'A3 Poster', 'Instagram Square', 'Web Banner']
                          .map((size) => DropdownMenuItem(value: size, child: Text(size)))
                          .toList(),
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() => _defaultSize = val);
                          await _settings.setDefaultSize(val);
                          widget.onSaved();
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('DEFAULT ORIENTATION', style: TextStyle(fontSize: 10, color: StitchTheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _defaultOrientation,
                      dropdownColor: StitchTheme.surfaceContainer,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: ['Landscape', 'Portrait']
                          .map((orient) => DropdownMenuItem(value: orient, child: Text(orient)))
                          .toList(),
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() => _defaultOrientation = val);
                          await _settings.setDefaultOrientation(val);
                          widget.onSaved();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: StitchTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StitchTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: StitchTheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: StitchTheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
