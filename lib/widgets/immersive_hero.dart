export 'immersive_hero_config.dart';

// Re-export the platform implementation.
export 'immersive_hero_stub.dart'
    if (dart.library.html) 'immersive_hero_web.dart'
    if (dart.library.io) 'immersive_hero_mobile.dart';
