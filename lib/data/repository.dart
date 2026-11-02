import '../models.dart';

/// One interface, two databases:
///  * [LocalRepository] — offline demo DB saved in the browser (works on FlutLab with no server)
///  * [ApiRepository]   — the MySQL database in XAMPP via xampp/htdocs/tala_api/api.php
abstract class Repository {
  /// Restores a saved session (token).
  void restoreSession(AppUser user);
  void clearSession();

  Future<String> ping();

  // ---------------------------------------------------------- accounts & security
  /// One login for everyone — the account's role decides guest app vs staff dashboard.
  Future<AppUser> login(String email, String password);
  Future<void> logout();
  Future<AppUser> register({required String name, required String email, required String phone, required String password});
  Future<AppUser> updateMe({required String name, required String phone});
  Future<void> verifyPassword(String password);
  Future<void> changePassword(String current, String next);

  // staff management (needs the staff.manage privilege)
  Future<List<AppUser>> staff();
  Future<AppUser> saveStaff(StaffDraft draft);
  Future<List<LoginEvent>> loginHistory({bool mine = false, bool failedOnly = false});
  Future<List<AuditEntry>> auditLog();
  Future<SecuritySummary> securitySummary();

  // ---------------------------------------------------------- rooms & extras
  Future<List<RoomType>> rooms();
  Future<RoomType> saveRoom(RoomType room);
  Future<void> setRoomUnits(int roomId, int units);
  Future<void> deleteRoom(int id);

  Future<List<Addon>> addons();
  Future<Addon> saveAddon(Addon addon);
  Future<void> deleteAddon(int id);

  Future<List<StayRange>> ranges();
  Future<Map<String, String>> closedDates();
  Future<void> setClosed(String ymd, bool closed, String reason);

  // ---------------------------------------------------------- bookings
  /// Guests get their own bookings; staff get every booking.
  Future<List<Booking>> bookings();
  Future<Booking> createBooking(BookingRequest request);
  Future<Booking> updateBooking(int id, {String? status, String? staffNote});

  Future<List<GuestSummary>> guests();

  Future<Set<int>> favorites();
  Future<bool> toggleFavorite(int roomTypeId);

  Future<List<Review>> reviews();
  Future<void> addReview(int bookingId, int rating, String comment);
}
