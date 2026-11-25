// Chat messages as the server sends them (CONTRACTS 4 and 16). Chat is not
// stored on the phone: these live in memory for the session only.
import 'package:meta/meta.dart';

import '../../data/api/api_error.dart';

/// Chats are kept this many days on the server, rolling per message
/// (CONTRACTS 16, DECISIONS D46). The one place the number lives in the app.
const chatRetentionDays = 5;

/// The line shown under the header.
const chatRetentionNote = 'Chats are kept for $chatRetentionDays days.';

@immutable
class LessonRef {
  const LessonRef({required this.lessonId, required this.index});

  factory LessonRef.fromJson(Map<String, dynamic> json) => LessonRef(
    lessonId: json['lesson_id'] as String,
    index: json['index'] as int,
  );

  final String lessonId;

  /// 1-based lesson number, shown as "From lesson N".
  final int index;

  @override
  bool operator ==(Object other) =>
      other is LessonRef && other.lessonId == lessonId && other.index == index;

  @override
  int get hashCode => Object.hash(lessonId, index);
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.fromUser,
    required this.text,
    this.outOfScope = false,
    this.lessonRefs = const [],
  });

  /// One element of `GET /v1/me/chat/{title_id}`.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final refs = json['lesson_refs'];
    return ChatMessage(
      id: json['id'] as String,
      fromUser: json['role'] == 'user',
      text: json['text'] as String,
      outOfScope: json['kind'] == 'out_of_scope',
      lessonRefs: [
        if (refs is List)
          for (final r in refs) LessonRef.fromJson(r as Map<String, dynamic>),
      ],
    );
  }

  final String id;
  final bool fromUser;
  final String text;

  /// The fixed refusal "I only know about {title}." It reads as a normal
  /// reply; only the missing lesson tag tells it apart.
  final bool outOfScope;
  final List<LessonRef> lessonRefs;
}

/// The 200 reply of `POST /v1/titles/{id}/chat`.
@immutable
class ChatReply {
  const ChatReply({required this.message, required this.remainingToday});

  factory ChatReply.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    final text = json['text'];
    if ((kind != 'answer' && kind != 'out_of_scope') || text is! String) {
      throw const ApiException(code: ApiException.badResponse);
    }
    final refs = json['lesson_refs'];
    return ChatReply(
      message: ChatMessage(
        id: (json['message_id'] as String?) ?? 'reply',
        fromUser: false,
        text: text,
        outOfScope: kind == 'out_of_scope',
        lessonRefs: [
          if (refs is List)
            for (final r in refs) LessonRef.fromJson(r as Map<String, dynamic>),
        ],
      ),
      remainingToday: json['remaining_today'] as int?,
    );
  }

  final ChatMessage message;
  final int? remainingToday;
}
