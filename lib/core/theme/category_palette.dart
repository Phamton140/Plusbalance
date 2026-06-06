import '../database/app_database.dart';

/// Paleta de colores bien diferenciados para asignar a las categorías.
///
/// El orden es importante: se asigna a las nuevas categorías el primer
/// color de la paleta que aún no esté en uso.
///
/// IMPORTANTE: Los colores reservados para categorías del sistema
/// (Metas, Transferencia) NO están en esta paleta. Ver
/// [kReservedCategoryColors].
const List<String> kCategoryColorPalette = [
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
  '#1E88E5', // azul brillante
  '#D81B60', // magenta
];

/// Colores reservados para categorías del sistema. Estos NO pueden
/// asignarse a categorías de usuario (las UI deben deshabilitarlos y
/// el asignador automático los salta).
const Set<String> kReservedCategoryColors = {
  goalDefaultCategoryColor, // #00D4AA -> Metas
  transferenciaDefaultColor, // #FB8C00 -> Transferencia
  efectivoDefaultColor, // #9E9E9E -> Cuenta Efectivo
};

const String kFallbackCategoryColor = '#4D96FF';

/// Devuelve un color (en formato hex `#RRGGBB`) que no esté en [used]
/// ni en los colores reservados del sistema. Si todos los de la paleta
/// están ocupados, devuelve el primero de la paleta (criterio
/// determinista) para no bloquear la creación.
String pickUnusedCategoryColor(Set<String> used) {
  final normalized = used.map((e) => e.toLowerCase()).toSet();
  for (final c in kCategoryColorPalette) {
    final low = c.toLowerCase();
    if (kReservedCategoryColors.contains(low)) continue;
    if (!normalized.contains(low)) return c;
  }
  return kCategoryColorPalette.first;
}
