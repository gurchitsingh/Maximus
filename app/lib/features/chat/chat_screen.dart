// Chat inside a title (FLOW 6, CONTRACTS 4.2 and 16). Locked to one title:
// bubbles, a composer, three suggested questions while the chat is empty,
// and a state card for every way the server can say no. The history is the
// server's; this screen only shows the in-memory copy (chat_controller).
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/util/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import 'chat_controller.dart';
import 'chat_models.dart';
import 'chat_suggestions.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.titleId});

  final String titleId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Show the cached copy now, refresh from the server right after.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(chatControllerProvider(widget.titleId).notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ChatController get _chat =>
      ref.read(chatControllerProvider(widget.titleId).notifier);

  void _send([String? text]) {
    final q = (text ?? _text.text).trim();
    if (q.isEmpty) return;
    _text.clear();
    _chat.send(q);
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _openLesson(LessonRef ref0) {
    final d = ref.read(titleDetailProvider(widget.titleId)).value;
    // The id is the contract's; the number is the fallback if a lesson was
    // renumbered since the answer was stored.
    final lesson = d == null
        ? null
        : (d.lessons.where((l) => l.id == ref0.lessonId).firstOrNull ??
              d.lessons.where((l) => l.index == ref0.index).firstOrNull);
    context.push(
      AppRoute.reader.location({
        'titleId': widget.titleId,
        'lessonId': lesson?.id ?? ref0.lessonId,
      }),
    );
  }

  Future<void> _confirmClear() async {
    final ok = await _confirmClearChat(context);
    if (ok != true || !mounted) return;
    final cleared = await _chat.clear();
    if (!mounted) return;
    if (cleared) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final id = widget.titleId;
    final s = ref.watch(chatControllerProvider(id));
    final summary = ref.watch(catalogueProvider).value?.title(id);
    final name = summary?.name ?? '';

    ref.listen(chatControllerProvider(id), (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          prev?.sending != next.sending ||
          prev?.notice != next.notice) {
        _toBottom();
      }
      // Keep the question that did not go through (CONTRACTS 4.2).
      final failed = next.failedText;
      if (failed != null && failed != prev?.failedText) {
        _text.value = TextEditingValue(
          text: failed,
          selection: TextSelection.collapsed(offset: failed.length),
        );
      }
    });

    return Column(
      children: [
        MxPushedTopBar(
          kicker: name,
          kickerColor: summary == null
              ? null
              : readableTint(hexColor(summary.tint), c.bg),
          title: 'Chat',
          onBack: () => context.pop(),
        ),
        _NoteRow(
          showClear: s.messages.isNotEmpty && !s.sending,
          onClear: _confirmClear,
        ),
        Expanded(
          child: s.loading && s.messages.isEmpty
              ? const LoadingState()
              : _Body(
                  state: s,
                  name: name,
                  kind: summary?.kind ?? 'topic',
                  controller: _scroll,
                  onSuggestion: s.canSend ? _send : null,
                  onLesson: _openLesson,
                  onRetry: _chat.retry,
                  onSignIn: () => context.go(AppRoute.signIn.location()),
                  onLessons: () => context.pop(),
                ),
        ),
        _Composer(
          controller: _text,
          name: name,
          enabled: s.canSend,
          offline: s.notice == ChatNotice.offline,
          onSend: _send,
        ),
      ],
    );
  }
}

