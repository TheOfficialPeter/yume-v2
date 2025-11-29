class SkipInterval {
  final double startTime;
  final double endTime;

  SkipInterval({required this.startTime, required this.endTime});

  factory SkipInterval.fromJson(Map<String, dynamic> json) {
    return SkipInterval(
      startTime: (json['startTime'] as num).toDouble(),
      endTime: (json['endTime'] as num).toDouble(),
    );
  }

  Duration get startDuration => Duration(
        milliseconds: (startTime * 1000).round(),
      );

  Duration get endDuration => Duration(
        milliseconds: (endTime * 1000).round(),
      );
}

class SkipTimeResult {
  final SkipInterval interval;
  final String skipType;
  final String skipId;
  final double? episodeLength;

  SkipTimeResult({
    required this.interval,
    required this.skipType,
    required this.skipId,
    this.episodeLength,
  });

  factory SkipTimeResult.fromJson(Map<String, dynamic> json) {
    return SkipTimeResult(
      interval: SkipInterval.fromJson(json['interval'] as Map<String, dynamic>),
      skipType: json['skipType'] as String,
      skipId: json['skipId'] as String,
      episodeLength: json['episodeLength'] != null
          ? (json['episodeLength'] as num).toDouble()
          : null,
    );
  }

  bool get isOpening => skipType == 'op' || skipType == 'mixed-op';
  bool get isEnding => skipType == 'ed' || skipType == 'mixed-ed';
  bool get isRecap => skipType == 'recap';

  String get displayName {
    switch (skipType) {
      case 'op':
        return 'Opening';
      case 'ed':
        return 'Ending';
      case 'mixed-op':
        return 'Mixed Opening';
      case 'mixed-ed':
        return 'Mixed Ending';
      case 'recap':
        return 'Recap';
      default:
        return skipType;
    }
  }
}

class SkipTimesResponse {
  final bool found;
  final List<SkipTimeResult> results;
  final String message;
  final int statusCode;

  SkipTimesResponse({
    required this.found,
    required this.results,
    required this.message,
    required this.statusCode,
  });

  factory SkipTimesResponse.fromJson(Map<String, dynamic> json) {
    List<SkipTimeResult> parseResults(dynamic resultsData) {
      if (resultsData == null) return [];
      final List resultList = resultsData as List;
      return resultList.map((json) => SkipTimeResult.fromJson(json)).toList();
    }

    return SkipTimesResponse(
      found: json['found'] as bool? ?? false,
      results: parseResults(json['results']),
      message: json['message'] as String? ?? '',
      statusCode: json['statusCode'] as int? ?? 200,
    );
  }

  SkipTimeResult? get opening {
    try {
      return results.firstWhere((r) => r.isOpening);
    } catch (e) {
      return null;
    }
  }

  SkipTimeResult? get ending {
    try {
      return results.firstWhere((r) => r.isEnding);
    } catch (e) {
      return null;
    }
  }
}
