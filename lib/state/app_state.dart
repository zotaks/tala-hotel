import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_repository.dart';
import '../data/repository.dart';
import '../models.dart';
import '../utils/format.dart';

/// Hotel facts shown in the app.
class Hotel {
  static const name = 'Tala Hotel';
  static const address = 'Arellano St., Dagupan City, Pangasinan';
  static const phone = '(075) 523 1234';
  static const checkIn = '2:00 PM';
  static const checkOut = '12:00 NN';
  static const payments = ['Pay at front desk', 'GCash at check-in', 'Card at front desk'];
  static const amenities = ['Pool', 'Free Wi-Fi', 'Restaurant', 'Gym', 'Spa', 'Parking', '24h Front desk'];
}

/// Security settings used by the app.
class Security {
  /// Staff are signed out after this many minutes without touching the app.
  static const staffIdleMinutes = 10;
}

/// App-wide state. Screens read it with `AppScope.of(context)`.
class AppState extends ChangeNotifier {
  late SharedPreferences _prefs;
  late Repository repo;

  /// Light / dark / follow the device.
  ThemeMode themeMode = ThemeMode.system;

  /// Shown on the login screen after an automatic sign-out.
  String? signOutReason;
  DateTime _lastActive = DateTime.now();
  Timer? _guard;

  /// Address of xampp/htdocs/tala_api/api.php. Every record is stored in the XAMPP MySQL database.
  String apiUrl = 'http://localhost/tala_api/api.php';

  bool ready = false;
  bool loading = false;
  String? loadError;
  AppUser? user;

  List<RoomType> rooms = [];
  List<Addon> addons = [];
  List<Booking> bookings = [];
  List<StayRange> ranges = [];
  Map<String, String> closed = {};
  Set<int> favorites = {};
  List<Review> reviews = [];
  List<GuestSummary> guests = [];

  // staff & security (needs staff.manage)
  List<AppUser> staff = [];
  List<LoginEvent> loginEvents = [];
  List<AuditEntry> audit = [];
  SecuritySummary security = const SecuritySummary();

  // ------------------------------------------------------------ setup
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    themeMode = switch (_prefs.getString('theme')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _guard = Timer.periodic(const Duration(seconds: 20), (_) => _checkSession());
    apiUrl = _prefs.getString('apiUrl') ?? apiUrl;
    _buildRepo();
    final saved = _prefs.getString('session');
    if (saved != null) {
      try {
        user = AppUser.fromJson(Map<String, dynamic>.from(jsonDecode(saved) as Map));
        repo.restoreSession(user!);
      } catch (_) {
        user = null;
      }
    }
    ready = true;
    notifyListeners();
    if (user != null) {
      await refresh();
    } else {
      await _loadCatalogue();
    }
  }

  void _buildRepo() {
    repo = ApiRepository(apiUrl);
  }

  /// Change the XAMPP API address (e.g. use your PC's IP when testing on a phone).
  Future<void> setServer(String url) async {
    apiUrl = url.trim();
    await _prefs.setString('apiUrl', apiUrl);
    await _clearSession();
    _buildRepo();
    _clearData();
    notifyListeners();
    await _loadCatalogue();
  }

  /// Test an address without switching to it.
  Future<String> testConnection(String url) => ApiRepository(url.trim()).ping();

  void _clearData() {
    bookings = [];
    favorites = {};
    guests = [];
    staff = [];
    loginEvents = [];
    audit = [];
    security = const SecuritySummary();
  }

  @override
  void dispose() {
    _guard?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------ appearance
  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    await _prefs.setString('theme', switch (m) { ThemeMode.light => 'light', ThemeMode.dark => 'dark', _ => 'system' });
  }

  // ------------------------------------------------------------ security
  /// Called on every tap/scroll — keeps the staff idle timer from firing.
  void touch() => _lastActive = DateTime.now();

  void _checkSession() {
    final u = user;
    if (u == null) return;
    final exp = u.tokenExpires == null ? null : parseDateTime(u.tokenExpires!);
    if (exp != null && DateTime.now().isAfter(exp)) {
      logout(reason: 'Your session expired. Please log in again.');
    } else if (u.isAdmin && DateTime.now().difference(_lastActive).inMinutes >= Security.staffIdleMinutes) {
      logout(reason: 'For security, you were signed out after ${Security.staffIdleMinutes} minutes without activity.');
    }
  }

  /// Does the signed-in staff member have privilege [p]?
  bool can(String p) => user?.can(p) ?? false;

  /// Re-checks the password before sensitive actions.
  Future<void> verifyPassword(String password) => repo.verifyPassword(password);

