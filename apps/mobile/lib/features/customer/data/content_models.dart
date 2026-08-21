import '../../../shared/json.dart';

class CmsDocument {
  const CmsDocument({
    required this.id,
    required this.kind,
    required this.locale,
    required this.title,
    required this.body,
    required this.version,
    required this.effectiveFrom,
  });

  final String id;
  final String kind;
  final String locale;
  final String title;
  final String body;
  final String version;
  final DateTime? effectiveFrom;

  String get kindLabel => _humanise(kind);

  factory CmsDocument.fromJson(Map<String, dynamic> json) => CmsDocument(
    id: asString(json['id']),
    kind: asString(json['kind'], 'ABOUT'),
    locale: asString(json['locale'], 'en'),
    title: asString(json['title'], 'Bites Box policy'),
    body: asString(json['body']),
    version: asString(json['version'], '1.0'),
    effectiveFrom: asDate(json['effective_from']),
  );
}

class CmsFaq {
  const CmsFaq({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    required this.locale,
  });

  final String id;
  final String category;
  final String question;
  final String answer;
  final String locale;

  String get categoryLabel => _humanise(category);

  factory CmsFaq.fromJson(Map<String, dynamic> json) => CmsFaq(
    id: asString(json['id']),
    category: asString(json['category'], 'GENERAL'),
    question: asString(json['question']),
    answer: asString(json['answer']),
    locale: asString(json['locale'], 'en'),
  );
}

String _humanise(String value) {
  final words = value.replaceAll('_', ' ').toLowerCase().split(' ');
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
