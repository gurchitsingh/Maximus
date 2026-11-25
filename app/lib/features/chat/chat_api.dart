// The three chat endpoints (CONTRACTS 4, 16). The bearer and the one
// refresh-and-retry on 401 come from the shared ApiClient; no key is ever
// in the app (the provider keys live on the server).
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_error.dart';
import '../../data/providers.dart';
import 'chat_models.dart';

abstract class ChatApi {
  /// The newest page of this title's history, oldest first.
  Future<List<ChatMessage>> history(String titleId);

  /// Sends one question. Throws [ApiException] on any failure.
  Future<ChatReply> send(String titleId, String message);

  /// Deletes this title's history on the server.
  Future<void> clear(String titleId);
}

class HttpChatApi implements ChatApi {
  HttpChatApi(this._client);

  final ApiClient _client;

  static String _enc(String id) => Uri.encodeComponent(id);

  @override
  Future<List<ChatMessage>> history(String titleId) async {
    // `limit` 100 is the maximum; 5 days of 20 chats a day fits in it.
    final r = await _client.get(
      '/v1/me/chat/${_enc(titleId)}',
      query: {'limit': '100'},
    );
    if (r is! ApiBody) {
      throw const ApiException(code: ApiException.badResponse);
    }
    try {
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      return [
        for (final m in json['messages'] as List)
          ChatMessage.fromJson(m as Map<String, dynamic>),
      ];
    } on Object {
      throw const ApiException(code: ApiException.badResponse);
    }
  }

  @override
  Future<ChatReply> send(String titleId, String message) async {
    final json = await _client.send(
      'POST',
      '/v1/titles/${_enc(titleId)}/chat',
      body: {'message': message},
    );
    if (json == null) {
      throw const ApiException(code: ApiException.badResponse);
    }
    try {
      return ChatReply.fromJson(json);
    } on ApiException {
      rethrow;
    } on Object {
      throw const ApiException(code: ApiException.badResponse);
    }
  }

  @override
  Future<void> clear(String titleId) async {
    await _client.send('DELETE', '/v1/me/chat/${_enc(titleId)}');
  }
}

final chatApiProvider = Provider<ChatApi>(
  (ref) => HttpChatApi(ref.watch(apiClientProvider)),
);
