// Credits (CONTRACTS 2.8, DESIGN_SPEC 11.8 default): a plain list of 7.20
// rows. Notices, Fonts, then one section per title (text sources, then
// images). Tapping a row opens its URL. Content credits come from the cached
// /v1/credits; fonts are bundled, so they always show.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/credits.dart';
import '../../data/repositories/credits_repository.dart';
import '../reader/lesson_body.dart' show openExternal;

class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credits = ref.watch(creditsProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const MxPushedTopBar(title: 'Credits'),
            Expanded(
              child: credits.when(
                loading: () => const LoadingState(),
                error: (_, _) =>
                    ErrorState(onRetry: () => ref.invalidate(creditsProvider)),
                data: (d) => _CreditsList(data: d),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditsList extends StatelessWidget {
  const _CreditsList({required this.data});
  final CreditsData data;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final content = data.content;
    Widget section(String label, List<Widget> rows) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [SectionLabel(label), const SizedBox(height: 6), ...rows],
      ),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (content != null)
          section('Notices', [
            for (final n in content.notices)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(n, style: MxText.body.copyWith(color: c.text)),
              ),
          ]),
        section('Fonts', [
          for (var i = 0; i < data.fonts.length; i++)
            SettingsRow(
              label: data.fonts[i].family,
              value: '${data.fonts[i].designer} · ${data.fonts[i].license}',
              showArrow: true,
              isLast: i == data.fonts.length - 1,
              onTap: () => openExternal(data.fonts[i].licenseUrl),
            ),
        ]),
        if (content == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Text(
              'Connect to load content credits.',
              style: MxText.body.copyWith(color: c.textMuted),
            ),
          )
        else
          for (final t in content.titles)
            _titleSection(section, content, t.id, t.name),
        section('Licences', [
          SettingsRow(
            label: 'Open-source licences',
            showArrow: true,
            isLast: true,
            onTap: () => showLicensePage(context: context),
          ),
        ]),
      ],
    );
  }

  Widget _titleSection(
    Widget Function(String, List<Widget>) section,
    ContentCredits content,
    String id,
    String name,
  ) {
    final texts = [
      for (final s in content.textSources)
        if (s.titleId == id) s,
    ];
    final images = [
      for (final i in content.images)
        if (i.titleId == id) i,
    ];
    final rows = <Widget>[
      for (var i = 0; i < texts.length; i++)
        SettingsRow(
          label: texts[i].name,
          value: texts[i].license,
          showArrow: true,
          isLast: images.isEmpty && i == texts.length - 1,
          onTap: () => openExternal(texts[i].url),
        ),
      for (var i = 0; i < images.length; i++)
        SettingsRow(
          label: images[i].creditLine,
          value: images[i].modified ? 'Modified' : null,
          showArrow: images[i].sourcePageUrl != null,
          isLast: i == images.length - 1,
          onTap: images[i].sourcePageUrl == null
              ? null
              : () => openExternal(images[i].sourcePageUrl!),
        ),
    ];
    return section(name, rows);
  }
}
