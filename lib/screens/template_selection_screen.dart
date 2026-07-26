import 'package:flutter/material.dart';
import '../theme/theme.dart';

class TemplateSelectionScreen extends StatelessWidget {
  final String selectedTemplate;
  final String selectedSize;
  final String selectedOrientation;
  final Function(String) onSelectTemplate;
  final Function(String) onSelectSize;
  final Function(String) onSelectOrientation;
  final VoidCallback onNext;

  const TemplateSelectionScreen({
    super.key,
    required this.selectedTemplate,
    required this.selectedSize,
    required this.selectedOrientation,
    required this.onSelectTemplate,
    required this.onSelectSize,
    required this.onSelectOrientation,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        const Text(
          'Select a Template',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.64,
            color: StitchTheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose a layout structure for your collage. You can always adjust spacing and borders later in the editor.',
          style: TextStyle(
            color: StitchTheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),

        // Grid of Templates
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: StitchTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: StitchTheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(12),
            child: GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              clipBehavior: Clip.none,
              children: [
                _buildTemplateCard(
                  title: 'Basic Grid',
                  description: 'Uniform grid layout. Perfect for structured sequences.',
                  previewWidget: _buildGridPreview(),
                ),
                _buildTemplateCard(
                  title: 'Random Collage',
                  description: 'Artistic overlapping with randomized rotation and depth layering. Most popular.',
                  previewWidget: _buildRandomPreview(),
                ),
                _buildTemplateCard(
                  title: 'Throw Down',
                  description: 'Mimics a messy pile of photos dropped onto a desk. Organic and chaotic.',
                  previewWidget: _buildThrowDownPreview(),
                ),
                _buildTemplateCard(
                  title: 'Circular Spiral',
                  description: 'Radial layout concentrating focus on the center. Dynamic and modern.',
                  previewWidget: _buildCircularPreview(),
                ),
                _buildTemplateCard(
                  title: 'Tiled Varied',
                  description: 'Masonry-style layout with variable block sizes. Great for mixing aspect ratios.',
                  previewWidget: _buildTiledPreview(),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

Widget _buildTemplateCard({
  required String title,
  required String description,
  required Widget previewWidget,
}) {
  final isSelected = selectedTemplate == title;
  return GestureDetector(
    onTap: () => onSelectTemplate(title),
    child: Container(
      decoration: BoxDecoration(
        color: StitchTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.transparent : StitchTheme.outlineVariant,
          width: 1,
        ),
        boxShadow: isSelected
            ? [
                const BoxShadow(
                  color: Colors.white,
                  spreadRadius: 2,
                  blurRadius: 0,
                )
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview Canvas
            Expanded(
              flex: 3,
              child: Container(
                color: StitchTheme.surfaceContainerHighest,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: DotGridPainter(spacing: 8.0, dotRadius: 0.5),
                      ),
                    ),
                    previewWidget,
                  ],
                ),
              ),
            ),
            // Details
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(12),
                color: StitchTheme.surfaceContainerLow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: StitchTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: StitchTheme.codeSm(color: StitchTheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  // Previews mimicking the original screen designs
  Widget _buildGridPreview() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 1.5,
        ),
        itemCount: 6,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: StitchTheme.outlineVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: StitchTheme.outlineVariant.withOpacity(0.5)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRandomPreview() {
    return Stack(
      children: [
        Positioned(
          top: 15,
          left: 15,
          width: 80,
          height: 60,
          child: Transform.rotate(
            angle: -0.08,
            child: Container(
              decoration: BoxDecoration(
                color: StitchTheme.primary.withOpacity(0.2),
                border: Border.all(color: StitchTheme.primary.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        Positioned(
          top: 25,
          right: 25,
          width: 90,
          height: 60,
          child: Transform.rotate(
            angle: 0.05,
            child: Container(
              decoration: BoxDecoration(
                color: StitchTheme.secondary.withOpacity(0.2),
                border: Border.all(color: StitchTheme.secondary.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 10,
          left: 60,
          width: 100,
          height: 70,
          child: Transform.rotate(
            angle: -0.03,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThrowDownPreview() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: 0.25,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: StitchTheme.onSurfaceVariant.withOpacity(0.2),
                border: Border.all(color: StitchTheme.outlineVariant),
              ),
            ),
          ),
          Transform.rotate(
            angle: -0.17,
            child: Container(
              width: 70,
              height: 70,
              margin: const EdgeInsets.only(left: 30),
              decoration: BoxDecoration(
                color: StitchTheme.onSurfaceVariant.withOpacity(0.2),
                border: Border.all(color: StitchTheme.outlineVariant),
              ),
            ),
          ),
          Transform.rotate(
            angle: 0.08,
            child: Container(
              width: 70,
              height: 70,
              margin: const EdgeInsets.only(left: 60, top: 20),
              decoration: BoxDecoration(
                color: StitchTheme.onSurfaceVariant.withOpacity(0.2),
                border: Border.all(color: StitchTheme.outlineVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularPreview() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: StitchTheme.outlineVariant,
                style: BorderStyle.solid,
                width: 2,
              ),
            ),
          ),
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: StitchTheme.secondaryContainer.withOpacity(0.2),
              border: Border.all(color: StitchTheme.secondaryContainer.withOpacity(0.5)),
              shape: BoxShape.circle,
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            width: 25,
            height: 25,
            child: Container(
              decoration: BoxDecoration(
                color: StitchTheme.primary.withOpacity(0.2),
                border: Border.all(color: StitchTheme.primary.withOpacity(0.5)),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            width: 20,
            height: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTiledPreview() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: StitchTheme.onSurfaceVariant.withOpacity(0.1),
                border: Border.all(color: StitchTheme.outlineVariant.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: StitchTheme.onSurfaceVariant.withOpacity(0.1),
                      border: Border.all(color: StitchTheme.outlineVariant.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: StitchTheme.onSurfaceVariant.withOpacity(0.1),
                      border: Border.all(color: StitchTheme.outlineVariant.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
