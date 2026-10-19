class Devotion {
  final String id;
  final String packageId;
  final String title;
  final String tag;
  final String body;
  final String? source;
  final int targetCount;
  final bool verified;

  const Devotion({
    required this.id,
    required this.packageId,
    required this.title,
    required this.tag,
    required this.body,
    required this.source,
    required this.targetCount,
    required this.verified,
  });

  factory Devotion.fromJson(Map<String, dynamic> json) => Devotion(
        id: json['id'] as String,
        packageId: json['packageId'] as String,
        title: json['title'] as String,
        tag: json['tag'] as String,
        body: json['body'] as String,
        source: json['source'] as String?,
        targetCount: (json['targetCount'] as num?)?.toInt() ?? 1,
        verified: json['verified'] as bool? ?? false,
      );
}
