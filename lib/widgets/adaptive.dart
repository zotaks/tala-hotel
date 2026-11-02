import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';
import 'motion.dart';

/// Lays cards out in equal-width columns: 1 column on a phone in portrait,
/// 2–3 columns in landscape or on a tablet, so content spreads evenly.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 340,
    this.maxColumns = 3,
    this.spacing = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });
  final List<Widget> children;
  final double minItemWidth, spacing;
  final int maxColumns;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: LayoutBuilder(builder: (context, c) {
          final cols = Screen.columns(c.maxWidth, minWidth: minItemWidth, max: maxColumns);
          final rows = <Widget>[];
          for (var i = 0; i < children.length; i += cols) {
            rows.add(Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var k = 0; k < cols; k++) ...[
                  if (k > 0) SizedBox(width: spacing),
                  Expanded(child: i + k < children.length ? children[i + k] : const SizedBox()),
                ],
              ]),
            ));
          }
          return Column(children: rows);
        }),
      );
}

/// Detail screens: one scrolling column on a phone, two side-by-side
/// scrolling panes in landscape / on a tablet.
class SplitList extends StatelessWidget {
  const SplitList({super.key, required this.left, required this.right, this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 28), this.leftFlex = 1, this.rightFlex = 1});
  final List<Widget> left, right;
  final EdgeInsets padding;
  final int leftFlex, rightFlex;

  @override
  Widget build(BuildContext context) {
    List<Widget> animate(List<Widget> items, [int offset = 0]) =>
        [for (var i = 0; i < items.length; i++) FadeSlideIn(index: i + offset, child: items[i])];
    if (!Screen.wide(context)) {
      return ListView(padding: padding, children: animate([...left, ...right]));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: leftFlex, child: ListView(padding: padding.copyWith(right: 10), children: animate(left))),
      Expanded(flex: rightFlex, child: ListView(padding: padding.copyWith(left: 10), children: animate(right, 2))),
    ]);
  }
}

/// Two widgets side by side when wide, stacked when narrow.
class PairRow extends StatelessWidget {
  const PairRow({super.key, required this.first, required this.second, this.spacing = 12});
  final Widget first, second;
  final double spacing;
  @override
  Widget build(BuildContext context) => Screen.wide(context)
      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: first), SizedBox(width: spacing), Expanded(child: second)])
      : Column(children: [first, SizedBox(height: spacing), second]);
}

/// App frame for the guest and admin apps: bottom navigation on a phone in
/// portrait, a side navigation rail in landscape and on tablets.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.items, required this.index, required this.onTap, required this.body, this.railFooter});
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  final Widget body;
  final Widget? railFooter;

  @override
  Widget build(BuildContext context) {
    if (!Screen.wide(context)) {
      return Scaffold(
        body: SafeArea(bottom: false, child: body),
        bottomNavigationBar: AnimatedNavBar(items: items, index: index, onTap: onTap),
      );
    }
    final extended = MediaQuery.of(context).size.width >= 1000;
    return Scaffold(
      body: SafeArea(
        child: Row(children: [
          _Rail(items: items, index: index, onTap: onTap, extended: extended, footer: railFooter),
          Expanded(child: body),
        ]),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.items, required this.index, required this.onTap, required this.extended, this.footer});
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  final bool extended;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: Motion.medium,
        curve: Motion.curve,
        width: extended ? 210 : 88,
        decoration: BoxDecoration(color: C.card, border: Border(right: BorderSide(color: C.line, width: 0.6))),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: extended ? const Logo(size: 26) : Icon(Icons.auto_awesome, color: C.accent, size: 24),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Pressable(
                      onTap: () => onTap(i),
                      child: AnimatedContainer(
                        duration: Motion.medium,
                        curve: Motion.curve,
                        height: extended ? 46 : 58,
                        padding: EdgeInsets.symmetric(horizontal: extended ? 14 : 0),
                        decoration: BoxDecoration(color: i == index ? C.card2 : const Color(0x00000000), borderRadius: BorderRadius.circular(12)),
                        child: extended
                            ? Row(children: [
                                _icon(i),
                                const SizedBox(width: 12),
                                Expanded(child: _label(i, 14)),
                                if (items[i].badge > 0) _badge(items[i].badge),
                              ])
                            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Stack(clipBehavior: Clip.none, children: [
                                  _icon(i),
                                  if (items[i].badge > 0) Positioned(right: -12, top: -6, child: _badge(items[i].badge)),
                                ]),
                                const SizedBox(height: 3),
                                _label(i, 10.5),
                              ]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (footer != null) Padding(padding: const EdgeInsets.all(10), child: footer!),
        ]),
      );

  Widget _icon(int i) => AnimatedSwitcher(
        duration: Motion.medium,
        child: Icon(i == index ? items[i].activeIcon : items[i].icon, key: ValueKey(i == index), size: 22, color: i == index ? C.text : C.muted),
      );

  Widget _label(int i, double size) => Text(items[i].label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: size, fontWeight: i == index ? FontWeight.w800 : FontWeight.w500, color: i == index ? C.text : C.muted));

  Widget _badge(int n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(8)),
        child: Text('$n', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black)),
      );
}

/// Side padding that keeps single-column forms at a readable width on wide screens.
double sidePad(BuildContext context, {double maxWidth = 600, double min = 20}) {
  final w = MediaQuery.of(context).size.width;
  final p = (w - maxWidth) / 2;
  return p > min ? p : min;
}
