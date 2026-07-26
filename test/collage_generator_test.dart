import 'package:flutter_test/flutter_test.dart';
import 'package:photocollage/engine/collage_generator.dart';
import 'package:photocollage/engine/collage_models.dart';

void main() {
  group('Collage Generator Tests', () {
    final mockPhotos = List.generate(
      8,
      (i) => PhotoItem(
        id: 'photo_$i',
        url: 'https://test.url/img_$i.jpg',
        title: 'Photo $i',
        albumId: 'test_album',
      ),
    );

    test('Basic Grid arrangement generates correct item counts and coordinates', () {
      final layout = CollageGenerator.generate(
        photos: mockPhotos,
        templateName: 'Basic Grid',
        canvasWidth: 800,
        canvasHeight: 600,
      );

      expect(layout.items.length, equals(8));
      expect(layout.templateName, equals('Basic Grid'));

      for (var item in layout.items) {
        expect(item.x, greaterThanOrEqualTo(0.0));
        expect(item.x, lessThanOrEqualTo(1.0));
        expect(item.y, greaterThanOrEqualTo(0.0));
        expect(item.y, lessThanOrEqualTo(1.0));
        expect(item.rotation, equals(0.0));
      }
    });

    test('Random Collage arrangement creates layout with rotations', () {
      final layout = CollageGenerator.generate(
        photos: mockPhotos,
        templateName: 'Random Collage',
        canvasWidth: 800,
        canvasHeight: 600,
      );

      expect(layout.items.length, equals(8));
      
      // Verify rotations are generated and z-indexes correspond to rendering order
      bool hasRotations = false;
      for (var item in layout.items) {
        if (item.rotation != 0.0) {
          hasRotations = true;
        }
        expect(item.zIndex, greaterThanOrEqualTo(0));
      }
      expect(hasRotations, isTrue);
    });

    test('Tiled Varied partitions coordinates completely', () {
      final layout = CollageGenerator.generate(
        photos: mockPhotos,
        templateName: 'Tiled Varied',
        canvasWidth: 800,
        canvasHeight: 600,
      );

      expect(layout.items.length, equals(8));
      
      // Grid items shouldn't exceed canvas limits
      for (var item in layout.items) {
        expect(item.x + item.width, lessThanOrEqualTo(1.0));
        expect(item.y + item.height, lessThanOrEqualTo(1.0));
      }
    });

    test('Image Swapping alters imagePath properties but maintains coordinates', () {
      final layout = CollageGenerator.generate(
        photos: mockPhotos,
        templateName: 'Basic Grid',
        canvasWidth: 800,
        canvasHeight: 600,
      );

      // Perform a mock swap
      final item1 = layout.items[0];
      final item2 = layout.items[1];

      final originalPath1 = item1.imagePath;
      final originalPath2 = item2.imagePath;

      final list = List<CollageItem>.from(layout.items);
      list[0] = item1.copyWith(imagePath: originalPath2);
      list[1] = item2.copyWith(imagePath: originalPath1);

      expect(list[0].imagePath, equals(originalPath2));
      expect(list[1].imagePath, equals(originalPath1));
      
      // Coordinates should remain unchanged
      expect(list[0].x, equals(item1.x));
      expect(list[0].y, equals(item1.y));
      expect(list[1].x, equals(item2.x));
      expect(list[1].y, equals(item2.y));
    });
  });
}
