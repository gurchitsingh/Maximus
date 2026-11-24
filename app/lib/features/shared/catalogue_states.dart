// Catalogue load states shared by Home and Library (CONTRACTS 3.6): first
// run with no catalogue, and a served catalogue with no titles.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/widgets.dart';
import '../../data/api/api_error.dart';
import '../../data/providers.dart';

/// No catalogue and none cached (CONTRACTS 3.6 first run): offline wording
/// when there is no connection, the generic one for a server error.
class CatalogueErrorState extends ConsumerWidget {
  const CatalogueErrorState({super.key, required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void retry() => ref.invalidate(catalogueProvider);
    return isOfflineError(error)
        ? ErrorState(
            title: 'Could not load the library',
            body: 'Connect to the internet to set up Maximus.',
            offline: true,
            onRetry: retry,
          )
        : ErrorState(
            title: 'Could not load the library',
            body: 'Something went wrong on our side. Try again in a moment.',
            onRetry: retry,
          );
  }
}

/// The server answered with no titles (nothing published yet). Not
/// designed: the 7.23 empty state, as on the Study list.
class EmptyCatalogueState extends ConsumerWidget {
  const EmptyCatalogueState({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: SingleChildScrollView(
      child: EmptyState(
        title: 'The library is empty',
        body: 'New titles are on their way. Check back soon.',
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(catalogueProvider),
      ),
    ),
  );
}
