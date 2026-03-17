import 'dart:io';
import 'dart:convert';

// ROM filename -> human-readable title conversion tester
//
// USAGE: cat ./names/ds.txt | dart run nametest.dart | head -n 20

final tag = RegExp(r'\(([^)]*)\)');

const regions = {
  'australia',
  'canada',
  'cn region lock',
  'europe',
  'france',
  'germany',
  'italy',
  'japan',
  'korea',
  'netherlands',
  'spain',
  'taiwan',
  'tw',
  'usa',
  'united kingdom',
  'world',
};
const languages = {
  'ar',
  'ca',
  'da',
  'de',
  'en',
  'es',
  'fi',
  'fr',
  'fr-ca',
  'it',
  'ja',
  'ko',
  'nl',
  'no',
  'pt',
  'ru',
  'sv',
  'tr',
  'zh',
  'zh-hans',
  'zh-hant',
};

const keywords = {
  'e',
  'jp',
  'legacy',
  'patched',
  'squirrels',
  'tengen',
  'u',
  'xenophobia',
};

bool isNoise(String inner) {
  final parts = inner.split(',').map((s) => s.trim().toLowerCase()).toList();
  if (regions.containsAll(parts)) return true;
  if (languages.containsAll(parts)) return true;
  if (keywords.contains(inner.trim().toLowerCase())) return true;
  if (inner.startsWith('Rev ') && int.tryParse(inner.substring(4)) != null) return true;
  return false;
}

String displayName(String orig) => orig
    .replaceAllMapped(tag, (m) => isNoise(m.group(1)!) ? '' : m.group(0)!)
    .trim();

// Fraction of tokens in a absent from b
double loss(String a, String b) {
  Set<String> tok(String s) => s
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((e) => e.isNotEmpty)
      .toSet();
  final A = tok(a);
  if (A.isEmpty) return 0;
  return (A.length - A.intersection(tok(b)).length) / A.length;
}

// Highlights characters in old that don't appear in neu
String diff(String old, String neu) {
  const red = '\x1b[31m', reset = '\x1b[0m';
  final buf = StringBuffer();
  var j = 0;
  for (final ch in old.split('')) {
    if (j < neu.length && ch == neu[j]) {
      buf.write(ch);
      j++;
    } else {
      buf.write('$red$ch$reset');
    }
  }
  return buf.toString();
}

void main() async {
  final lines = await stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .toList();

  lines
      .map((o) => (original: o, converted: displayName(o), loss: loss(o, displayName(o))))
      .toList()
      ..sort((a, b) => b.loss.compareTo(a.loss))
      ..forEach((r) => print('${diff(r.original, r.converted)}  (${r.loss.toStringAsFixed(2)})'));
}
