import 'package:flutter/material.dart';

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
    Color(0xFFF8FAFC),
    requiresPro: false,
  ),
  CompanionDefinition(
    'milo',
    'Milo',
    'Bear-pup',
    'Comforting',
    'A loyal, comforting presence.',
    Color(0xFFF7F8FA),
  ),
  CompanionDefinition(
    'nova',
    'Nova',
    'Cosmic fox',
    'Dreamy',
    'Dreaming among the stars.',
    Color(0xFFE0F2FE),
  ),
  CompanionDefinition(
    'hoots',
    'Hoots',
    'Snowy owl',
    'Thoughtful',
    'Always observing thoughtfully.',
    Color(0xFFF1F5F9),
  ),
  CompanionDefinition(
    'rocky',
    'Rocky',
    'Living rock',
    'Steady',
    'A steady, dependable friend.',
    Color(0xFF94A3B8),
  ),
  CompanionDefinition(
    'seedy',
    'Seedy',
    'Sprout',
    'Optimistic',
    'Springing with optimism.',
    Color(0xFFF0FDF4),
  ),
  CompanionDefinition(
    'stacky',
    'Stacky',
    'Friendly robot',
    'Helpful',
    'Organized and always helpful.',
    Color(0xFFE2E8F0),
  ),
  CompanionDefinition(
    'dewey',
    'Dewey',
    'Water droplet',
    'Calm',
    'A relaxing drop of calm.',
    Color(0xFFCCFBF1),
  ),
  CompanionDefinition(
    'mizu',
    'Mizu',
    'Water spirit',
    'Energetic',
    'Bouncing with energy.',
    Color(0xFFBAE6FD),
  ),
  CompanionDefinition(
    'nimbus',
    'Nimbus',
    'Living cloud',
    'Cozy',
    'A soft, sleepy little cloud.',
    Color(0xFFF8FAFC),
  ),
  CompanionDefinition(
    'shadow',
    'Shadow',
    'Black cat',
    'Quiet',
    'Quiet and observant.',
    Color(0xFF475569),
  ),
  CompanionDefinition(
    'ember',
    'Ember',
    'Flame spirit',
    'Motivated',
    'A spark of motivation.',
    Color(0xFFFFFBEB),
  ),
  CompanionDefinition(
    'sprig',
    'Sprig',
    'Forest creature',
    'Hopeful',
    'Hopeful for new growth.',
    Color(0xFFF4F4F5),
  ),
  CompanionDefinition(
    'pebble',
    'Pebble',
    'Stone golem',
    'Reliable',
    'Solid and quietly funny.',
    Color(0xFFCBD5E1),
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
  CosmeticOption('pearl', 'Pearl', color: Color(0xFFF8FAFC)),
  CosmeticOption('silver', 'Silver', color: Color(0xFFCBD5E1)),
  CosmeticOption('graphite', 'Graphite', color: Color(0xFF475569)),
  CosmeticOption('midnight', 'Midnight', color: Color(0xFF172033)),
  CosmeticOption('ice', 'Ice', color: Color(0xFFE0F2FE)),
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