  Future<void> changePassword(String current, String next) async {
    await repo.changePassword(current, next);
    final u = user;
    if (u != null && u.mustChangePassword) {
      await _setUser(u.passwordChanged()); // unlocks the staff dashboard
      notifyListeners();
      await refresh();
    }
  }

  Future<void> saveStaff(StaffDraft d) async {
    await repo.saveStaff(d);
    await refresh();
  }

  Future<List<LoginEvent>> myLogins() => repo.loginHistory(mine: true);

  // ------------------------------------------------------------ auth
  /// Same login for guests, owner, manager and front desk — the role decides which app opens.
  Future<void> login(String email, String password) async {
    final u = await repo.login(email, password);
    signOutReason = null;
    _lastActive = DateTime.now();
    await _setUser(u);
    await refresh();
  }

  Future<void> register({required String name, required String email, required String phone, required String password}) async {
    final u = await repo.register(name: name, email: email, phone: phone, password: password);
    await _setUser(u);
    await refresh();
  }

  Future<void> updateMe({required String name, required String phone}) async {
    final u = await repo.updateMe(name: name, phone: phone);
    final old = user;
    await _setUser(old == null ? u : old.merge(u)); // keep token + previous-login info
    notifyListeners();
  }

  Future<void> logout({String? reason}) async {
    try {
      await repo.logout(); // ends the session on the server too
    } catch (_) {}
    signOutReason = reason;
    await _clearSession();
    _clearData();
    notifyListeners();
  }

  Future<void> _setUser(AppUser u) async {
    user = u;
    repo.restoreSession(u);
    await _prefs.setString('session', jsonEncode(u.toJson()));
  }

  Future<void> _clearSession() async {
    user = null;
    repo.clearSession();
    await _prefs.remove('session');
  }

  // ------------------------------------------------------------ loading
  Future<void> _loadCatalogue() async {
    try {
      final res = await Future.wait([repo.rooms(), repo.addons(), repo.ranges(), repo.closedDates(), repo.reviews()]);
      rooms = res[0] as List<RoomType>;
      addons = res[1] as List<Addon>;
      ranges = res[2] as List<StayRange>;
      closed = res[3] as Map<String, String>;
      reviews = res[4] as List<Review>;
      loadError = null;
    } catch (e) {
      loadError = '$e';
    }
    notifyListeners();
  }

