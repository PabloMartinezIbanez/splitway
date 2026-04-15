class ManualSplitSummary {
  const ManualSplitSummary({
    required this.splitNumber,
    required this.label,
    required this.duration,
    required this.markedAt,
  });

  final int splitNumber;
  final String label;
  final Duration duration;
  final Duration markedAt;

  Map<String, dynamic> toJson() => {
        'splitNumber': splitNumber,
        'label': label,
        'durationMs': duration.inMilliseconds,
        'markedAtMs': markedAt.inMilliseconds,
      };

  factory ManualSplitSummary.fromJson(Map<String, dynamic> json) =>
      ManualSplitSummary(
        splitNumber: (json['splitNumber'] as num).toInt(),
        label: json['label'] as String,
        duration: Duration(milliseconds: (json['durationMs'] as num).toInt()),
        markedAt: Duration(milliseconds: (json['markedAtMs'] as num).toInt()),
      );
}
