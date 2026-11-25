// Chat inside a title (FLOW 6, CONTRACTS 4.2 and 16), in the whole app with
// a fake ChatApi: no network. One test at the end drives the real HTTP
// client against a fake server to prove the 401 refresh-and-retry.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maximus/app/app.dart';
import 'package:maximus/app/router.dart';
import 'package:maximus/data/api/api_error.dart';
import 'package:maximus/data/api/auth_tokens.dart';
import 'package:maximus/features/chat/chat_api.dart';
import 'package:maximus/features/chat/chat_models.dart';

import '../../app_harness.dart';
import '../../fakes/fake_auth.dart';
import '../../helpers.dart';

/// Scriptable chat server: the history it holds, the next failure, and a
/// gate to hold a reply open (typing state).
class FakeChatApi implements ChatApi {
  List<ChatMessage> stored = [];
  ApiException? historyError;
  ApiException? sendError;
  ApiException? clearError;
  Completer<void>? gate;
  final sent = <String>[];
  int clears = 0;
  int historyCalls = 0;

  ChatReply Function(String q) reply = (q) => const ChatReply(
    message: ChatMessage(
      id: 'm-reply',
      fromUser: false,
      text: 'Chanakya wrote the Arthashastra.',
      lessonRefs: [LessonRef(lessonId: 'chanakya.l01', index: 1)],
    ),
    remainingToday: 19,
  );

  @override
  Future<List<ChatMessage>> history(String titleId) async {
    historyCalls++;
    if (historyError != null) throw historyError!;
    return [...stored];
  }

  @override
  Future<ChatReply> send(String titleId, String message) async {
    sent.add(message);
    if (gate != null) await gate!.future;
    if (sendError != null) throw sendError!;
    final r = reply(message);
    stored = [
      ...stored,
      ChatMessage(id: 'u${sent.length}', fromUser: true, text: message),
      r.message,
    ];
    return r;
  }

  @override
  Future<void> clear(String titleId) async {
    if (clearError != null) throw clearError!;
    clears++;
    stored = [];
  }
}

const _offline = ApiException(code: ApiException.offline);
ApiException _http(int status, String code, {int? retry}) =>
    ApiException(code: code, status: status, retryAfterS: retry);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaximusApp)));

Future<AppHarness> _pump(
  WidgetTester tester,
  FakeChatApi api, {
  String titleId = 'chanakya',
  FakeAuthBackend? backend,
}) async {
  usePixel8(tester);
  final h = await AppHarness.pump(
    tester,
    backend: backend,
    overrides: [chatApiProvider.overrideWithValue(api)],
  );
  _container(tester).read(routerProvider).go('/title/$titleId/chat');
  await AppHarness.settle(tester);
  return h;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await AppHarness.settle(tester);
}

Future<void> _ask(WidgetTester tester, String q) async {
  await tester.enterText(find.byType(TextField), q);
  await tester.pump();
  await _tap(tester, find.bySemanticsLabel('Send'));
}

bool _composerEnabled(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).enabled ?? true;

