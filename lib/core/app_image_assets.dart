/// Central registry for optional, locally supplied food and meal images.
///
/// To add an image later, place a file with the matching name in
/// `assets/images/foods/`. The folder is already included in `pubspec.yaml`,
/// so no additional asset registration is required. Until then, the UI shows
/// the "Image here" placeholder.
class AppImageAssets {
  const AppImageAssets._();

  static const String _base = 'assets/images/foods/';

  /// Optional meal-category image names. These are ready for any future meal
  /// category cards; no images are displayed until the corresponding UI uses
  /// them.
  static const Map<String, String> mealCategoryPaths = {
    'breakfast': '${_base}category_breakfast.webp',
    'lunch': '${_base}category_lunch.webp',
    'dinner': '${_base}category_dinner.webp',
    'snack': '${_base}category_snack.webp',
  };

  /// Default convention: `assets/images/foods/<lowercase-food-name>.webp`.
  /// For example, "Chicken Adobo" becomes `chicken_adobo.webp`.
  static String foodPath(String foodName) {
    final key = foodName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '$_base$key.webp';
  }
}
