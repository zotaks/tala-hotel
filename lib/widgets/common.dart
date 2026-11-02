import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'motion.dart';

// ======================================================================= brand
class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 28, this.color});
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('tala', style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: color ?? C.text, letterSpacing: -size * 0.04, height: 1)),
        Padding(padding: EdgeInsets.only(left: size * 0.06), child: Icon(Icons.auto_awesome, color: C.accent, size: size * 0.55)),
      ]);
}

// ======================================================================= layout
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color, this.radius = 14, this.dim = false});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final box = AnimatedOpacity(
      opacity: dim ? 0.55 : 1,
      duration: Motion.medium,
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: color ?? C.card, borderRadius: BorderRadius.circular(radius)),
        child: child,
      ),
    );
    return onTap == null ? box : Pressable(onTap: onTap, child: box);
  }
}

/// Big page title + subtitle with optional square icon buttons (reference style).
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.h1),
              if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: T.bodyMuted)],
            ]),
          ),
          for (final a in actions) Padding(padding: const EdgeInsets.only(left: 8), child: a),
        ]),
      );
}

class SquareIconButton extends StatelessWidget {
  const SquareIconButton({super.key, required this.icon, this.onTap, this.badge = false, this.color, this.iconColor});
  final IconData icon;
  final VoidCallback? onTap;
  final bool badge;
  final Color? color, iconColor;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.9,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color ?? C.card, borderRadius: BorderRadius.circular(12)),
          child: Stack(alignment: Alignment.center, children: [
            Icon(icon, size: 21, color: iconColor ?? C.text),
            if (badge)
              Positioned(top: 10, right: 11, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: C.accent, shape: BoxShape.circle))),
          ]),
        ),
      );
}

/// "← Booking #TL-1001" header for pushed screens.
class BackHeader extends StatelessWidget {
  const BackHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        child: Row(children: [
          IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18)),
          const SizedBox(width: 2),
          Expanded(child: Text(title, style: T.title, overflow: TextOverflow.ellipsis)),
          if (trailing != null) trailing!,
        ]),
      );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.action, this.onAction, this.padding = const EdgeInsets.fromLTRB(20, 22, 20, 10)});
  final String text;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(children: [
          Expanded(child: Text(text.toUpperCase(), style: T.label)),
          if (action != null)
            Pressable(onTap: onAction, child: Text(action!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.text))),
        ]),
      );
}

// ======================================================================= buttons
enum BtnStyle { primary, secondary, dark, danger }

class Btn extends StatelessWidget {
  const Btn(this.label, {super.key, this.onTap, this.style = BtnStyle.primary, this.loading = false, this.icon, this.height = 52, this.expand = true});
  final String label;
  final VoidCallback? onTap;
  final BtnStyle style;
  final bool loading;
  final IconData? icon;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    final (Color bg, Color fg) = switch (style) {
      BtnStyle.primary => (C.text, C.onText),
      BtnStyle.secondary => (C.card2, C.text),
      BtnStyle.dark => (Colors.black, Colors.white),
      BtnStyle.danger => (C.dangerBg, C.danger),
    };
    return Pressable(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: Motion.medium,
        curve: Motion.curve,
        height: height,
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: expand ? Alignment.center : null,
        decoration: BoxDecoration(color: enabled || loading ? bg : C.card2, borderRadius: BorderRadius.circular(10)),
        child: AnimatedSwitcher(
          duration: Motion.fast,
          child: loading
              ? SizedBox(key: const ValueKey('l'), width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
              : Row(key: const ValueKey('t'), mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[Icon(icon, size: 18, color: enabled ? fg : C.faint), const SizedBox(width: 8)],
                  Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: enabled ? fg : C.faint)),
                ]),
        ),
      ),
    );
  }
}