Future<bool?> _confirmClearChat(BuildContext context) => showDialog<bool>(
  context: context,
  barrierColor: MxFixed.sheetBackdrop,
  builder: (ctx) {
    final c = ctx.mx;
    return Dialog(
      backgroundColor: c.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MxRadius.sheet),
        side: BorderSide(color: c.divider),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Clear this chat?',
              style: MxText.emptyTitle.copyWith(color: c.text),
            ),
            const SizedBox(height: 10),
            Text(
              'This deletes your questions and the answers for this title '
              'from your account. It cannot be undone.',
              style: MxText.body.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: 20),
            SecondaryButton(
              label: 'Keep chat',
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: MxPressable(
                onPressed: () => Navigator.of(ctx).pop(true),
                fill: c.error,
                semanticLabel: 'Clear chat',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(
                      'Clear chat',
                      textAlign: TextAlign.center,
                      style: MxText.buttonM.copyWith(color: c.bg),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
);

/// "Chats are kept for 5 days." and the clear action, wrapping at any size.
class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.showClear, required this.onClear});

  final bool showClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MxSpace.gutter),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            chatRetentionNote,
            style: MxText.caption.copyWith(color: c.textMuted),
          ),
          if (showClear)
            MxTextButton(label: 'Clear this chat', onPressed: onClear),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.name,
    required this.kind,
    required this.controller,
    required this.onSuggestion,
    required this.onLesson,
    required this.onRetry,
    required this.onSignIn,
    required this.onLessons,
  });

  final ChatState state;
  final String name;
  final String kind;
  final ScrollController controller;
  final ValueChanged<String>? onSuggestion;
  final ValueChanged<LessonRef> onLesson;
  final VoidCallback onRetry;
  final VoidCallback onSignIn;
  final VoidCallback onLessons;

  @override
  Widget build(BuildContext context) {
    final notice = state.notice == ChatNotice.none
        ? null
        : _NoticeCard(
            notice: state.notice,
            ready: state.blockedUntil == null,
            onRetry: onRetry,
            onSignIn: onSignIn,
            onLessons: onLessons,
          );
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(MxSpace.gutter, 8, MxSpace.gutter, 12),
      children: [
        if (state.isEmpty)
          _Greeting(name: name, kind: kind, onTap: onSuggestion),
        for (final m in state.messages) _Bubble(message: m, onLesson: onLesson),
        if (state.sending) const _TypingBubble(),
        ?notice,
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.name,
    required this.kind,
    required this.onTap,
  });

  final String name;
  final String kind;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: _Picture(icon: MxIcons.chat, color: c.accentText),
          ),
          const SizedBox(height: 16),
          Text(
            'Ask me anything about $name.',
            textAlign: TextAlign.center,
            style: MxText.emptyTitle.copyWith(color: c.text),
          ),
          const SizedBox(height: 18),
          for (final q in chatSuggestions(kind: kind, name: name)) ...[
            _SuggestionButton(
              label: q,
              onPressed: onTap == null ? null : () => onTap!(q),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// A suggested question. Wraps instead of scrolling so it reads at the
/// largest text size; 0.4 opacity and inert when chat is off (4.2).
class _SuggestionButton extends StatelessWidget {
  const _SuggestionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: MxPressable(
          onPressed: onPressed,
          border: BorderSide(color: c.divider, width: 2),
          borderRadius: BorderRadius.circular(MxRadius.option),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: MxText.chip.copyWith(color: c.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Picture extends StatelessWidget {
  const _Picture({required this.icon, required this.color});

  final MxIcons icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return ExcludeSemantics(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          shape: BoxShape.circle,
        ),
        child: Center(child: MxIcon(icon, size: 32, color: color)),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onLesson});

  final ChatMessage message;
  final ValueChanged<LessonRef> onLesson;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final mine = message.fromUser;
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width * 0.85),
          child: Semantics(
            container: true,
            label: mine ? 'You said' : 'Chat said',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? c.accent : c.surfaceRaised,
                borderRadius: BorderRadius.circular(MxRadius.option),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: (mine ? MxText.chatUser : MxText.chatAi).copyWith(
                      color: mine ? c.onAccent : c.text,
                    ),
                  ),
                  if (message.lessonRefs.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final r in message.lessonRefs)
                          _LessonTag(ref: r, onTap: () => onLesson(r)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "From lesson N": opens that lesson in the reader.
class _LessonTag extends StatelessWidget {
  const _LessonTag({required this.ref, required this.onTap});

  final LessonRef ref;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final label = 'From lesson ${ref.index}';
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: MxPressable(
        onPressed: onTap,
        semanticLabel: label,
        border: BorderSide(color: c.accentText),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MxIcon(MxIcons.book, size: 16, color: c.accentText),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: MxText.tag.copyWith(color: c.accentText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _a.stop();
      _a.value = 0.5;
    } else if (!_a.isAnimating) {
      _a.repeat();
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          liveRegion: true,
          label: 'Chat is typing',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: BorderRadius.circular(MxRadius.option),
            ),
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _a,
                builder: (_, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
                        child: Opacity(
                          opacity: 0.35 + 0.65 * _pulse(i),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: c.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _pulse(int i) {
    final t = (_a.value - i * 0.18) % 1.0;
    return t < 0.5 ? t * 2 : (1 - t) * 2;
  }
}

/// One card per failure (CONTRACTS 4.2): a picture, a title and sentence
/// (icon plus text, never colour alone) and one action.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.notice,
    required this.ready,
    required this.onRetry,
    required this.onSignIn,
    required this.onLessons,
  });

  final ChatNotice notice;

  /// The retry window has passed, so "Try again" works.
  final bool ready;
  final VoidCallback onRetry;
  final VoidCallback onSignIn;
  final VoidCallback onLessons;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final (
      MxIcons icon,
      String title,
      String body,
      String action,
      VoidCallback? run,
    ) = switch (notice) {
      ChatNotice.offline => (
        MxIcons.wifiOff,
        'Chat needs internet',
        'Connect to the internet and ask again. Your lessons still work.',
        'Try again',
        onRetry,
      ),
      ChatNotice.signedOut => (
        MxIcons.chat,
        'Please sign in again',
        'Your session ended. Sign in to keep chatting.',
        'Sign in',
        onSignIn,
      ),
      ChatNotice.dailyCap => (
        MxIcons.moon,
        'Chat is resting',
        'Chat is resting, back tomorrow.',
        'Back to lessons',
        onLessons,
      ),
      ChatNotice.resting => (
        MxIcons.moon,
        'Chat is resting',
        'It needs a short break. Try again in a few minutes.',
        'Try again',
        ready ? onRetry : null,
      ),
      ChatNotice.rateLimited => (
        MxIcons.minus,
        'One moment',
        'Too many questions in a row. Wait a few seconds.',
        'Try again',
        ready ? onRetry : null,
      ),
      ChatNotice.failed || ChatNotice.none => (
        MxIcons.quiz,
        'Something went wrong',
        'Try again.',
        'Try again',
        onRetry,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(MxRadius.card),
            border: Border.all(color: c.divider, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: _Picture(icon: icon, color: c.text),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: MxText.cardTitle.copyWith(color: c.text),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: MxText.body.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: 16),
              Opacity(
                opacity: run == null ? 0.4 : 1,
                child: SecondaryButton(label: action, onPressed: run),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.name,
    required this.enabled,
    required this.offline,
    required this.onSend,
  });

  final TextEditingController controller;
  final String name;
  final bool enabled;
  final bool offline;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Container(
        decoration: BoxDecoration(
          color: c.bg,
          border: Border(top: BorderSide(color: c.divider)),
        ),
        padding: const EdgeInsets.fromLTRB(MxSpace.gutter, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: MxText.input.copyWith(color: c.text),
                decoration: InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  hintText: offline ? 'Chat needs internet' : 'Ask about $name',
                  hintStyle: MxText.input.copyWith(color: c.textMuted),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, v, _) => MxIconButton(
                icon: MxIcons.send,
                label: 'Send',
                color: c.accentText,
                onPressed: enabled && v.text.trim().isNotEmpty ? onSend : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