  /// Reloads everything the current user can see.
  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    notifyListeners();
    try {
      await _loadCatalogue();
      final u = user;
      if (u != null) {
        if (!u.isAdmin) {
          bookings = await repo.bookings();
          favorites = await repo.favorites();
        } else if (u.mustChangePassword) {
          // nothing else loads until a new password is set
        } else {
          bookings = u.can(Priv.bookingsView) ? await repo.bookings() : [];
          guests = u.can(Priv.guestsView) ? await repo.guests() : [];
          if (u.can(Priv.staffManage)) {
            final r = await Future.wait([repo.staff(), repo.loginHistory(), repo.auditLog(), repo.securitySummary()]);
            staff = r[0] as List<AppUser>;
            loginEvents = r[1] as List<LoginEvent>;
            audit = r[2] as List<AuditEntry>;
            security = r[3] as SecuritySummary;
          }
        }
      }
      loadError = null;
    } on AppException catch (e) {
      loadError = e.message;
      if (e.message.contains('log in')) {
        signOutReason = e.message;
        await _clearSession();
        _clearData();
      }
    } catch (e) {
      loadError = '$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ guest actions
  Future<Booking> createBooking(BookingRequest req) async {
    final b = await repo.createBooking(req);
    await refresh();
    return bookingById(b.id) ?? b;
  }

  Future<void> cancelBooking(Booking b) => setStatus(b, BookingStatus.cancelled);

  Future<void> toggleFavorite(int roomId) async {
    // optimistic: update instantly, roll back on error
    final had = favorites.contains(roomId);
    favorites = {...favorites};
    had ? favorites.remove(roomId) : favorites.add(roomId);
    notifyListeners();
    try {
      await repo.toggleFavorite(roomId);
    } catch (e) {
      favorites = {...favorites};
      had ? favorites.add(roomId) : favorites.remove(roomId);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addReview(Booking b, int rating, String comment) async {
    await repo.addReview(b.id, rating, comment);
    await refresh();
  }

  // ------------------------------------------------------------ admin actions
  Future<void> setStatus(Booking b, String status) async {
    await repo.updateBooking(b.id, status: status);
    await refresh();
  }

  Future<void> saveStaffNote(Booking b, String note) async {
    await repo.updateBooking(b.id, staffNote: note);
    await refresh();
  }

  Future<void> saveRoom(RoomType r) async {
    await repo.saveRoom(r);
    await refresh();
  }

  Future<void> deleteRoom(RoomType r) async {
    await repo.deleteRoom(r.id);
    await refresh();
  }

  Future<void> adjustUnits(RoomType r, int delta) async {
    final next = clampInt(r.units + delta, 0, 99);
    if (next == r.units) return;
    // instant UI feedback, rolled back if the server refuses
    final before = rooms;
    rooms = [for (final x in rooms) x.id == r.id ? x.copyWith(units: next) : x];
    notifyListeners();
    try {
      await repo.setRoomUnits(r.id, next);
    } catch (e) {
      rooms = before;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> saveAddon(Addon a) async {
    await repo.saveAddon(a);
    await refresh();
  }

  Future<void> deleteAddon(Addon a) async {
    await repo.deleteAddon(a.id);
    await refresh();
  }

  Future<void> setClosed(DateTime day, bool isClosed, {String reason = 'Closed'}) async {
    await repo.setClosed(ymd(day), isClosed, reason);
    closed = {...closed};
    if (isClosed) {
      closed[ymd(day)] = reason;
    } else {
      closed.remove(ymd(day));
    }
    notifyListeners();
  }

  // ------------------------------------------------------------ derived data
  List<RoomType> get visibleRooms => rooms.where((r) => r.visible).toList();

  RoomType? roomById(int id) {
    for (final r in rooms) {
      if (r.id == id) return r;
    }
    return null;
  }

  Booking? bookingById(int id) {
    for (final b in bookings) {
      if (b.id == id) return b;
    }
    return null;
  }

  List<Review> reviewsFor(int roomId) => reviews.where((r) => r.roomTypeId == roomId).toList();

  bool isClosed(DateTime day) => closed.containsKey(ymd(day));

  int bookedOn(int roomId, DateTime night) => ranges.where((s) => s.roomTypeId == roomId && s.coversNight(night)).length;

  int freeOn(RoomType r, DateTime night) => clampInt(r.units - bookedOn(r.id, night), 0, 999);

  /// Free units for every night of a stay (the smallest number wins).
  int freeForStay(RoomType r, DateTime checkIn, int nights) {
    var free = r.units;
    for (var i = 0; i < nights; i++) {
      final f = freeOn(r, addDays(checkIn, i));
      if (f < free) free = f;
    }
    return free;
  }

  /// Rooms of any type still free on a night (for the date strips).
  int totalFreeOn(DateTime night, {Iterable<RoomType>? only}) =>
      (only ?? visibleRooms).fold(0, (s, r) => s + freeOn(r, night));

  int get totalUnits => visibleRooms.fold(0, (s, r) => s + r.units);

  // guest views
  List<Booking> get upcoming => bookings.where((b) => b.isUpcoming).toList()..sort((a, b) => a.checkIn.compareTo(b.checkIn));
  List<Booking> get past => bookings.where((b) => !b.isUpcoming).toList()..sort((a, b) => b.checkIn.compareTo(a.checkIn));
  Booking? get nextStay => upcoming.isEmpty ? null : upcoming.first;

  // admin views
  List<Booking> get pending => bookings.where((b) => b.status == BookingStatus.pending).toList()..sort((a, b) => a.checkIn.compareTo(b.checkIn));
  List<Booking> get arrivalsToday =>
      bookings.where((b) => sameDay(b.checkIn, today()) && b.status != BookingStatus.cancelled).toList();
  List<Booking> get departuresToday =>
      bookings.where((b) => sameDay(b.checkOut, today()) && (b.status == BookingStatus.checkedIn || b.status == BookingStatus.checkedOut)).toList();
  List<Booking> get inHouse => bookings.where((b) => b.status == BookingStatus.checkedIn).toList();

  double get revenueThisMonth {
    final t = today();
    return bookings
        .where((b) => (b.status == BookingStatus.checkedOut || b.status == BookingStatus.checkedIn) && b.checkIn.year == t.year && b.checkIn.month == t.month)
        .fold(0.0, (s, b) => s + b.total);
  }

  /// Share of rooms occupied tonight (0..1).
  double get occupancyTonight {
    final units = totalUnits;
    if (units == 0) return 0;
    final booked = visibleRooms.fold<int>(0, (s, r) => s + clampInt(bookedOn(r.id, today()), 0, r.units));
    return booked / units;
  }

  /// Booking activity for the guest's bell icon.
  List<Booking> get activity => [...bookings]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}

/// Makes [AppState] available to every screen and rebuilds them when it changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing to changes (for button callbacks).
  static AppState read(BuildContext context) => context.findAncestorWidgetOfExactType<AppScope>()!.notifier!;
}
