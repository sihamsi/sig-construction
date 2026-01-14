import 'package:flutter/material.dart';

/// Types de construction + symbologie (couleurs) utilisées partout
/// (Formulaire, liste, carte).
///
/// 👉 Pour changer une couleur, modifie simplement le champ `hex` (et la `color`).
class ConstructionTypeDef {
  final String code; // valeur stockée en BD (type_construction)
  final String label; // affichage
  final Color color; // couleur côté Flutter (liste, chips)
  final String hex; // couleur côté Leaflet (ex: "#E53935")

  const ConstructionTypeDef({
    required this.code,
    required this.label,
    required this.color,
    required this.hex,
  });
}

class ConstructionTypes {
  ConstructionTypes._();

  /// ⚠️ Ajoute ici autant de types que tu veux.
  /// Les `code` doivent rester stables (car stockés en SQLite).
  static const List<ConstructionTypeDef> all = [
    ConstructionTypeDef(
      code: 'residentiel',
      label: 'Résidentiel',
      color: Color(0xFFE53935),
      hex: '#E53935',
    ),
    ConstructionTypeDef(
      code: 'commercial',
      label: 'Commercial',
      color: Color(0xFF1E88E5),
      hex: '#1E88E5',
    ),
    ConstructionTypeDef(
      code: 'industriel',
      label: 'Industriel',
      color: Color(0xFFFB8C00),
      hex: '#FB8C00',
    ),
    ConstructionTypeDef(
      code: 'administratif',
      label: 'Administratif',
      color: Color(0xFF8E24AA),
      hex: '#8E24AA',
    ),
    ConstructionTypeDef(
      code: 'equipement_public',
      label: 'Équipement public',
      color: Color(0xFF43A047),
      hex: '#43A047',
    ),
    ConstructionTypeDef(
      code: 'touristique',
      label: 'Touristique',
      color: Color(0xFFFDD835),
      hex: '#FDD835',
    ),
    ConstructionTypeDef(
      code: 'agricole',
      label: 'Agricole',
      color: Color(0xFF6D4C41),
      hex: '#6D4C41',
    ),
    ConstructionTypeDef(
      code: 'mixte',
      label: 'Mixte',
      color: Color(0xFF00897B),
      hex: '#00897B',
    ),
    ConstructionTypeDef(
      code: 'autre',
      label: 'Autre',
      color: Color(0xFF546E7A),
      hex: '#546E7A',
    ),
  ];

  static const String defaultCode = 'residentiel';

  static ConstructionTypeDef byCode(String? code) {
    final c = (code ?? '').trim();
    for (final t in all) {
      if (t.code == c) return t;
    }
    return all.last; // "autre"
  }

  static String labelOf(String? code) => byCode(code).label;
  static Color colorOf(String? code) => byCode(code).color;
  static String hexOf(String? code) => byCode(code).hex;

  /// Map code -> hex (utile si tu veux envoyer tout le dictionnaire à Leaflet)
  static Map<String, String> hexMap() => {for (final t in all) t.code: t.hex};
}