// ======================================================================= status
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final label = BookingStatus.label(status);
    Widget dot;
    Color txt = C.text;
    TextDecoration? deco;
    switch (status) {
      case BookingStatus.pending:
        dot = Container(width: 9, height: 9, decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(2)));
      case BookingStatus.confirmed:
        dot = Container(width: 9, height: 9, decoration: BoxDecoration(border: Border.all(color: C.text, width: 1.6), borderRadius: BorderRadius.circular(2)));
      case BookingStatus.checkedIn:
        dot = Container(width: 9, height: 9, decoration: BoxDecoration(color: C.text, borderRadius: BorderRadius.circular(2)));
      case BookingStatus.cancelled:
        dot = Container(width: 9, height: 9, decoration: BoxDecoration(color: C.faint, borderRadius: BorderRadius.circular(2)));
        txt = C.muted;
        deco = TextDecoration.lineThrough;
      default:
        dot = Container(width: 9, height: 9, decoration: BoxDecoration(color: C.faint, borderRadius: BorderRadius.circular(2)));
        txt = C.muted;
    }
    return AnimatedSwitcher(
      duration: Motion.medium,
      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(a), child: c)),
      child: Row(key: ValueKey(status), mainAxisSize: MainAxisSize.min, children: [
        dot,
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: txt, decoration: deco, decorationColor: C.muted)),
      ]),
    );
  }
}

/// Booked → Confirmed → Checked in → Checked out, with animated fill.
class ProgressTracker extends StatelessWidget {
  const ProgressTracker({super.key, required this.status});
  final String status;
  static const labels = ['Booked', 'Confirmed', 'Checked in', 'Checked out'];
  @override
  Widget build(BuildContext context) {
    final step = BookingStatus.step(status);
    return Row(children: [
      for (var i = 0; i < 4; i++)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 3 ? 6 : 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Stack(children: [
                  Container(height: 4, color: C.line),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: i <= step ? 1.0 : 0.0),
                    duration: Duration(milliseconds: 420 + i * 140),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => FractionallySizedBox(widthFactor: v, child: Container(height: 4, color: i == step && step < 3 ? C.accent : C.text)),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Text(labels[i],
                  style: TextStyle(fontSize: 11.5, fontWeight: i <= step ? FontWeight.w700 : FontWeight.w500, color: i <= step ? C.text : C.faint),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
    ]);
  }
}

// ======================================================================= images
/// Network photo with fade-in, skeleton while loading and a graceful fallback.
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.width, this.height, this.radius = 12, this.fit = BoxFit.cover, this.icon = Icons.hotel_rounded});
  final String url;
  final double? width, height;
  final double radius;
  final BoxFit fit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [C.note, C.card2], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Icon(icon, color: const Color(0x88F2762E), size: ((height ?? 80) * 0.32).clamp(16, 48).toDouble()),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              width: width,
              height: height,
              fit: fit,
              gaplessPlayback: true,
              // if Flutter's own loader can't fetch/decode the photo, let the browser show it directly
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              frameBuilder: (context, child, frame, sync) {
                if (sync) return child;
                return Stack(fit: StackFit.passthrough, children: [
                  if (frame == null) Positioned.fill(child: Skeleton(radius: radius)),
                  AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 420), curve: Curves.easeOut, child: child),
                ]);
              },
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 44, this.accent = false});
  final String name;
  final double size;
  final bool accent;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: accent ? C.accent : C.card2, borderRadius: BorderRadius.circular(size * 0.22)),
        child: Text(initials(name), style: TextStyle(fontSize: size * 0.34, fontWeight: FontWeight.w800, color: accent ? Colors.black : C.text)),
      );
}

// ======================================================================= rows & boxes
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.label, required this.value, this.trailing, this.onTap});
  final IconData icon;
  final String label, value;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: C.text),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: T.small),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.text)),
          ]),
        ),
        if (trailing != null) trailing!,
        if (onTap != null && trailing == null) Icon(Icons.chevron_right_rounded, color: C.muted),
      ]),
    );
    return onTap == null ? row : Pressable(onTap: onTap, child: row);
  }
}

class NoteBox extends StatelessWidget {
  const NoteBox({super.key, required this.title, required this.text});
  final String title, text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.note, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: C.accent, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(text, style: TextStyle(fontSize: 14, color: C.peach, height: 1.4)),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.text, this.action, this.onAction});
  final IconData icon;
  final String title, text;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => FadeSlideIn(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(18)),
              child: Icon(icon, color: C.accent, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title, style: T.title, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(text, style: T.bodyMuted, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 18), Btn(action!, onTap: onAction, expand: false, height: 46)],
          ]),
        ),
      );
}

