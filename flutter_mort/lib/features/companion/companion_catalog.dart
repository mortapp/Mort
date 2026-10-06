import 'package:flutter/material.dart';
import '../../core/theme/mort_pet_colors.dart';

/// Cosmetic companions are separate from the three MORT Guide mascots.
class CompanionDefinition {
  const CompanionDefinition(
    this.id,
    this.name,
    this.kind,
    this.personality,
    this.tagline,
    this.baseColor, {
    this.requiresPro = true,
  });

  final String id;
  final String name;
  final String kind;
  final String personality;
  final String tagline;
  final Color baseColor;
  final bool requiresPro;
}

const companions = <CompanionDefinition>[
  CompanionDefinition(
    'wix',
    'Wix',
    'Fox-cat',
    'Curious',
    'Curious little explorer.',
    MortPetColors.tangerine,
    requiresPro: false,
  ),
  CompanionDefinition(
    'milo',
    'Milo',
    'Bear-pup',
    'Comforting',
    'A loyal, comforting presence.',
    MortPetColors.honey,
  ),
  CompanionDefinition(
    'nova',
    'Nova',
    'Cosmic fox',
    'Dreamy',
    'Dreaming among the stars.',
    MortPetColors.lavender,
  ),
  CompanionDefinition(
    'hoots',
    'Hoots',
    'Snowy owl',
    'Thoughtful',
    'Always observing thoughtfully.',
    MortPetColors.sky,
  ),
  CompanionDefinition(
    'rocky',
    'Rocky',
    'Living rock',
    'Steady',
    'A steady, dependable friend.',
    MortPetColors.teal,
  ),
  CompanionDefinition(
    'seedy',
    'Seedy',
    'Sprout',
    'Optimistic',
    'Springing with optimism.',
    MortPetColors.leaf,
  ),
  CompanionDefinition(
    'stacky',
    'Stacky',
    'Friendly robot',
    'Helpful',
    'Organized and always helpful.',
    MortPetColors.turquoise,
  ),
  CompanionDefinition(
    'dewey',
    'Dewey',
    'Water droplet',
    'Calm',
    'A relaxing drop of calm.',
    MortPetColors.sky,
  ),
  CompanionDefinition(
    'mizu',
    'Mizu',
    'Water spirit',
    'Energetic',
    'Bouncing with energy.',
    MortPetColors.blue,
  ),
  CompanionDefinition(
    'nimbus',
    'Nimbus',
    'Living cloud',
    'Cozy',
    'A soft, sleepy little cloud.',
    MortPetColors.periwinkle,
  ),
  CompanionDefinition(
    'shadow',
    'Shadow',
    'Black cat',
    'Quiet',
    'Quiet and observant.',
    MortPetColors.plum,
  ),
  CompanionDefinition(
    'ember',
    'Ember',
    'Flame spirit',
    'Motivated',
    'A spark of motivation.',
    MortPetColors.tangerine,
  ),
  CompanionDefinition(
    'sprig',
    'Sprig',
    'Forest creature',
    'Hopeful',
    'Hopeful for new growth.',
    MortPetColors.lime,
  ),
  CompanionDefinition(
    'pebble',
    'Pebble',
    'Stone golem',
    'Reliable',
    'Solid and quietly funny.',
    MortPetColors.clay,
  ),
];

CompanionDefinition? companionById(String id) {
  for (final companion in companions) {
    if (companion.id == id) return companion;
  }
  return null;
}

bool canSelectCompanion(String id, {required bool hasPro}) {
  final companion = companionById(id);
  return companion != null && (!companion.requiresPro || hasPro);
}

const focusMinutes = <int>[15, 25, 45, 60];

class CosmeticOption {
  const CosmeticOption(this.id, this.name, {this.color});

  final String id;
  final String name;
  final Color? color;
}

const companionColors = <CosmeticOption>[
  CosmeticOption('default', 'Original'),
  CosmeticOption('pearl', 'Pearl', color: Color(0xFFFAFAFA)),
  CosmeticOption('silver', 'Silver', color: Color(0xFFD4D4D4)),
  CosmeticOption('graphite', 'Graphite', color: Color(0xFF535353)),
  CosmeticOption('midnight', 'Midnight', color: Color(0xFF1F1F1F)),
  CosmeticOption('ice', 'Ice', color: Color(0xFFEFEFEF)),
  CosmeticOption('coral', 'Coral', color: MortPetColors.coral),
  CosmeticOption('sunshine', 'Sunshine', color: MortPetColors.honey),
  CosmeticOption('mint', 'Mint', color: MortPetColors.teal),
  CosmeticOption('lavender', 'Lavender', color: MortPetColors.lavender),
  CosmeticOption('sky', 'Sky', color: MortPetColors.sky),
];

const companionAccessories = <CosmeticOption>[
  CosmeticOption('none', 'None'),
  CosmeticOption('beanie', 'Beanie'),
  CosmeticOption('crown', 'Crown'),
  CosmeticOption('bow', 'Bow'),
  CosmeticOption('headphones', 'Headphones'),
  CosmeticOption('glasses', 'Glasses'),
  CosmeticOption('scarf', 'Scarf'),
];

const companionItems = <CosmeticOption>[
  CosmeticOption('none', 'None'),
  CosmeticOption('star', 'Star'),
  CosmeticOption('book', 'Book'),
  CosmeticOption('watering_can', 'Watering can'),
  CosmeticOption('acorn', 'Acorn'),
  CosmeticOption('lantern', 'Lantern'),
  CosmeticOption('telescope', 'Telescope'),
  CosmeticOption('laptop', 'Laptop'),
  CosmeticOption('pillow', 'Pillow'),
  CosmeticOption('crystal', 'Crystal'),
  CosmeticOption('moon_charm', 'Moon charm'),
];

const companionAuras = <CosmeticOption>[
  CosmeticOption('none', 'None'),
  CosmeticOption('stars', 'Stars'),
  CosmeticOption('hearts', 'Hearts'),
  CosmeticOption('sparkles', 'Sparkles'),
  CosmeticOption('bubbles', 'Bubbles'),
  CosmeticOption('leaves', 'Leaves'),
  CosmeticOption('moon_dust', 'Moon dust'),
];

const companionEnvironments = <CosmeticOption>[
  CosmeticOption('default', 'MORT night'),
  CosmeticOption('moon_base', 'Moon base'),
  CosmeticOption('cozy_room', 'Cozy room'),
  CosmeticOption('rain_window', 'Rain window'),
  CosmeticOption('garden', 'Garden'),
  CosmeticOption('desk', 'Desk'),
  CosmeticOption('cloud_world', 'Cloud world'),
  CosmeticOption('night_forest', 'Night forest'),
  CosmeticOption('minimal_studio', 'Minimal studio'),
];
