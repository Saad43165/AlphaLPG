import 'package:flutter/foundation.dart';

import 'ur.dart';

/// The app's language. English is the default; Urdu is switched on in
/// Settings (or automatically when the phone itself is set to Urdu).
class Lang {
  Lang._();

  /// True while the app shows Urdu. Screens rebuild when this changes.
  static final ValueNotifier<bool> urdu = ValueNotifier(false);

  static bool get isUrdu => urdu.value;

  static void set(bool value) {
    if (urdu.value == value) return;
    _cache.clear();
    urdu.value = value;
  }

  /// Debug only: English texts shown in Urdu mode that have no translation.
  static final Set<String> missed = {};

  static final _cache = <String, String>{};
  static List<_Template>? _templates;

  /// Urdu for [en] (exact text first, then sentences with a name or number
  /// in them). Anything not known stays in English rather than guessing.
  static String translate(String en) {
    if (!isUrdu || en.isEmpty) return en;
    final trimmed = en.trim();
    if (trimmed.isEmpty) return en;
    final hit = _cache[trimmed] ??= _lookup(trimmed);
    if (identical(hit, trimmed) || hit == trimmed) {
      assert(() {
        if (RegExp(r'[A-Za-z]{3}').hasMatch(trimmed)) missed.add(trimmed);
        return true;
      }());
      return en;
    }
    final start = en.indexOf(trimmed);
    return en.substring(0, start) + hit + en.substring(start + trimmed.length);
  }

  static String _lookup(String s) {
    final exact = urExact[s];
    if (exact != null) return exact;
    _templates ??= _build();
    for (final t in _templates!) {
      final m = t.re.firstMatch(s);
      if (m == null) continue;
      var n = 0;
      return t.ur.replaceAllMapped(RegExp(r'\{(\d*)\}'), (g) {
        final idx = g.group(1)!.isEmpty ? ++n : int.parse(g.group(1)!);
        // A name or phrase inside the sentence is translated on its own.
        return idx <= m.groupCount ? _part(m.group(idx) ?? '') : '';
      });
    }
    // "A, B, C": translate each piece when at least one is known.
    if (s.contains(', ')) {
      final pieces = s.split(', ');
      final out = [for (final p in pieces) _part(p)];
      var changed = false;
      for (var i = 0; i < pieces.length; i++) {
        if (out[i] != pieces[i]) changed = true;
      }
      if (changed) return out.join('، ');
    }
    return s;
  }

  static String _part(String p) {
    if (!RegExp(r'[A-Za-z]').hasMatch(p)) return p;
    return _lookup(p.trim()).isEmpty ? p : _lookupKeep(p);
  }

  static String _lookupKeep(String p) {
    final t = p.trim();
    final r = _lookup(t);
    if (r == t) return p;
    final i = p.indexOf(t);
    return p.substring(0, i) + r + p.substring(i + t.length);
  }

  static List<_Template> _build() {
    final list = <_Template>[];
    urTemplates.forEach((en, ur) {
      final parts = en.split('{}');
      final pattern = parts.map(RegExp.escape).join('(.+?)');
      list.add(
        _Template(RegExp('^$pattern\$', dotAll: true), ur, parts.join().length),
      );
    });
    // The most specific sentence (most fixed words) is tried first.
    list.sort((a, b) => b.literal.compareTo(a.literal));
    return list;
  }
}

class _Template {
  _Template(this.re, this.ur, this.literal);
  final RegExp re;
  final String ur;
  final int literal;
}

/// Shorthand for texts that are not shown through [Text] (hints, tooltips,
/// notifications, error messages).
String tr(String en) => Lang.translate(en);
