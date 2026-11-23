// Feed (DESIGN_SPEC 9.2.8, CONTRACTS 7.2): a vertical snap pager of fact
// cards. The deck deals one card ahead, so likes never reorder the feed.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../../data/repositories/feed_repository.dart';
import '../../domain/feed/feed_ranker.dart';
import '../shared/title_visuals.dart';
import 'feed_card.dart';
import 'feed_providers.dart';

const _seenAfter = Duration(seconds: 1);
const _pageTurn = Duration(milliseconds: 260);

/// Feed has no top bar (DESIGN_SPEC 7.9).
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  // keepPage off: the deck, not PageStorage, decides the page.
  final _page = PageController(keepPage: false);
  final _entries = <String, FeedEntry>{};

  FeedDeck? _deck;
  FeedInputs? _inputs;
  Set<String> _disliked = const {};

  /// Fetched once per Feed session (7.2).
  Future<List<FeedEntry>>? _tries;
  String? _poolKey;
  int _generation = 0;
  int _index = 0;
  bool _ready = false;
  bool _visible = false;
  Timer? _seenTimer;

  @override
  void initState() {
    super.initState();
    ref.listenManual<FeedInputs?>(feedInputsProvider, (_, next) {
      if (next != null) _onInputs(next);
    }, fireImmediately: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Off in the IndexedStack or under a full-screen route: not "on screen".
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _visible) return;
    _visible = visible;
    if (visible) {
      _startSeenTimer();
    } else {
      _seenTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _seenTimer?.cancel();
    _page.dispose();
    super.dispose();
  }

  void _onInputs(FeedInputs inputs) {
    _inputs = inputs;
    if (inputs.poolKey != _poolKey) {
      _poolKey = inputs.poolKey;
      unawaited(_reload(inputs));
    } else {
      _disliked = inputs.dislikedFacts;
      _deck?.setDisliked(_disliked);
    }
  }

  Future<void> _reload(FeedInputs inputs) async {
    final generation = ++_generation;
    final repo = ref.read(feedRepositoryProvider);
    _tries ??= repo.tryEntries(
      inputs.catalogue,
      tryTitleIds(inputs.match, inputs.studyIds, inputs.ratedDown),
    );
    final own = await repo.ownEntries(inputs.catalogue, inputs.studyIds);
    final allTries = await _tries!;
    if (!mounted || generation != _generation) return;

    final tries = [
      for (final e in allTries)
        if (!inputs.studyIds.contains(e.title.id) &&
            !inputs.ratedDown.contains(e.title.id))
          e,
    ];
    _entries
      ..clear()
      ..addAll({
        for (final e in [...tries, ...own]) e.fact.id: e,
      });
    _disliked = inputs.dislikedFacts;

    final deck = _deck ??= FeedDeck(
      seen: [
        for (final r in inputs.rows)
          if (r.seenAt != null) r.factId,
      ],
    );
    deck.setDisliked(_disliked);
    final target = deck.setPool(
      own: [for (final e in own) _candidate(e)],
      tries: [for (final e in tries) _candidate(e)],
      current: _index,
    );
    if (!deck.hasCandidates) deck.cards.clear();

    final page = deck.cards.isEmpty ? 0 : target;
    if (page != _index) {
      _index = page;
      // Before the rebuild, while the old page count still holds it.
      if (_page.hasClients) _page.jumpToPage(page);
    }
    _dealAhead();
    setState(() => _ready = true);
    _startSeenTimer();
  }

  FeedCandidate _candidate(FeedEntry e) =>
      FeedCandidate(factId: e.fact.id, titleId: e.title.id, isTry: e.isTry);

  /// Keeps one card dealt past the current page.
  void _dealAhead() {
    final deck = _deck;
    if (deck == null) return;
    while (deck.cards.length < _index + 2) {
      if (deck.deal((id) => _inputs?.match.pctOf(id)) == null) break;
    }
  }

  void _onPage(int page) {
    if (page == _index) return;
    setState(() {
      _index = page;
      _dealAhead();
    });
    _startSeenTimer();
  }

  void _startSeenTimer() {
    _seenTimer?.cancel();
    final deck = _deck;
    if (!_visible || deck == null || _index >= deck.cards.length) return;
    final card = deck.cards[_index];
    _seenTimer = Timer(_seenAfter, () {
      deck.markSeen(card.factId);
      unawaited(
        ref
            .read(databaseProvider)
            .userStateDao
            .markFactSeen(factId: card.factId, titleId: card.titleId),
      );
    });
  }

  Future<void> _react(FeedEntry e, int value) async {
    final next = await ref
        .read(databaseProvider)
        .userStateDao
        .toggleFactReaction(
          factId: e.fact.id,
          titleId: e.title.id,
          value: value,
        );
    if (!mounted) return;
    _disliked = {..._disliked};
    if (next == -1) {
      _disliked.add(e.fact.id);
    } else {
      _disliked.remove(e.fact.id);
    }
    final deck = _deck;
    deck?.setDisliked(_disliked);
    setState(_dealAhead);
    if (next != -1 || deck == null) return;

    // Dislike also moves on, if this card is still the one on screen.
    final onScreen =
        _index < deck.cards.length && deck.cards[_index].factId == e.fact.id;
    if (!onScreen || _index + 1 >= deck.cards.length) return;
    if (MxMotion.reduced(context)) {
      _page.jumpToPage(_index + 1);
    } else {
      unawaited(
        _page.animateToPage(
          _index + 1,
          duration: _pageTurn,
          curve: MxMotion.standard,
        ),
      );
    }
  }

  void _goDeeper(FeedEntry e) {
    final lesson = e.lessonId;
    if (e.isTry || lesson == null) {
      openTitleSheet(context, e.title.id);
    } else {
      context.push(
        AppRoute.reader.location({'titleId': e.title.id, 'lessonId': lesson}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(catalogueProvider);
    if (catalogue.value == null && catalogue.hasError) {
      return SafeArea(
        bottom: false,
        child: Center(
          child: ErrorState(
            title: 'Could not load the feed',
            body: 'Connect to the internet to set up Maximus.',
            offline: true,
            onRetry: () => ref.invalidate(catalogueProvider),
          ),
        ),
      );
    }
    final deck = _deck;
    if (!_ready || deck == null) return const LoadingState();
    if (deck.cards.isEmpty) {
      return SafeArea(
        bottom: false,
        child: Center(
          child: EmptyState(
            title: 'Your feed is empty',
            body: 'Add a topic to your study list and its facts land here.',
            actionLabel: 'Browse the library',
            onAction: () => context.go(AppRoute.library.path),
          ),
        ),
      );
    }
    return PageView.builder(
      controller: _page,
      scrollDirection: Axis.vertical,
      // Builds the neighbour so its art is ready before the swipe lands.
      allowImplicitScrolling: true,
      onPageChanged: _onPage,
      itemCount: deck.cards.length,
      itemBuilder: (_, i) {
        final e = _entries[deck.cards[i].factId]!;
        return FeedCard(
          key: ValueKey('$i:${e.fact.id}'),
          entry: e,
          onGoDeeper: () => _goDeeper(e),
          onSave: () => unawaited(
            ref
                .read(databaseProvider)
                .userStateDao
                .toggleFactSaved(factId: e.fact.id, titleId: e.title.id),
          ),
          onLike: () => unawaited(_react(e, 1)),
          onDislike: () => unawaited(_react(e, -1)),
        );
      },
    );
  }
}
