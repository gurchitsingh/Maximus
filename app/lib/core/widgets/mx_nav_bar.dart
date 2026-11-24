// Bottom navigation and topic bar (DESIGN_SPEC 7.8). One widget, two item
// sets: main tabs (Home, Library, Feed, Settings) and topic tabs (Lessons,
// Chat, Quiz).
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'mx_icon.dart';

@immutable
class MxNavItem {
  const MxNavItem(this.icon, this.label);
  final MxIcons icon;
  final String label;

  static const mainTabs = [
    MxNavItem(MxIcons.home, 'Home'),
    MxNavItem(MxIcons.library, 'Library'),
    MxNavItem(MxIcons.feed, 'Feed'),
    MxNavItem(MxIcons.settings, 'Settings'),
  ];

  static const topicTabs = [
    MxNavItem(MxIcons.book, 'Lessons'),
    MxNavItem(MxIcons.chat, 'Chat'),
    MxNavItem(MxIcons.quiz, 'Quiz'),
  ];
}

class MxNavBar extends StatelessWidget {
  const MxNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<MxNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.divider)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MxSpace.navBarHeight,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    active: i == currentIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final MxNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final color = active ? c.accentText : c.textMuted;
    return Semantics(
      container: true,
      button: true,
      selected: active,
      label: item.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: MxMotion.reduced(context)
                  ? Duration.zero
                  : MxMotion.fade,
              width: 56,
              height: 30,
              decoration: BoxDecoration(
                color: active ? c.accentContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(MxRadius.navPill),
              ),
              alignment: Alignment.center,
              child: MxIcon(item.icon, size: 22, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              style: (active ? MxText.navLabelActive : MxText.navLabel)
                  .copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
