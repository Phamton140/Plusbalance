import 'package:flutter/material.dart';

/// Conjunto de íconos disponibles para categorías (y servicios, que heredan
/// de la categoría padre). El identificador almacenado en la base de datos
/// es el `codePoint` del `IconData` como `String`.
///
/// Al estar definidos como `const` y referenciados siempre a través de este
/// mapa, el tree-shaker puede identificar todos los íconos usados en tiempo
/// de compilación y descartar el resto del font.
const List<IconData> _kSelectableCategoryIcons = [
  Icons.shopping_cart,
  Icons.restaurant,
  Icons.directions_bus,
  Icons.movie,
  Icons.medical_services,
  Icons.home,
  Icons.church,
  Icons.flight,
  Icons.fitness_center,
  Icons.school,
  Icons.pets,
  Icons.sports_esports,
];

/// Code point -> IconData. Construido a partir de la lista seleccionable para
/// mantener una sola fuente de verdad.
final Map<int, IconData> kCategoryIconByCodePoint = {
  for (final icon in _kSelectableCategoryIcons) icon.codePoint: icon,
};

/// Lista de íconos seleccionables en el formulario de categorías.
List<IconData> get selectableCategoryIcons => _kSelectableCategoryIcons;

/// Devuelve el `IconData` correspondiente al code point almacenado en BD.
/// Si el code point no está en la lista, devuelve `Icons.label`.
IconData iconFromCodePoint(String codePoint) {
  final cp = int.tryParse(codePoint);
  if (cp == null) return Icons.label;
  return kCategoryIconByCodePoint[cp] ?? Icons.label;
}
