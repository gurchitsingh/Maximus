// Chat state per title (CONTRACTS 4.2, 16). The server holds the history;
// this keeps the last loaded copy in memory for the session so reopening a
// title shows it at once, then refreshes. Nothing is written to drift.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_error.dart';
import '../../data/sync/sync_providers.dart';
import '../auth/auth_controller.dart';
import 'chat_api.dart';
import 'chat_models.dart';

/// What the screen has to tell the user besides the messages.
enum ChatNotice {
  none,

  /// No connection: composer inert.
  offline,

  /// 401 after the one refresh: sign in again.
  signedOut,

  /// 429 `chat_daily_cap`: back tomorrow.
  dailyCap,

  /// 503 `chat_resting` (providers down or the global cap).
  resting,

  /// 429 `rate_limited`.
  rateLimited,

  /// Any other failure.
  failed,
}

class ChatState {
  const ChatState({
    this.messages = const [],
    this.loading = true,
    this.sending = false,
    this.notice = ChatNotice.none,
    this.failedText,
    this.blockedUntil,
  });

  final List<ChatMessage> messages;

  /// The history request is in flight and there is nothing cached yet.
  final bool loading;

  /// A question is waiting for its answer (typing dots).
  final bool sending;
  final ChatNotice notice;

  /// The question that did not go through, so the composer can keep it and
  /// "Try again" can resend it.
  final String? failedText;

  /// Retry window from `retry_after_s`; sending stays off until then.
  final DateTime? blockedUntil;

  bool get isEmpty => messages.isEmpty && !sending;

  /// Whether the composer and the suggestions accept input.
  bool get canSend =>
      !sending &&
      blockedUntil == null &&
      switch (notice) {
        ChatNotice.offline ||
        ChatNotice.signedOut ||
        ChatNotice.dailyCap ||
        ChatNotice.resting ||
        ChatNotice.rateLimited => false,
        ChatNotice.none || ChatNotice.failed => true,
      };

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? loading,
    bool? sending,
    ChatNotice? notice,
    Object? failedText = _keep,
    Object? blockedUntil = _keep,
  }) => ChatState(
    messages: messages ?? this.messages,
    loading: loading ?? this.loading,
    sending: sending ?? this.sending,
    notice: notice ?? this.notice,
    failedText: identical(failedText, _keep)
        ? this.failedText
        : failedText as String?,
    blockedUntil: identical(blockedUntil, _keep)
        ? this.blockedUntil
        : blockedUntil as DateTime?,
  );

  static const _keep = Object();
}

final chatControllerProvider =
    NotifierProvider.family<ChatController, ChatState, String>(
      ChatController.new,
    );

class ChatController extends Notifier<ChatState> {
  ChatController(this.titleId);

  final String titleId;

  Timer? _unblock;
  int _local = 0;

  /// Bumped by clear() and by a new load, so a slow reply to an older
  /// request cannot overwrite newer state.
  int _epoch = 0;

  ChatApi get _api => ref.read(chatApiProvider);

  @override
  ChatState build() {
    // A different account must never see this one's chat: watching the id
    // throws the cached copy away on sign-out and on a switch.
    ref.watch(currentUserProvider.select((u) => u?.id));
    final net = ref.read(connectivityProvider).listen(_onConnectivity);
    ref.onDispose(() {
      _unblock?.cancel();
      unawaited(net.cancel());
    });
    return const ChatState();
  }

  void _onConnectivity(bool online) {
    if (!online) {
      if (state.notice == ChatNotice.none ||
          state.notice == ChatNotice.failed) {
        state = state.copyWith(notice: ChatNotice.offline);
      }
    } else if (state.notice == ChatNotice.offline) {
      state = state.copyWith(notice: ChatNotice.none);
      unawaited(load());
    }
  }

  /// Fetches the history. Cached messages stay on screen while it runs and
  /// when it fails.
  Future<void> load() async {
    final epoch = ++_epoch;
    state = state.copyWith(loading: state.messages.isEmpty);
    try {
      final messages = await _api.history(titleId);
      if (epoch != _epoch) return;
      // A question sent while the history was loading is already in the
      // list; keep what is newer than the server's copy.
      final pending = state.sending
          ? state.messages.where((m) => m.id.startsWith('local-')).toList()
          : const <ChatMessage>[];
      state = state.copyWith(
        messages: [...messages, ...pending],
        loading: false,
        notice: _clearsOnSuccess(state.notice) ? ChatNotice.none : null,
      );
    } on ApiException catch (e) {
      if (epoch != _epoch) return;
      state = state.copyWith(loading: false, notice: _noticeFor(e));
    }
  }

  /// Sends [text]. A failure keeps the text in [ChatState.failedText] and
  /// leaves no message behind (the server stores nothing on failure).
  Future<void> send(String text) async {
    final q = text.trim();
    if (q.isEmpty || q.length > 500 || !state.canSend) return;
    final mine = ChatMessage(id: 'local-${_local++}', fromUser: true, text: q);
    state = state.copyWith(
      messages: [...state.messages, mine],
      sending: true,
      notice: ChatNotice.none,
      failedText: null,
    );
    final epoch = _epoch;
    try {
      final reply = await _api.send(titleId, q);
      if (epoch != _epoch) return;
      state = state.copyWith(
        messages: [...state.messages, reply.message],
        sending: false,
      );
    } on ApiException catch (e) {
      if (epoch != _epoch) return;
      _fail(e, mine, q);
    }
  }

  void _fail(ApiException e, ChatMessage mine, String text) {
    final notice = _noticeFor(e);
    final wait = switch (notice) {
      ChatNotice.rateLimited => Duration(seconds: e.retryAfterS ?? 30),
      ChatNotice.resting => Duration(seconds: e.retryAfterS ?? 300),
      _ => null,
    };
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          if (m.id != mine.id) m,
      ],
      sending: false,
      notice: notice,
      failedText: text,
      blockedUntil: wait == null ? null : DateTime.now().add(wait),
    );
    _unblock?.cancel();
    if (wait != null) {
      _unblock = Timer(wait, () {
        state = state.copyWith(blockedUntil: null);
      });
    }
  }

  /// "Try again": resend the question that failed, or reload the history.
  Future<void> retry() async {
    if (state.blockedUntil != null) return;
    final text = state.failedText;
    state = state.copyWith(notice: ChatNotice.none);
    if (text != null) {
      await send(text);
    } else {
      await load();
    }
  }

  /// Deletes the whole chat on the server, then empties the screen.
  /// Returns false when the server call failed (the chat is untouched).
  Future<bool> clear() async {
    try {
      await _api.clear(titleId);
    } on ApiException catch (e) {
      state = state.copyWith(notice: _noticeFor(e), failedText: null);
      return false;
    }
    _epoch++;
    state = state.copyWith(
      messages: const [],
      loading: false,
      sending: false,
      notice: ChatNotice.none,
      failedText: null,
    );
    return true;
  }

  static bool _clearsOnSuccess(ChatNotice n) =>
      n == ChatNotice.offline || n == ChatNotice.failed;

  static ChatNotice _noticeFor(ApiException e) {
    if (e.isOffline) return ChatNotice.offline;
    if (e.status == 401) return ChatNotice.signedOut;
    return switch (e.code) {
      'chat_daily_cap' => ChatNotice.dailyCap,
      'chat_resting' => ChatNotice.resting,
      'rate_limited' => ChatNotice.rateLimited,
      _ => ChatNotice.failed,
    };
  }
}