// ======================================================================= inputs
class Field extends StatelessWidget {
  const Field({super.key, required this.label, this.hint, this.controller, this.obscure = false, this.keyboard, this.maxLines = 1,
      this.trailing, this.onChanged, this.suffix, this.autofill});
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboard;
  final int maxLines;
  final Widget? trailing;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofill;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.text))),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboard,
            maxLines: maxLines,
            onChanged: onChanged,
            autofillHints: autofill,
            style: TextStyle(fontSize: 15, color: C.text),
            decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
          ),
        ]),
      );
}

/// Selectable tile (pet-size style chips in the reference → room type / payment / filters).
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({super.key, required this.title, this.subtitle, required this.selected, this.onTap, this.disabled = false, this.height = 60});
  final String title;
  final String? subtitle;
  final bool selected, disabled;
  final VoidCallback? onTap;
  final double height;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: disabled ? null : onTap,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.curve,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? C.text : (disabled ? C.disabled : C.card),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedDefaultTextStyle(
              duration: Motion.medium,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: selected ? C.onText : (disabled ? C.faint : C.text)),
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ),
            if (subtitle != null)
              AnimatedDefaultTextStyle(
                duration: Motion.medium,
                style: TextStyle(fontSize: 11.5, color: selected ? C.onTextMuted : (disabled ? C.faint : C.muted)),
                child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ]),
        ),
      );
}

/// Pill chips for filters ("All", "Pending (2)", ...).
class FilterChips extends StatelessWidget {
  const FilterChips({super.key, required this.options, required this.selected, required this.onSelect});
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: options.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => Pressable(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: Motion.medium,
              curve: Motion.curve,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: i == selected ? C.text : C.card, borderRadius: BorderRadius.circular(9)),
              child: Text(options[i],
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: i == selected ? C.onText : C.text)),
            ),
          ),
        ),
      );
}

/// Two-option toggle with a sliding thumb (Upcoming / Past).
class SegmentToggle extends StatelessWidget {
  const SegmentToggle({super.key, required this.options, required this.index, required this.onChanged});
  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        height: 46,
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(10)),
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth / options.length;
          return Stack(children: [
            AnimatedPositioned(
              duration: Motion.medium,
              curve: Curves.easeOutBack,
              left: w * index,
              top: 0,
              bottom: 0,
              width: w,
              child: Container(decoration: BoxDecoration(color: C.text, borderRadius: BorderRadius.circular(10))),
            ),
            Row(children: [
              for (var i = 0; i < options.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: Motion.medium,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: i == index ? C.onText : C.muted),
                        child: Text(options[i]),
                      ),
                    ),
                  ),
                ),
            ]),
          ]);
        }),
      );
}

/// Horizontal day picker — "Thu 5 · 5 open".
class DateStrip extends StatelessWidget {
  const DateStrip({super.key, required this.days, required this.selected, required this.onSelect, required this.caption, this.isDisabled});
  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final String Function(DateTime) caption;
  final bool Function(DateTime)? isDisabled;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 74,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: days.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final d = days[i];
            final sel = sameDay(d, selected);
            final off = isDisabled?.call(d) ?? false;
            final fg = sel ? C.onText : (off ? C.faint : C.text);
            return Pressable(
              onTap: off ? null : () => onSelect(d),
              child: AnimatedContainer(
                duration: Motion.medium,
                curve: Motion.curve,
                width: 66,
                decoration: BoxDecoration(color: sel ? C.text : (off ? C.disabled : C.card), borderRadius: BorderRadius.circular(10)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(wd(d), style: TextStyle(fontSize: 11.5, color: sel ? C.onTextMuted : C.muted)),
                  Text('${d.day}', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: fg, height: 1.2)),
                  Text(caption(d),
                      style: TextStyle(fontSize: 10.5, color: sel ? C.onTextMuted : (off ? C.faint : C.muted)), maxLines: 1),
                ]),
              ),
            );
          },
        ),
      );
}

