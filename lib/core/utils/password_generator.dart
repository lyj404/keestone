import 'dart:math';

import 'package:flutter/foundation.dart';

class PasswordGenerator {
  static const defaultUppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const defaultLowercase = 'abcdefghijklmnopqrstuvwxyz';
  static const defaultDigits = '0123456789';
  static const defaultSymbols = '!@#\$%^&*=[]{}|;:,.<>?';
  static const defaultHyphen = '-';
  static const defaultSpace = ' ';
  static const defaultUnderscore = '_';
  static const defaultParentheses = '()';

  /// Visually ambiguous characters excluded when [excludeAmbiguous] is true.
  /// Covers the common confusable pairs: 0/O, 1/l/I, and the pipe glyph.
  static const ambiguousChars = {'0', 'O', '1', 'l', 'I', '|', '`'};

  /// A compact, memorable word list for passphrase generation. With ~256
  /// entries (~8 bits/word), 6 words yield ~48 bits of entropy — strong
  /// against online guessing while remaining human-typable. For offline
  /// attacks, prefer 8+ words or fall back to the character generator.
  /// Words must be unique: duplicates silently reduce entropy.
  @visibleForTesting
  static const passphraseWords = [
    'apple', 'azure', 'badge', 'balcony', 'banner', 'basket', 'beacon', 'berry',
    'bicycle', 'bison', 'blossom', 'bluebird', 'border', 'bracket', 'branch',
    'bridge', 'bronze', 'bubble', 'bucket', 'cactus', 'candle', 'canyon',
    'carbon', 'castle', 'cedar', 'channel', 'charm', 'cheese', 'cherry',
    'cipher', 'circuit', 'cloud', 'comet', 'compass', 'copper', 'coral',
    'cosmos', 'cotton', 'cradle', 'crown', 'crystal', 'cubic', 'cursor',
    'daisy', 'dancer', 'delta', 'desert', 'dexter', 'diamond', 'dolphin',
    'drift', 'ember', 'engine', 'fable', 'fabric', 'feather', 'ferret',
    'fjord', 'flame', 'flute', 'forest', 'fountain', 'galaxy', 'garden',
    'gemini', 'glacier', 'glider', 'granite', 'gravel', 'harbor', 'hazel',
    'helix', 'hedge', 'heron', 'honey', 'horizon', 'ivory', 'jacket', 'jaguar',
    'jasper', 'jungle', 'kettle', 'kayak', 'kindle', 'lantern', 'lattice',
    'laurel', 'lavender', 'ledger', 'lemon', 'lilac', 'lotus', 'maple',
    'marble', 'meadow', 'mirror', 'mist', 'mosaic', 'mushroom', 'myrtle',
    'nebula', 'nectar', 'needle', 'nimbus', 'oasis', 'ocean', 'opal', 'orbit',
    'orchid', 'otter', 'paddle', 'panther', 'paper', 'pearl', 'pelican',
    'pepper', 'piano', 'pillar', 'pine', 'planet', 'plum', 'pocket', 'prairie',
    'prism', 'puzzle', 'quartz', 'quasar', 'quiver', 'rabbit', 'radish',
    'rainbow', 'reef', 'relic', 'ribbon', 'river', 'rocket', 'ruby', 'saddle',
    'saffron', 'sail', 'sapphire', 'satin', 'scarf', 'shadow', 'silver',
    'slate', 'sleet', 'snail', 'snow', 'sparrow', 'spice', 'spruce', 'squash',
    'star', 'stone', 'straw', 'sugar', 'summer', 'sunset', 'sweater', 'syrup',
    'tablet', 'tangle', 'tape', 'temple', 'thicket', 'thistle', 'throne',
    'thunder', 'timber', 'topaz', 'tractor', 'trail', 'treasure', 'trident',
    'trout', 'tulip', 'tundra', 'turtle', 'unicorn', 'valley', 'velvet',
    'vendor', 'violet', 'violin', 'vortex', 'walnut', 'wander', 'willow',
    'winter', 'wolf', 'yarrow', 'zephyr', 'zinnia', 'anchor', 'arrow', 'ash',
    'attic', 'aurora', 'autumn', 'avocado', 'axiom', 'basin', 'beach',
    'beam', 'bell', 'bench', 'bloom', 'bolt', 'book', 'brooke', 'buzz',
    'cabal', 'cabin', 'carrot', 'ceiling', 'chalk', 'chord', 'clam', 'cliff',
    'clover', 'cobalt', 'crate', 'dawn', 'dewdrop', 'dill', 'dune', 'elm',
    'falcon', 'fern', 'field', 'finch', 'finland', 'fish', 'flag', 'fleece',
    'gazebo', 'globe', 'grape', 'gull', 'halo', 'hamlet', 'hare',
    'hill', 'hymn', 'iris', 'island', 'jade', 'jolly', 'kelp', 'kite',
    'lake', 'lamb', 'lamp', 'leaf', 'lily', 'linnet', 'loon', 'mango',
    'mint', 'mole', 'moon', 'moss', 'nest', 'nook', 'oat', 'ochre', 'olive',
    'owl', 'palm', 'pansy', 'pebble', 'penny', 'petal', 'plume', 'pond',
    'poppy', 'quill', 'raft', 'rain', 'raven', 'red', 'reed', 'ridge', 'robin',
    'rose', 'sage', 'scent', 'seed', 'shale', 'shark', 'shore',
    'shrub', 'silence', 'skiff', 'sky', 'slope', 'spire',
    'sprout', 'starling', 'stem', 'stork', 'sun', 'swan', 'tap', 'thaw',
    'tide', 'tiger', 'tiller', 'tower', 'town', 'trellis', 'trove', 'tuff',
    'vase', 'vault', 'veil', 'vine', 'waffle', 'wake', 'wave',
    'wheat', 'whisk', 'wick', 'wink', 'wren', 'yew', 'zest',
  ];

