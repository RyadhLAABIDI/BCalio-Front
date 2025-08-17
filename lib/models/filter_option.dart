import 'package:image/image.dart' as img;

typedef ImageFilter = img.Image Function(img.Image);

class FilterOption {
  final String name;
  final ImageFilter? filter;

  FilterOption({required this.name, required this.filter});
}