class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.value, required this.onChanged, this.min = 0, this.max = 99});
  final int value, min, max;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        _b(Icons.remove_rounded, value > min ? () => onChanged(value - 1) : null),
        SizedBox(
          width: 38,
          child: AnimatedSwitcher(
            duration: Motion.fast,
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Text('$value', key: ValueKey(value), textAlign: TextAlign.center, style: T.title),
          ),
        ),
        _b(Icons.add_rounded, value < max ? () => onChanged(value + 1) : null),
      ]);

  Widget _b(IconData i, VoidCallback? onTap) => Pressable(
        onTap: onTap,
        scale: 0.85,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(8)),
          child: Icon(i, size: 18, color: onTap == null ? C.faint : C.text),
        ),
      );
}

class Stars extends StatelessWidget {
  const Stars(this.rating, {super.key, this.size = 14});
  final double rating;
  final double size;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Icon(rating >= i ? Icons.star_rounded : (rating >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
              size: size, color: C.accent),
      ]);
}

/// Sticky bottom bar (summary + main action).
class BottomBar extends StatelessWidget {
  const BottomBar({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(color: C.card, border: Border(top: BorderSide(color: C.line, width: 0.6))),
        child: child,
      );
}

// ======================================================================= nav bar
class NavItem {
  const NavItem(this.icon, this.activeIcon, this.label, {this.badge = 0});
  final IconData icon, activeIcon;
  final String label;
  final int badge;
}

/// Bottom navigation with a sliding highlight pill.
class AnimatedNavBar extends StatelessWidget {
  const AnimatedNavBar({super.key, required this.items, required this.index, required this.onTap});
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: C.card, border: Border(top: BorderSide(color: C.line, width: 0.6))),
        padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + MediaQuery.of(context).padding.bottom),
        child: SizedBox(
          height: 56,
          child: LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth / items.length;
            return Stack(children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                left: w * index + 6,
                width: w - 12,
                top: 0,
                bottom: 0,
                child: Container(decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(12))),
              ),
              Row(children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Stack(clipBehavior: Clip.none, children: [
                            AnimatedSwitcher(
                              duration: Motion.medium,
                              transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: 0.7, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
                              child: Icon(i == index ? items[i].activeIcon : items[i].icon,
                                  key: ValueKey(i == index), size: 23, color: i == index ? C.text : C.muted),
                            ),
                            if (items[i].badge > 0)
                              Positioned(
                                right: -9,
                                top: -5,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(8)),
                                  child: Text('${items[i].badge}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black)),
                                ),
                              ),
                          ]),
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: Motion.medium,
                            style: TextStyle(fontSize: 11, fontWeight: i == index ? FontWeight.w800 : FontWeight.w500, color: i == index ? C.text : C.muted),
                            child: Text(items[i].label, maxLines: 1),
                          ),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ]);
          }),
        ),
      );
}

// ======================================================================= feedback
void toast(BuildContext context, String msg, {bool error = false}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? C.danger : C.text,
    duration: Duration(milliseconds: error ? 3800 : 2200),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ));
}

/// Runs an action and shows its error as a toast. Returns true on success.
Future<bool> attempt(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) toast(context, success);
    return true;
  } catch (e) {
    if (context.mounted) toast(context, '$e', error: true);
    return false;
  }
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String confirm = 'Confirm', bool danger = false}) async {
  final ok = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'close',
    barrierColor: const Color(0x99000000),
    transitionDuration: Motion.medium,
    transitionBuilder: (_, a, __, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(c), child: child));
    },
    pageBuilder: (ctx, _, __) => Center(
      child: Container(
        margin: const EdgeInsets.all(28),
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(18)),
        child: Material(
          color: Colors.transparent,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.h2),
            const SizedBox(height: 8),
            Text(message, style: T.bodyMuted),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: Btn('Back', style: BtnStyle.secondary, height: 46, onTap: () => Navigator.of(ctx).pop(false))),
              const SizedBox(width: 10),
              Expanded(child: Btn(confirm, style: danger ? BtnStyle.danger : BtnStyle.primary, height: 46, onTap: () => Navigator.of(ctx).pop(true))),
            ]),
          ]),
        ),
      ),
    ),
  );
  return ok ?? false;
}