  static String generate({
    int length = 20,
    bool useUppercase = true,
    bool useLowercase = true,
    bool useDigits = true,
    bool useSymbols = true,
    bool useHyphen = true,
    bool useSpace = false,
    bool useUnderscore = true,
    bool useParentheses = true,
    String? customSymbols,
    bool excludeAmbiguous = false,
    bool ensureEachType = true,
  }) {
    final pools = <List<String>>[];
    void addPool(String chars) {
      var pool = chars.split('');
      if (excludeAmbiguous) pool = pool.where((c) => !ambiguousChars.contains(c)).toList();
      if (pool.isNotEmpty) pools.add(pool);
    }

    if (useUppercase) addPool(defaultUppercase);
    if (useLowercase) addPool(defaultLowercase);
    if (useDigits) addPool(defaultDigits);
    if (useSymbols) addPool(defaultSymbols);
    if (useHyphen) addPool(defaultHyphen);
    if (useSpace) addPool(defaultSpace);
    if (useUnderscore) addPool(defaultUnderscore);
    if (useParentheses) addPool(defaultParentheses);
    if (customSymbols?.isNotEmpty == true) addPool(customSymbols!);
    if (pools.isEmpty) addPool(defaultLowercase);

    final random = Random.secure();
    final allChars = <String>[];
    for (final pool in pools) {
      allChars.addAll(pool);
    }

    // Guarantee at least one character from every enabled category so the
    // result can never silently lack a chosen character class.
    final result = <String>[];
    if (ensureEachType && pools.length <= length) {
      for (final pool in pools) {
        result.add(pool[random.nextInt(pool.length)]);
      }
    }
    while (result.length < length) {
      result.add(allChars[random.nextInt(allChars.length)]);
    }
    // Shuffle so the guaranteed-per-category characters are not predictably
    // clustered at the start of the password.
    result.shuffle(random);
    return result.take(length).join();
  }

  /// Generates a memorable passphrase of [wordCount] random words joined by
  /// [separator]. An optional trailing digit is appended when [appendDigit]
  /// is true to satisfy common password policies.
  static String generatePassphrase({
    int wordCount = 6,
    String separator = '-',
    bool appendDigit = true,
  }) {
    final random = Random.secure();
    final words = <String>[];
    for (var i = 0; i < wordCount; i++) {
      words.add(passphraseWords[random.nextInt(passphraseWords.length)]);
    }
    var passphrase = words.join(separator);
    if (appendDigit) passphrase += separator + random.nextInt(10).toString();
    return passphrase;
  }
}
