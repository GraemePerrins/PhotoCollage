import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/collage_models.dart';
import '../theme/theme.dart';

class ProgressScreen extends StatefulWidget {
  final String templateName;
  final List<PhotoItem> selectedPhotos;
  final VoidCallback onCompleted;

  const ProgressScreen({
    super.key,
    required this.templateName,
    required this.selectedPhotos,
    required this.onCompleted,
  });

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  Timer? _timer;
  final List<Map<String, dynamic>> _visibleThumbnails = [];
  final Random _random = Random();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _startGenerationSimulation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startGenerationSimulation() {
    final int count = widget.selectedPhotos.length;
    // Step interval depends on photo count, e.g. total 3 seconds
    final int totalDurationMs = 3000;
    final int intervalMs = 50;
    final double step = intervalMs / totalDurationMs;

    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!mounted) return;

      setState(() {
        _progress += step;
        if (_progress >= 1.0) {
          _progress = 1.0;
          _timer?.cancel();
          // Delay transition slightly for a satisfying finish
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) widget.onCompleted();
          });
        }

        // Add thumbnails periodically matching progress
        final int targetThumbCount = (_progress * count).floor();
        if (_visibleThumbnails.length < targetThumbCount && _visibleThumbnails.length < count) {
          final nextPhoto = widget.selectedPhotos[_visibleThumbnails.length];
          _visibleThumbnails.add({
            'photo': nextPhoto,
            'left': 10 + _random.nextDouble() * 70, // percentage x (10% to 80%)
            'top': 10 + _random.nextDouble() * 60, // percentage y (10% to 70%)
            'angle': (_random.nextDouble() * 0.4) - 0.2, // rotation in rad
            'scale': 0.7 + _random.nextDouble() * 0.4,
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (_progress * 100).floor();
    final isDone = _progress >= 1.0;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Focused Progress Visual
            Text(
              isDone ? 'Generation Complete!' : 'Processing images... $percentage%',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.96,
                color: StitchTheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Applying "${widget.templateName}" style to ${widget.selectedPhotos.length} images',
              style: const TextStyle(
                color: StitchTheme.secondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 48),

            // Central Progress Bar System
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Glowing Progress Bar
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: StitchTheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progress,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [StitchTheme.primary, StitchTheme.secondary],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: StitchTheme.primary,
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Technical Readouts
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isDone ? 'STATUS: COMPLETED' : 'STATUS: RENDERING_COLLAGE',
                      style: StitchTheme.codeSm(),
                    ),
                    Text(
                      'BUFFER: ${(4.2 + _progress * 2.1).toStringAsFixed(1)}GB / 8GB',
                      style: StitchTheme.codeSm(),
                    ),
                    Text(
                      'ESTIMATED: ${((1 - _progress) * 3).toStringAsFixed(1)}s',
                      style: StitchTheme.codeSm(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 48),

            // Visualization Area (Canvas where thumbnails float into place)
            Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                color: StitchTheme.surfaceContainerLowest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: StitchTheme.outlineVariant),
              ),
              child: Stack(
                children: [
                  // Dot grid inside canvas
                  Positioned.fill(
                    child: CustomPaint(
                      painter: DotGridPainter(spacing: 16.0, dotRadius: 0.8),
                    ),
                  ),

                  // Floating Thumbnails
                  ..._visibleThumbnails.map((item) {
                    final photo = item['photo'] as PhotoItem;
                    return Positioned(
                      left: (item['left'] as double) * 7.0, // scale percentage to canvas size
                      top: (item['top'] as double) * 2.4,
                      child: Transform.rotate(
                        angle: item['angle'] as double,
                        child: Transform.scale(
                          scale: item['scale'] as double,
                          child: Container(
                            width: 70,
                            height: 90,
                            decoration: BoxDecoration(
                              color: StitchTheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: photo.isLocal
                                ? Image.file(File(photo.url), fit: BoxFit.cover)
                                : Image.network(
                                    photo.url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 20),
                                  ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),

                  // Core Pulsing icon
                  Center(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: 0.3 + (_pulseController.value * 0.7),
                          child: Transform.scale(
                            scale: 0.9 + (_pulseController.value * 0.2),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: StitchTheme.primary,
                              size: 64,
                            ),
                          ),
                        );
                      },
                    ),
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
