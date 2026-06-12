import 'dart:math';

const kOsName = "jappeos";

String generateHostname() {
  final adjectives = ['swift', 'silent', 'rapid', 'lunar', 'crimson', 'cobalt', 'frosty', 'amber'];
  final nouns = ['falcon', 'comet', 'tiger', 'nebula', 'forge', 'wolf', 'rocket', 'cipher'];

  final rand = Random();
  final adjective = adjectives[rand.nextInt(adjectives.length)];
  final noun = nouns[rand.nextInt(nouns.length)];
  final number = rand.nextInt(1000);

  final sanitizedOs = kOsName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  return '$sanitizedOs-$adjective-$noun-$number';
}