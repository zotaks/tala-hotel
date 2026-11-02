import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// One colour palette. The app has two (dark + light) built from the
/// reference's "black, white, grey, one orange" system.
class Palette {
  const Palette({
    required this.isDark,
    required this.bg,
    required this.card,
    required this.card2,
    required this.line,
    required this.text,
    required this.muted,
    required this.faint,
    required this.onText,
    required this.onTextMuted,
    required this.disabled,
    required this.note,
    required this.noteText,
    required this.danger,
    required this.dangerBg,
    required this.backdrop,
  });

  final bool isDark;
  final Color bg, card, card2, line, text, muted, faint, onText, onTextMuted, disabled, note, noteText, danger, dangerBg, backdrop;

  static const dark = Palette(
    isDark: true,
    bg: Color(0xFF0B0B0D),
    card: Color(0xFF161618),
    card2: Color(0xFF1F1F23),
    line: Color(0xFF2A2A2F),
    text: Color(0xFFF4F4F2),
    muted: Color(0xFF8E8E96),
    faint: Color(0xFF55555C),
    onText: Color(0xFF000000),
    onTextMuted: Color(0xFF3A3A3A),
    disabled: Color(0xFF121214),
    note: Color(0xFF2A1B12),
    noteText: Color(0xFFFDE9DC),
    danger: Color(0xFFFF7A6B),
    dangerBg: Color(0xFF2A1513),
    backdrop: Color(0xFF050506),
  );

  static const light = Palette(
    isDark: false,
    bg: Color(0xFFF2F2F0),
    card: Color(0xFFFFFFFF),
    card2: Color(0xFFEBEBE7),
    line: Color(0xFFE0E0DB),
    text: Color(0xFF111111),
    muted: Color(0xFF5E5E5E),
    faint: Color(0xFFA6A6A2),
    onText: Color(0xFFFFFFFF),
    onTextMuted: Color(0xFFC8C8C8),
    disabled: Color(0xFFE6E6E2),
    note: Color(0xFFFDE9DC),
    noteText: Color(0xFF5A2E12),
    danger: Color(0xFFD9483B),
    dangerBg: Color(0xFFFBE4E1),
    backdrop: Color(0xFFE4E4E0),
  );
}

/// Colour tokens. They follow the current palette, so the whole app
/// switches between light and dark when [C.use] is called.
class C {
  static Palette p = Palette.dark;
  static void use(Palette palette) => p = palette;

  static bool get isDark => p.isDark;
  static Color get bg => p.bg;
  static Color get card => p.card;
  static Color get card2 => p.card2;
  static Color get line => p.line;
  static Color get text => p.text;
  static Color get muted => p.muted;
  static Color get faint => p.faint;

  /// Text/icons placed ON a [text]-coloured surface (primary buttons, selected chips).
  static Color get onText => p.onText;
  static Color get onTextMuted => p.onTextMuted;
  static Color get disabled => p.disabled;
  static Color get note => p.note;
  static Color get peach => p.noteText;
  static Color get danger => p.danger;
  static Color get dangerBg => p.dangerBg;
  static Color get backdrop => p.backdrop;

  // The one orange is the same in both modes.
  static const accent = Color(0xFFF2762E);
  static const accentDeep = Color(0xFFD9611D);
}

/// Text styles (follow the current palette).
class T {
  static TextStyle get h1 => TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: C.text, letterSpacing: -0.6, height: 1.15);
  static TextStyle get h2 => TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.text, letterSpacing: -0.3);
  static TextStyle get title => TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.text, letterSpacing: -0.1);
  static TextStyle get body => TextStyle(fontSize: 14, color: C.text, height: 1.35);
  static TextStyle get bodyMuted => TextStyle(fontSize: 14, color: C.muted, height: 1.35);
  static TextStyle get small => TextStyle(fontSize: 12.5, color: C.muted, height: 1.3);
  static TextStyle get label => TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.muted, letterSpacing: 1.1);
  static TextStyle get price => TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.text);
}

ThemeData buildTheme(Palette p) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: p.isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: p.bg,
    colorScheme: p.isDark
        ? ColorScheme.dark(primary: C.accent, onPrimary: Colors.black, secondary: C.accent, surface: p.card, onSurface: p.text, error: p.danger)
        : ColorScheme.light(primary: C.accent, onPrimary: Colors.black, secondary: C.accent, surface: p.card, onSurface: p.text, error: p.danger),
    splashFactory: InkRipple.splashFactory,
  );
  OutlineInputBorder border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: c == Colors.transparent ? BorderSide.none : BorderSide(color: c, width: w));
  return base.copyWith(
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: p.text, displayColor: p.text),
    appBarTheme: AppBarTheme(backgroundColor: p.bg, elevation: 0, scrolledUnderElevation: 0, foregroundColor: p.text),
    dividerColor: p.line,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.isDark ? p.card2 : p.card,
      hintStyle: TextStyle(color: p.faint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(p.isDark ? Colors.transparent : p.line),
      enabledBorder: border(p.isDark ? Colors.transparent : p.line),
      focusedBorder: border(C.accent, 1.4),
      errorBorder: border(p.danger),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.text,
      contentTextStyle: TextStyle(color: p.onText, fontWeight: FontWeight.w600),
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: C.accent, selectionColor: Color(0x55F2762E)),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _SmoothTransitions(),
      TargetPlatform.iOS: _SmoothTransitions(),
      TargetPlatform.windows: _SmoothTransitions(),
      TargetPlatform.macOS: _SmoothTransitions(),
      TargetPlatform.linux: _SmoothTransitions(),
      TargetPlatform.fuchsia: _SmoothTransitions(),
    }),
  );
}

/// Fade + short slide for every MaterialPageRoute (also used on web).
class _SmoothTransitions extends PageTransitionsBuilder {
  const _SmoothTransitions();
  @override
  Widget buildTransitions<Tx>(PageRoute<Tx> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final inCurve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final outCurve = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic);
    return SlideTransition(
      position: Tween(begin: Offset.zero, end: const Offset(-0.06, 0)).animate(outCurve),
      child: FadeTransition(
        opacity: Tween(begin: 1.0, end: 0.6).animate(outCurve),
        child: SlideTransition(
          position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(inCurve),
          child: FadeTransition(opacity: inCurve, child: child),
        ),
      ),
    );
  }
}

/// Screen-size helpers for portrait / landscape / tablet layouts.
class Screen {
  /// Wide enough for side navigation + multi-column content (phones in landscape, tablets, desktop).
  static bool wide(BuildContext context) => MediaQuery.of(context).size.width >= 640;

  /// Number of equal columns that fit, each at least [minWidth] wide.
  static int columns(double width, {double minWidth = 340, int max = 3}) {
    final n = (width / minWidth).floor();
    return n < 1 ? 1 : (n > max ? max : n);
  }
}
