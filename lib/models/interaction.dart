class Interaction {
  final String id;
  final DateTime at;
  final String text;
  final String kind;
  const Interaction({
    required this.id,
    required this.at,
    required this.text,
    this.kind = 'note',
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toUtc().toIso8601String(),
    'text': text,
    'kind': kind,
  };
  factory Interaction.fromJson(Map<String, dynamic> json) => Interaction(
    id: json['id'] as String,
    at: DateTime.parse(json['at'] as String),
    text: json['text'] as String,
    kind: json['kind'] as String? ?? 'note',
  );
}
