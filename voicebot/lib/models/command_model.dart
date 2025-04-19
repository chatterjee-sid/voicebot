class Command {
  final String action;
  final String originalText;
  final String language;

  Command({
    required this.action,
    required this.originalText,
    required this.language,
  });

  factory Command.fromJson(Map<String, dynamic> json) {
    return Command(
      action: json['action'] ?? '',
      originalText: json['original_text'] ?? '',
      language: json['language'] ?? 'en',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'original_text': originalText,
      'language': language,
    };
  }

  @override
  String toString() {
    return 'Command: $action (from: $originalText)';
  }
}

enum VoiceLanguage {
  english,
  hindi,
  gujarati
}

extension VoiceLanguageExtension on VoiceLanguage {
  String get code {
    switch (this) {
      case VoiceLanguage.english:
        return 'en';
      case VoiceLanguage.hindi:
        return 'hi';
      case VoiceLanguage.gujarati:
        return 'gu';
    }
  }

  String get displayName {
    switch (this) {
      case VoiceLanguage.english:
        return 'English';
      case VoiceLanguage.hindi:
        return 'Hindi';
      case VoiceLanguage.gujarati:
        return 'Gujarati';
    }
  }
}
