enum CommandType { forward, backward, left, right, stop, unknown }

class Command {
  final CommandType type;
  final String rawText;

  Command({required this.type, required this.rawText});

  factory Command.fromString(String text) {
    final lowercaseText = text.toLowerCase().trim();

    if (lowercaseText.contains('forward')) {
      return Command(type: CommandType.forward, rawText: text);
    } else if (lowercaseText.contains('backward') ||
        lowercaseText.contains('back')) {
      return Command(type: CommandType.backward, rawText: text);
    } else if (lowercaseText.contains('left')) {
      return Command(type: CommandType.left, rawText: text);
    } else if (lowercaseText.contains('right')) {
      return Command(type: CommandType.right, rawText: text);
    } else if (lowercaseText.contains('stop') ||
        lowercaseText.contains('halt')) {
      return Command(type: CommandType.stop, rawText: text);
    } else {
      return Command(type: CommandType.unknown, rawText: text);
    }
  }

  @override
  String toString() => rawText;
}
