import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../engine/collage_models.dart';
import '../engine/collage_generator.dart';
import '../theme/theme.dart';
import 'template_selection_screen.dart';
import 'photo_picker_screen.dart';
import 'progress_screen.dart';
import 'editor_screen.dart';
import 'settings_screen.dart';
import 'recent_collages_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final SettingsService _settings = SettingsService();

  // Workflow states
  String _activeTab = 'templates'; // templates, library, recent, settings
  String? _workflowSubScreen; // progress, editor
  
  // Selection state
  String _selectedTemplate = 'Random Collage';
  List<PhotoItem> _selectedPhotos = [];
  CollageLayout? _collageLayout;

  // Settings cached copies (trigger UI updates)
  String _selectedSize = 'A4 Paper';
  String _selectedOrientation = 'Landscape';
  bool _whiteBorderOn = true;
  double _borderSizeMm = 5.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _selectedSize = _settings.getDefaultSize();
      _selectedOrientation = _settings.getDefaultOrientation();
      _whiteBorderOn = _settings.getWhiteBorderOn(_selectedTemplate);
      _borderSizeMm = _settings.getBorderSizeMm(_selectedTemplate);
    });
  }

  void _changeTab(String tab) {
    setState(() {
      _activeTab = tab;
      _workflowSubScreen = null; // Exit workflow if switching tabs
    });
  }

  void _resetProject() {
    setState(() {
      _selectedPhotos = [];
      _collageLayout = null;
      _workflowSubScreen = null;
      _activeTab = 'templates';
    });
  }

  // Trigger collage generator and move to progress screen
  void _generateCollage() {
    if (_selectedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one photo before generating.'),
          backgroundColor: StitchTheme.error,
        ),
      );
      return;
    }

    setState(() {
      _workflowSubScreen = 'progress';
    });
  }

  // Transition from Progress to Editor
  void _onProgressCompleted() {
    // Load template-specific border styling configuration
    setState(() {
      _whiteBorderOn = _settings.getWhiteBorderOn(_selectedTemplate);
      _borderSizeMm = _settings.getBorderSizeMm(_selectedTemplate);
    });

    // Generate layout representation
    double canvasW = 1200;
    double canvasH = 800;

    // Calculate dynamic canvas size based on aspect ratio
    final double aspect = _selectedSize == 'Instagram Square'
        ? 1.0
        : _selectedSize == 'Web Banner'
            ? (_selectedOrientation == 'Landscape' ? 3.0 : 0.33)
            : (_selectedOrientation == 'Landscape' ? 1.414 : 0.707); // A4, A3, etc.

    if (aspect >= 1.0) {
      canvasW = 1000;
      canvasH = canvasW / aspect;
    } else {
      canvasH = 800;
      canvasW = canvasH * aspect;
    }

    final layout = CollageGenerator.generate(
      photos: _selectedPhotos,
      templateName: _selectedTemplate,
      canvasWidth: canvasW,
      canvasHeight: canvasH,
    );

    setState(() {
      _collageLayout = layout;
      _workflowSubScreen = 'editor';
    });
  }

  void _onRegenerate(String template, List<dynamic> photos) {
    setState(() {
      _selectedTemplate = template;
      _workflowSubScreen = 'progress';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTheme.background,
      body: Row(
        children: [
          // Sidebar (Fixed 260px)
          _buildSidebar(),

          // Main Section (Top Bar + Workspace + Bottom Bar)
          Expanded(
            child: Column(
              children: [
                // Top Toolbar
                _buildTopToolbar(),

                // Workspace Content
                Expanded(
                  child: Container(
                    color: StitchTheme.background,
                    padding: _workflowSubScreen == 'editor'
                        ? EdgeInsets.zero // Editor manages its own full-screen canvas and sidebar
                        : const EdgeInsets.all(24),
                    child: Stack(
                      children: [
                        // Dot grid background
                        if (_workflowSubScreen != 'editor')
                          Positioned.fill(
                            child: CustomPaint(
                              painter: DotGridPainter(),
                            ),
                          ),
                        // Screen Loader
                        Positioned.fill(
                          child: _getActiveWorkspace(),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Footer Navigation (if not in Editor mode)
                if (_workflowSubScreen != 'editor' && _workflowSubScreen != 'progress')
                  _buildBottomFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: StitchTheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: StitchTheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Title
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 8),
            child: const Text(
              'Collage Studio',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: StitchTheme.primary,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Nav links
          _buildSidebarNavItem(
            icon: Icons.dashboard_outlined,
            filledIcon: Icons.dashboard,
            label: 'Templates',
            tabName: 'templates',
          ),
          _buildSidebarNavItem(
            icon: Icons.photo_library_outlined,
            filledIcon: Icons.photo_library,
            label: 'Image Library',
            tabName: 'library',
          ),
          _buildSidebarNavItem(
            icon: Icons.history_outlined,
            filledIcon: Icons.history,
            label: 'Recent Collages',
            tabName: 'recent',
          ),
          _buildSidebarNavItem(
            icon: Icons.settings_outlined,
            filledIcon: Icons.settings,
            label: 'Settings',
            tabName: 'settings',
          ),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem({
    required IconData icon,
    required IconData filledIcon,
    required String label,
    required String tabName,
  }) {
    final isSelected = _activeTab == tabName && _workflowSubScreen == null;
    return GestureDetector(
      onTap: () => _changeTab(tabName),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? StitchTheme.primaryContainer.withOpacity(0.1) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? StitchTheme.primary : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              isSelected ? filledIcon : icon,
              size: 20,
              color: isSelected ? StitchTheme.primary : StitchTheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? StitchTheme.primary : StitchTheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopToolbar() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: StitchTheme.surfaceContainer,
        border: Border(bottom: BorderSide(color: StitchTheme.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox.shrink(),

          // Contextual parameters in toolbar
          if (_activeTab == 'templates' && _workflowSubScreen == null)
            Row(
              children: [
                // Size picker dropdown
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: StitchTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: StitchTheme.outlineVariant),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSize,
                      dropdownColor: StitchTheme.surfaceContainer,
                      style: StitchTheme.labelCaps(color: StitchTheme.onSurface),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedSize = val);
                          _settings.setDefaultSize(val);
                        }
                      },
                      items: ['A4 Paper', 'A3 Poster', 'Instagram Square', 'Web Banner']
                          .map((size) => DropdownMenuItem(value: size, child: Text(size)))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => _buildAboutDialog(context),
                    );
                  },
                  icon: const Icon(Icons.help_outline, color: StitchTheme.onSurfaceVariant, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  tooltip: 'About Collage Studio',
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAboutDialog(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF201F1F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF353534)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App Icon
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/app_icon.png',
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
            
            // App Name
            const Text(
              'CollageStudio',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            
            // Version Label
            const Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 13,
                color: StitchTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            
            const Divider(color: Color(0xFF353534), height: 1),
            const SizedBox(height: 16),
            
            // Close Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StitchTheme.primary,
                  foregroundColor: StitchTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildBottomFooter() {
    String nextLabel = 'Next: Choose Images';
    IconData nextIcon = Icons.arrow_forward;
    VoidCallback? onNextAction;

    if (_activeTab == 'templates') {
      nextLabel = 'Next: Choose Images';
      nextIcon = Icons.arrow_forward;
      onNextAction = () => setState(() => _activeTab = 'library');
    } else if (_activeTab == 'library') {
      nextLabel = 'Next: Generate Collage';
      nextIcon = Icons.auto_awesome;
      // Enabled only if photos selected
      onNextAction = _selectedPhotos.isNotEmpty ? _generateCollage : null;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: StitchTheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: StitchTheme.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_activeTab == 'library') ...[
              OutlinedButton.icon(
                onPressed: () => setState(() => _activeTab = 'templates'),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: StitchTheme.onSurfaceVariant,
                  side: const BorderSide(color: StitchTheme.outlineVariant),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 12),
            ],
            ElevatedButton(
              onPressed: onNextAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: onNextAction != null ? StitchTheme.primary : StitchTheme.outlineVariant.withOpacity(0.5),
                foregroundColor: onNextAction != null ? StitchTheme.onPrimary : StitchTheme.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                children: [
                  Text(nextLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Icon(nextIcon, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );

  }

  Widget _getActiveWorkspace() {
    if (_workflowSubScreen == 'progress') {
      return ProgressScreen(
        templateName: _selectedTemplate,
        selectedPhotos: _selectedPhotos,
        onCompleted: _onProgressCompleted,
      );
    }

    if (_workflowSubScreen == 'editor' && _collageLayout != null) {
      double aspect = 1.414;
      if (_selectedSize == 'Instagram Square') {
        aspect = 1.0;
      } else if (_selectedSize == 'Web Banner') {
        aspect = _selectedOrientation == 'Landscape' ? 3.0 : 0.33;
      } else {
        aspect = _selectedOrientation == 'Landscape' ? 1.414 : 0.707;
      }

      double w = 1000;
      double h = w / aspect;

      return EditorScreen(
        layout: _collageLayout!,
        selectedPhotos: _selectedPhotos,
        templateName: _selectedTemplate,
        canvasWidth: w,
        canvasHeight: h,
        initialWhiteBorderOn: _whiteBorderOn,
        initialBorderSizeMm: _borderSizeMm,
        selectedOrientation: _selectedOrientation,
        onSelectOrientation: (ori) {
          setState(() {
            _selectedOrientation = ori;
          });
          _settings.setDefaultOrientation(ori);
        },
        onLayoutChanged: (newLayout) {
          setState(() {
            _collageLayout = newLayout;
          });
        },
        onBack: () {
          setState(() {
            _workflowSubScreen = null;
            _activeTab = 'library';
          });
        },
        onRegenerate: _onRegenerate,
      );
    }

    switch (_activeTab) {
      case 'templates':
        return TemplateSelectionScreen(
          selectedTemplate: _selectedTemplate,
          selectedSize: _selectedSize,
          selectedOrientation: _selectedOrientation,
          onSelectTemplate: (tpl) => setState(() => _selectedTemplate = tpl),
          onSelectSize: (sz) => setState(() => _selectedSize = sz),
          onSelectOrientation: (ori) => setState(() => _selectedOrientation = ori),
          onNext: () => setState(() => _activeTab = 'library'),
        );
      case 'library':
        return PhotoPickerScreen(
          selectedPhotos: _selectedPhotos,
          onPhotosChanged: (photos) => setState(() => _selectedPhotos = photos),
          onBack: () => setState(() => _activeTab = 'templates'),
          onNext: _generateCollage,
        );
      case 'recent':
        return const RecentCollagesScreen();
      case 'settings':
        return SettingsScreen(
          onSaved: _loadSettings,
        );
      default:
        return const Center(child: Text('Coming Soon'));
    }
  }
}