void main() {
  testWidgets('empty chat: header, retention note, three suggestions', (
    tester,
  ) async {
    final api = FakeChatApi();
    await _pump(tester, api);

    expect(find.text('CHANAKYA'), findsOneWidget);
    expect(find.text('Ask me anything about Chanakya.'), findsOneWidget);
    expect(find.text(chatRetentionNote), findsOneWidget);
    expect(chatRetentionNote, 'Chats are kept for 5 days.');
    // Thinker questions, written by hand.
    expect(find.text('What is Chanakya known for?'), findsOneWidget);
    expect(find.text('What were the big ideas?'), findsOneWidget);
    expect(find.text('How can I use these ideas today?'), findsOneWidget);
    expect(find.text('Clear this chat'), findsNothing);
    expect(api.historyCalls, 1);
  });

  testWidgets('suggestions follow the title kind', (tester) async {
    await _pump(tester, FakeChatApi(), titleId: 'roman-history');
    expect(find.text('Give me a short summary'), findsOneWidget);
    expect(find.text('Who were the key people?'), findsOneWidget);
    expect(find.text('Why does it still matter today?'), findsOneWidget);
  });

  testWidgets('send: question, typing dots, answer with a lesson tag', (
    tester,
  ) async {
    final api = FakeChatApi()..gate = Completer<void>();
    await _pump(tester, api);

    await _ask(tester, 'Who taught Chandragupta?');
    expect(find.text('Who taught Chandragupta?'), findsOneWidget);
    expect(find.bySemanticsLabel('Chat is typing'), findsOneWidget);
    expect(_composerEnabled(tester), isFalse);
    // The empty-state suggestions are gone once a question is on screen.
    expect(find.text('Ask me anything about Chanakya.'), findsNothing);

    api.gate!.complete();
    await AppHarness.settle(tester);
    expect(api.sent, ['Who taught Chandragupta?']);
    expect(find.text('Chanakya wrote the Arthashastra.'), findsOneWidget);
    expect(find.text('From lesson 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Chat is typing'), findsNothing);
    expect(_composerEnabled(tester), isTrue);
  });

  testWidgets('tapping a suggestion sends it', (tester) async {
    final api = FakeChatApi();
    await _pump(tester, api);
    await _tap(tester, find.text('What were the big ideas?'));
    expect(api.sent, ['What were the big ideas?']);
  });

  testWidgets('the lesson tag opens that lesson in the reader', (tester) async {
    final api = FakeChatApi();
    await _pump(tester, api);
    await _ask(tester, 'Who was he?');

    await _tap(tester, find.text('From lesson 1'));
    final router = _container(tester).read(routerProvider);
    expect(router.state.uri.path, '/title/chanakya/lesson/chanakya.l01');
    expect(find.text('Who was Chanakya?'), findsWidgets);
  });

  testWidgets('an off-topic refusal is a normal reply with no tag', (
    tester,
  ) async {
    final api = FakeChatApi()
      ..reply = (_) => const ChatReply(
        message: ChatMessage(
          id: 'm2',
          fromUser: false,
          text: 'I only know about Chanakya.',
          outOfScope: true,
        ),
        remainingToday: 18,
      );
    await _pump(tester, api);
    await _ask(tester, 'Who won the match?');

    expect(find.text('I only know about Chanakya.'), findsOneWidget);
    expect(find.textContaining('From lesson'), findsNothing);
    expect(find.text('Something went wrong'), findsNothing);
    expect(_composerEnabled(tester), isTrue);
  });

  testWidgets('history loads from the server and survives reopening', (
    tester,
  ) async {
    final api = FakeChatApi()
      ..stored = const [
        ChatMessage(id: 'a', fromUser: true, text: 'Earlier question'),
        ChatMessage(
          id: 'b',
          fromUser: false,
          text: 'Earlier answer',
          lessonRefs: [LessonRef(lessonId: 'chanakya.l01', index: 1)],
        ),
      ];
    await _pump(tester, api);

    expect(find.text('Earlier question'), findsOneWidget);
    expect(find.text('Earlier answer'), findsOneWidget);
    expect(find.text('From lesson 1'), findsOneWidget);
    expect(find.text('Ask me anything about Chanakya.'), findsNothing);
    expect(find.text('Clear this chat'), findsOneWidget);

    // Leave and come back: the session copy shows, then the server's.
    final router = _container(tester).read(routerProvider);
    router.go('/home');
    await AppHarness.settle(tester);
    api.stored = [
      ...api.stored,
      const ChatMessage(id: 'c', fromUser: true, text: 'Newer question'),
    ];
    router.go('/title/chanakya/chat');
    await AppHarness.settle(tester);
    expect(api.historyCalls, 2);
    expect(find.text('Newer question'), findsOneWidget);
  });

  testWidgets('clear asks first, then deletes on the server', (tester) async {
    final api = FakeChatApi()
      ..stored = const [
        ChatMessage(id: 'a', fromUser: true, text: 'Earlier question'),
      ];
    await _pump(tester, api);

    await _tap(tester, find.text('Clear this chat'));
    expect(find.text('Clear this chat?'), findsOneWidget);
    await _tap(tester, find.text('Keep chat'));
    expect(api.clears, 0);
    expect(find.text('Earlier question'), findsOneWidget);

    await _tap(tester, find.text('Clear this chat'));
    await _tap(tester, find.bySemanticsLabel('Clear chat'));
    expect(api.clears, 1);
    expect(find.text('Earlier question'), findsNothing);
    expect(find.text('Ask me anything about Chanakya.'), findsOneWidget);
  });

  testWidgets('a failed clear keeps the chat and says so', (tester) async {
    final api = FakeChatApi()
      ..clearError = _offline
      ..stored = const [
        ChatMessage(id: 'a', fromUser: true, text: 'Earlier question'),
      ];
    await _pump(tester, api);
    await _tap(tester, find.text('Clear this chat'));
    await _tap(tester, find.bySemanticsLabel('Clear chat'));

    expect(find.text('Earlier question'), findsOneWidget);
    expect(find.text('Chat needs internet'), findsWidgets);
  });

  group('error states', () {
    testWidgets('offline on open: input disabled, picture and Try again', (
      tester,
    ) async {
      final api = FakeChatApi()..historyError = _offline;
      await _pump(tester, api);

      expect(find.text('Chat needs internet'), findsWidgets);
      expect(find.text('Try again'), findsOneWidget);
      expect(_composerEnabled(tester), isFalse);
      // Suggestions are inert too.
      await _tap(tester, find.text('What were the big ideas?'));
      expect(api.sent, isEmpty);

      // Back online: Try again reloads and unlocks the composer.
      api.historyError = null;
      await _tap(tester, find.text('Try again'));
      expect(_composerEnabled(tester), isTrue);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('losing the network disables chat, regaining it enables', (
      tester,
    ) async {
      final api = FakeChatApi();
      final h = await _pump(tester, api);
      expect(_composerEnabled(tester), isTrue);

      h.net.add(false);
      await AppHarness.settle(tester);
      expect(_composerEnabled(tester), isFalse);
      expect(find.text('Chat needs internet'), findsWidgets);

      h.net.add(true);
      await AppHarness.settle(tester);
      expect(_composerEnabled(tester), isTrue);
    });

    testWidgets('offline while sending keeps the typed question', (
      tester,
    ) async {
      final api = FakeChatApi()..sendError = _offline;
      await _pump(tester, api);
      await _ask(tester, 'Who taught him?');

      expect(find.text('Chat needs internet'), findsWidgets);
      expect(_composerEnabled(tester), isFalse);
      // The question is not left as a bubble; it is back in the composer.
      expect(find.text('Who taught him?'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Who taught him?',
      );

      api.sendError = null;
      await _tap(tester, find.text('Try again'));
      expect(api.sent, ['Who taught him?', 'Who taught him?']);
      expect(find.text('Chanakya wrote the Arthashastra.'), findsOneWidget);
    });

    testWidgets('daily cap: resting card, composer off, one action', (
      tester,
    ) async {
      final api = FakeChatApi()
        ..sendError = _http(429, 'chat_daily_cap', retry: 40000);
      await _pump(tester, api);
      await _ask(tester, 'One more?');

      expect(find.text('Chat is resting'), findsOneWidget);
      expect(find.text('Chat is resting, back tomorrow.'), findsOneWidget);
      expect(_composerEnabled(tester), isFalse);
      expect(find.text('Back to lessons'), findsOneWidget);
    });

    testWidgets(
      'providers down: resting card, Try again waits for the window',
      (tester) async {
        final api = FakeChatApi()
          ..sendError = _http(503, 'chat_resting', retry: 300);
        await _pump(tester, api);
        await _ask(tester, 'Anything?');

        expect(find.text('Chat is resting'), findsOneWidget);
        expect(
          find.text('It needs a short break. Try again in a few minutes.'),
          findsOneWidget,
        );
        expect(_composerEnabled(tester), isFalse);

        // Before the window ends the button does nothing.
        await _tap(tester, find.text('Try again'));
        expect(api.sent, ['Anything?']);

        // After it, Try again resends the same question.
        api.sendError = null;
        await tester.pump(const Duration(seconds: 301));
        await _tap(tester, find.text('Try again'));
        expect(api.sent, ['Anything?', 'Anything?']);
        expect(find.text('Chat is resting'), findsNothing);
        expect(find.text('Chanakya wrote the Arthashastra.'), findsOneWidget);
      },
    );

    testWidgets('rate limit: a note, composer off until the wait is over', (
      tester,
    ) async {
      final api = FakeChatApi()
        ..sendError = _http(429, 'rate_limited', retry: 20);
      await _pump(tester, api);
      await _ask(tester, 'Fast one');

      expect(find.text('One moment'), findsOneWidget);
      expect(_composerEnabled(tester), isFalse);

      api.sendError = null;
      await tester.pump(const Duration(seconds: 21));
      await _tap(tester, find.text('Try again'));
      expect(find.text('Chanakya wrote the Arthashastra.'), findsOneWidget);
      expect(_composerEnabled(tester), isTrue);
    });

    testWidgets('any other failure: generic card, composer stays on', (
      tester,
    ) async {
      final api = FakeChatApi()..sendError = _http(500, 'internal_error');
      await _pump(tester, api);
      await _ask(tester, 'Hello?');

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(_composerEnabled(tester), isTrue);
      expect(find.text('Hello?'), findsOneWidget);
    });

    testWidgets('signed out (401 after the refresh): Sign in', (tester) async {
      final api = FakeChatApi()..sendError = _http(401, 'unauthorized');
      await _pump(tester, api);
      await _ask(tester, 'Hello?');

      expect(find.text('Please sign in again'), findsOneWidget);
      expect(_composerEnabled(tester), isFalse);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets(
      'the server refuses the refresh token: leaves the chat for sign-in',
      (tester) async {
        final server = _ChatServer();
        await AppHarness.pump(tester, backend: server);
        _container(tester).read(routerProvider).go('/title/chanakya/chat');
        await AppHarness.settle(tester);
        expect(find.text('Ask me anything about Chanakya.'), findsOneWidget);

        server.expireAccessTokens();
        server.refreshFailure = (401, 'token_invalid');
        await _ask(tester, 'Hello?');

        expect(server.posts, 1, reason: 'no retry after a refused refresh');
        final path = _container(tester).read(routerProvider).state.uri.path;
        expect(path, isNot(contains('/chat')));
        expect(find.byType(TextField), findsNothing);
      },
    );

    testWidgets('the biggest text size still fits every state', (tester) async {
      final api = FakeChatApi()
        ..sendError = _http(503, 'chat_resting', retry: 300);
      usePixel8(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 3.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await AppHarness.pump(
        tester,
        overrides: [chatApiProvider.overrideWithValue(api)],
      );
      _container(tester).read(routerProvider).go('/title/chanakya/chat');
      await AppHarness.settle(tester);
      expect(tester.takeException(), isNull);

      await _ask(tester, 'Anything?');
      expect(find.text('Chat is resting'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('buttons carry labels', (tester) async {
    await _pump(tester, FakeChatApi());
    expect(find.bySemanticsLabel('Send'), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsWidgets);
  });

  testWidgets('401 on a real call: refresh once, retry, no sign-out', (
    tester,
  ) async {
    final server = _ChatServer()
      ..history = [
        {
          'id': 'h1',
          'role': 'user',
          'text': 'Saved question',
          'kind': null,
          'lesson_refs': <Object>[],
          'created_at': '2026-11-25T10:00:00Z',
        },
      ];
    usePixel8(tester);
    final h = await AppHarness.pump(tester, backend: server);
    _container(tester).read(routerProvider).go('/title/chanakya/chat');
    await AppHarness.settle(tester);
    expect(find.text('Saved question'), findsOneWidget);

    // The access token dies; the next chat call must refresh and retry.
    server.expireAccessTokens();
    final refreshes = server.count('POST /v1/auth/refresh');
    await _ask(tester, 'Who taught him?');

    expect(server.count('POST /v1/auth/refresh'), refreshes + 1);
    expect(server.posts, 2, reason: 'one 401, one retry');
    expect(server.lastBody, {'message': 'Who taught him?'});
    expect(find.text('Server reply'), findsOneWidget);
    expect(find.text('From lesson 2'), findsOneWidget);
    expect(find.text('Please sign in again'), findsNothing);
    expect(h.store.values[TokenKeys.refreshToken], isNotNull);

    // Clear goes to DELETE /v1/me/chat/{id}.
    await _tap(tester, find.text('Clear this chat'));
    await _tap(tester, find.bySemanticsLabel('Clear chat'));
    expect(server.deletes, ['/v1/me/chat/chanakya']);
    expect(find.text('Saved question'), findsNothing);
  });
}

/// The auth fake plus the chat endpoints, behind the same tokens.
class _ChatServer extends FakeAuthBackend {
  List<Map<String, Object?>> history = [];
  int posts = 0;
  Map<String, dynamic>? lastBody;
  final deletes = <String>[];

  ResponseBody _json(int status, Object? body) => ResponseBody.fromString(
    body == null ? '' : jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = o.uri.path;
    final isChat =
        path.startsWith('/v1/titles/') && path.endsWith('/chat') ||
        path.startsWith('/v1/me/chat/');
    if (!isChat) return super.fetch(o, requestStream, cancelFuture);

    // Same bearer rules as GET /v1/me: expired or unknown token -> 401.
    final probe = RequestOptions(
      path: '/v1/me',
      baseUrl: o.baseUrl,
      headers: o.headers,
    );
    final who = await super.fetch(probe, null, null);
    if (who.statusCode != 200) {
      if (o.method == 'POST') posts++;
      return who;
    }
    switch ('${o.method} $path') {
      case 'POST /v1/titles/chanakya/chat':
        posts++;
        final bytes = await requestStream!.expand((b) => b).toList();
        lastBody = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        return _json(200, {
          'kind': 'answer',
          'text': 'Server reply',
          'lesson_refs': [
            {'lesson_id': 'chanakya.l02', 'index': 2},
          ],
          'remaining_today': 19,
          'message_id': '7c0e5b1a-2d94-4f6b-8a3e-9b1d4c5e6f70',
        });
      case 'GET /v1/me/chat/chanakya':
        return _json(200, {'messages': history, 'has_more': false});
      case 'DELETE /v1/me/chat/chanakya':
        deletes.add(path);
        history = [];
        return _json(204, null);
    }
    return _json(404, {
      'error': {'code': 'not_found', 'message': '', 'details': null},
    });
  }

  @override
  void close({bool force = false}) {}
}
