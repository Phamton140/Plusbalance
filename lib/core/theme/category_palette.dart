/// Paleta de colores bien diferenciados para asignar a las categorías.
///
/// El orden es importante: se asigna a las nuevas categorías el primer
/// color de la paleta que aún no esté en uso.
const List<String> kCategoryColorPalette = [
  '#6C63FF', // violeta (primario app)
  '#00D4AA', // verde agua
  '#4D96FF', // azul
  '#FF6B6B', // rojo coral
  '#FCA311', // ámbar
  '#9D4EDD', // morado
  '#FF6B9D', // rosa
  '#00BCD4', // cian
  '#795548', // marrón
  '#8BC34A', // verde lima
  '#3D5A80', // azul acero
  '#E76F51', // terracota
  '#5E60CE', // índigo
  '#48BFE3', // celeste
  '#F4A261', // naranja claro
  '#264653', // azul oscuro
];

const String kFallbackCategoryColor = '#9E9E9E';

/// Devuelve un color (en formato hex `#RRGGBB`) que no esté en [used].
/// Si todos los de la paleta están ocupados, devuelve el primero de la
/// paleta (criterio determinista) para no bloquear la creación.
String pickUnusedCategoryColor(Set<String> used) {
  final normalized = used.map((e) => e.toLowerCase()).toSet();
  for (final c in kCategoryColorPalette) {
    if (!normalized.contains(c.toLowerCase())) return c;
  }
  return kCategoryColorPalette.first;
}
