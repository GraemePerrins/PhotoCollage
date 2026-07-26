import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StitchTheme {
  // Brand Colors
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF131313);
  static const Color surfaceDim = Color(0xFF131313);
  static const Color surfaceBright = Color(0xFF393939);
  
  static const Color surfaceContainerLowest = Color(0xFF0E0E0E);
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color surfaceContainer = Color(0xFF201F1F);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceContainerHighest = Color(0xFF353534);
  
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFC7C4D8);
  static const Color outline = Color(0xFF918FA1);
  static const Color outlineVariant = Color(0xFF464555);
  
  static const Color primary = Color(0xFFC3C0FF);
  static const Color onPrimary = Color(0xFF1D00A5);
  static const Color primaryContainer = Color(0xFF4F46E5);
  static const Color onPrimaryContainer = Color(0xFFDAD7FF);
  static const Color inversePrimary = Color(0xFF4D44E3);
  
  static const Color secondary = Color(0xFF89CEFF);
  static const Color onSecondary = Color(0xFF00344D);
  static const Color secondaryContainer = Color(0xFF00A2E6);
  static const Color onSecondaryContainer = Color(0xFF00344E);

  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  
  // Theme Data Builder
  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        background: background,
        surface: surface,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        error: error,
        onError: onError,
        outline: outline,
        outlineVariant: outlineVariant,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.interTextTheme(baseTextTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.96,
          color: onSurface,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: onSurface,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: MaterialStateProperty.all(outlineVariant),
        trackColor: MaterialStateProperty.all(surfaceContainerLow),
        radius: const Radius.circular(3),
        thickness: MaterialStateProperty.all(6),
      ),
    );
  }

  // Label style (JetBrains Mono uppercase)
  static TextStyle labelCaps({Color color = onSurfaceVariant}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.55,
      color: color,
    );
  }

  // Technical code style
  static TextStyle codeSm({Color color = onSurfaceVariant}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: color,
    );
  }
}

// Dot Grid Background Painter
class DotGridPainter extends CustomPainter {
  final Color dotColor;
  final double spacing;
  final double dotRadius;

  DotGridPainter({
    this.dotColor = StitchTheme.outlineVariant,
    this.spacing = 24.0,
    this.dotRadius = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotGridPainter oldDelegate) => false;
}
