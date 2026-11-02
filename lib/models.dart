import 'utils/format.dart';

int _i(dynamic v) => v is int ? v : int.tryParse('$v') ?? (v is num ? v.toInt() : 0);
double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
bool _b(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';
String _s(dynamic v) => v == null ? '' : '$v';
List<String> _ls(dynamic v) => v is List ? v.map((e) => '$e').toList() : <String>[];

String? _ns(dynamic v) => v == null || '$v'.isEmpty ? null : '$v';

/// Staff privileges. Every admin screen and API action checks one of these.
class Priv {
  static const bookingsView = 'bookings.view';
  static const bookingsManage = 'bookings.manage';
  static const bookingsCancel = 'bookings.cancel';
  static const guestsView = 'guests.view';
  static const roomsManage = 'rooms.manage';
  static const calendarManage = 'calendar.manage';
  static const reportsView = 'reports.view';
  static const staffManage = 'staff.manage';

  static const all = [bookingsView, bookingsManage, bookingsCancel, guestsView, roomsManage, calendarManage, reportsView, staffManage];

  static const labels = {
    bookingsView: 'View bookings',
    bookingsManage: 'Confirm, check in & check out',
    bookingsCancel: 'Cancel confirmed bookings',
    guestsView: 'See guest list & contact details',
    roomsManage: 'Edit rooms, prices & extras',
    calendarManage: 'Close days & change room inventory',
    reportsView: 'See revenue & occupancy',
    staffManage: 'Manage staff, logins & audit log',
  };

  static const roles = ['Owner', 'Manager', 'Front desk', 'Custom'];

  /// Default privileges for each role (Owner always has everything).
  static List<String> preset(String role) => switch (role) {
        'Owner' => all,
        'Manager' => all.where((p) => p != staffManage).toList(),
        'Front desk' => const [bookingsView, bookingsManage, guestsView],
        _ => const [bookingsView],
      };
}

class AppUser {
  final int id;
  final String name, email, phone, role, createdAt;
  final String? token, tokenExpires, staffRole;
  final List<String> privileges;
  final bool active;
  final String? lastLoginAt, lastLoginIp, previousLoginAt, previousLoginIp;
  final int activeSessions;

  /// Staff with a default / reset password must choose a new one before using the dashboard.
  final bool mustChangePassword;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.createdAt = '',
    this.token,
    this.tokenExpires,
    this.staffRole,
    this.privileges = const [],
    this.active = true,
    this.lastLoginAt,
    this.lastLoginIp,
    this.previousLoginAt,
    this.previousLoginIp,
    this.activeSessions = 0,
    this.mustChangePassword = false,
  });

  bool get isAdmin => role == 'admin';
  bool get isOwner => isAdmin && staffRole == 'Owner';

  /// Does this staff member have privilege [p]?
  bool can(String p) => isAdmin && (isOwner || privileges.contains(p));

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: _i(j['id']),
        name: _s(j['name']),
        email: _s(j['email']),
        phone: _s(j['phone']),
        role: _s(j['role']).isEmpty ? 'guest' : _s(j['role']),
        createdAt: _s(j['created_at']),
        token: _ns(j['token']),
        tokenExpires: _ns(j['token_expires']),
        staffRole: _ns(j['staff_role']),
        privileges: _ls(j['privileges']),
        active: j['active'] == null ? true : _b(j['active']),
        lastLoginAt: _ns(j['last_login_at']),
        lastLoginIp: _ns(j['last_login_ip']),
        previousLoginAt: _ns(j['previous_login_at']),
        previousLoginIp: _ns(j['previous_login_ip']),
        activeSessions: _i(j['active_sessions']),
        mustChangePassword: _b(j['must_change_password']),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'email': email, 'phone': phone, 'role': role, 'created_at': createdAt, 'token': token,
        'token_expires': tokenExpires, 'staff_role': staffRole, 'privileges': privileges, 'active': active,
        'last_login_at': lastLoginAt, 'last_login_ip': lastLoginIp, 'previous_login_at': previousLoginAt, 'previous_login_ip': previousLoginIp,
        'must_change_password': mustChangePassword,
      };

  /// Keeps session details (token, previous login) when the profile is refreshed.
  AppUser merge(AppUser fresh) => AppUser(
        id: fresh.id, name: fresh.name, email: fresh.email, phone: fresh.phone, role: fresh.role, createdAt: fresh.createdAt,
        token: fresh.token ?? token, tokenExpires: fresh.tokenExpires ?? tokenExpires, staffRole: fresh.staffRole,
        privileges: fresh.privileges, active: fresh.active, lastLoginAt: fresh.lastLoginAt ?? lastLoginAt,
        lastLoginIp: fresh.lastLoginIp ?? lastLoginIp, previousLoginAt: previousLoginAt, previousLoginIp: previousLoginIp,
        mustChangePassword: fresh.mustChangePassword,
      );

  /// Same user, with the must-change-password flag cleared.
  AppUser passwordChanged() => AppUser(
        id: id, name: name, email: email, phone: phone, role: role, createdAt: createdAt, token: token, tokenExpires: tokenExpires,
        staffRole: staffRole, privileges: privileges, active: active, lastLoginAt: lastLoginAt, lastLoginIp: lastLoginIp,
        previousLoginAt: previousLoginAt, previousLoginIp: previousLoginIp,
      );
}

/// What the owner submits when adding or editing a staff account.
class StaffDraft {
  final int id;
  final String name, email, phone, staffRole, password;
  final List<String> privileges;
  final bool active;
  const StaffDraft({this.id = 0, required this.name, required this.email, required this.phone, required this.staffRole,
      required this.privileges, required this.active, this.password = ''});
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'email': email, 'phone': phone, 'staff_role': staffRole, 'privileges': privileges,
        'active': active, if (password.isNotEmpty) 'password': password,
      };
}

class LoginEvent {
  final int id;
  final String email, reason, portal, ip, userAgent, createdAt;
  final String? userName;
  final bool success;
  const LoginEvent({required this.id, required this.email, this.userName, required this.success, required this.reason,
      required this.portal, required this.ip, required this.userAgent, required this.createdAt});
  factory LoginEvent.fromJson(Map<String, dynamic> j) => LoginEvent(
      id: _i(j['id']), email: _s(j['email']), userName: _ns(j['user_name']), success: _b(j['success']), reason: _s(j['reason']),
      portal: _s(j['portal']), ip: _s(j['ip']), userAgent: _s(j['user_agent']), createdAt: _s(j['created_at']));

  String get reasonLabel => switch (reason) {
        'ok' => 'Signed in',
        'bad_password' => 'Wrong password',
        'locked' => 'Blocked — account locked',
        'disabled' => 'Blocked — account disabled',
        'wrong_portal' => 'Used the wrong login tab',
        _ => reason,
      };
}

class AuditEntry {
  final int id;
  final String userName, action, details, ip, createdAt;
  const AuditEntry({required this.id, required this.userName, required this.action, required this.details, required this.ip, required this.createdAt});
  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
      id: _i(j['id']), userName: _s(j['user_name']), action: _s(j['action']), details: _s(j['details']), ip: _s(j['ip']), createdAt: _s(j['created_at']));
}

class SecuritySummary {
  final int failed24h, lockedAccounts, activeSessions, staffActive, staffDisabled;
  const SecuritySummary({this.failed24h = 0, this.lockedAccounts = 0, this.activeSessions = 0, this.staffActive = 0, this.staffDisabled = 0});
  factory SecuritySummary.fromJson(Map<String, dynamic> j) => SecuritySummary(
      failed24h: _i(j['failed_24h']), lockedAccounts: _i(j['locked_accounts']), activeSessions: _i(j['active_sessions']),
      staffActive: _i(j['staff_active']), staffDisabled: _i(j['staff_disabled']));
}

/// Password rules shared by the app and the server.
class PasswordRules {
  static String? check(String pw) {
    if (pw.length < 8) return 'Password must be at least 8 characters.';
    if (!RegExp(r'[A-Za-z]').hasMatch(pw) || !RegExp(r'\d').hasMatch(pw)) return 'Password must contain letters and numbers.';
    return null;
  }

  /// 0 (weak) … 4 (strong), for the strength meter.
  static int score(String pw) {
    var s = 0;
    if (pw.length >= 8) s++;
    if (pw.length >= 12) s++;
    if (RegExp(r'[A-Za-z]').hasMatch(pw) && RegExp(r'\d').hasMatch(pw)) s++;
    if (RegExp(r'[A-Z]').hasMatch(pw) && RegExp(r'[a-z]').hasMatch(pw) || RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) s++;
    return s;
  }
}

class GuestSummary {
  final AppUser user;
  final String? lastStay;
  final int bookingsCount;
  final double spent;
  const GuestSummary(this.user, this.lastStay, this.bookingsCount, this.spent);

  factory GuestSummary.fromJson(Map<String, dynamic> j) =>
      GuestSummary(AppUser.fromJson(j), j['last_stay'] as String?, _i(j['bookings_count']), _d(j['spent']));
}

class RoomType {
  final int id;
  final String name, category, description, beds;
  final double price, rating;
  final int capacity, sizeSqm, units, reviewCount;
  final bool popular, visible;
  final List<String> images, amenities;

  const RoomType({
    this.id = 0,
    required this.name,
    this.category = 'Standard',
    this.description = '',
    this.beds = '',
    required this.price,
    this.capacity = 2,
    this.sizeSqm = 20,
    this.units = 1,
    this.popular = false,
    this.visible = true,
    this.images = const [],
    this.amenities = const [],
    this.rating = 0,
    this.reviewCount = 0,
  });

  String get cover => images.isNotEmpty ? images.first : '';

  factory RoomType.fromJson(Map<String, dynamic> j) => RoomType(
        id: _i(j['id']), name: _s(j['name']), category: _s(j['category']), description: _s(j['description']),
        beds: _s(j['beds']), price: _d(j['price']), capacity: _i(j['capacity']), sizeSqm: _i(j['size_sqm']),
        units: _i(j['units']), popular: _b(j['popular']), visible: _b(j['visible']), images: _ls(j['images']),
        amenities: _ls(j['amenities']), rating: _d(j['rating']), reviewCount: _i(j['review_count']));

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'category': category, 'description': description, 'beds': beds, 'price': price,
        'capacity': capacity, 'size_sqm': sizeSqm, 'units': units, 'popular': popular, 'visible': visible,
        'images': images, 'amenities': amenities,
      };

  RoomType copyWith({int? units, bool? visible}) => RoomType(
        id: id, name: name, category: category, description: description, beds: beds, price: price, capacity: capacity,
        sizeSqm: sizeSqm, units: units ?? this.units, popular: popular, visible: visible ?? this.visible, images: images,
        amenities: amenities, rating: rating, reviewCount: reviewCount);
}

class Addon {
  final int id;
  final String name, description, image;
  final double price;
  final bool active;
  const Addon({this.id = 0, required this.name, this.description = '', this.image = '', required this.price, this.active = true});

  factory Addon.fromJson(Map<String, dynamic> j) => Addon(
      id: _i(j['id']), name: _s(j['name']), description: _s(j['description']), image: _s(j['image']), price: _d(j['price']), active: _b(j['active']));

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'description': description, 'image': image, 'price': price, 'active': active};
}

class BookingAddon {
  final int addonId;
  final String name;
  final double price;
  const BookingAddon(this.addonId, this.name, this.price);
  factory BookingAddon.fromJson(Map<String, dynamic> j) => BookingAddon(_i(j['addon_id']), _s(j['name']), _d(j['price']));
  Map<String, dynamic> toJson() => {'addon_id': addonId, 'name': name, 'price': price};
}

/// Booking life cycle — mirrors the reference's Booked → Confirmed → Grooming → Ready.
class BookingStatus {
  static const pending = 'pending';
  static const confirmed = 'confirmed';
  static const checkedIn = 'checked_in';
  static const checkedOut = 'checked_out';
  static const cancelled = 'cancelled';

  static String label(String s) => switch (s) {
        pending => 'Pending',
        confirmed => 'Confirmed',
        checkedIn => 'Checked in',
        checkedOut => 'Completed',
        cancelled => 'Cancelled',
        _ => s,
      };

  /// 0 Booked, 1 Confirmed, 2 Checked in, 3 Checked out
  static int step(String s) => switch (s) {
        pending => 0,
        confirmed => 1,
        checkedIn => 2,
        checkedOut => 3,
        _ => -1,
      };

  static bool isActive(String s) => s == pending || s == confirmed || s == checkedIn;
}

class Booking {
  final int id, userId, roomTypeId, guests, nights;
  final String code, guestName, guestEmail, guestPhone, roomName, roomImage, status, paymentMethod, note, staffNote, createdAt, updatedAt;
  final DateTime checkIn, checkOut;
  final double roomTotal, addonsTotal, total;
  final List<BookingAddon> addons;
  final bool reviewed;

  const Booking({
    required this.id,
    required this.code,
    required this.userId,
    required this.guestName,
    required this.guestEmail,
    required this.guestPhone,
    required this.roomTypeId,
    required this.roomName,
    required this.roomImage,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.nights,
    required this.roomTotal,
    required this.addonsTotal,
    required this.total,
    required this.status,
    required this.paymentMethod,
    required this.note,
    required this.staffNote,
    required this.createdAt,
    required this.updatedAt,
    required this.addons,
    required this.reviewed,
  });

  bool get isActive => BookingStatus.isActive(status);
  bool get isUpcoming => isActive && !checkOut.isBefore(today());
  bool get canGuestCancel => (status == BookingStatus.pending || status == BookingStatus.confirmed) && checkIn.isAfter(today());

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: _i(j['id']), code: _s(j['code']), userId: _i(j['user_id']), guestName: _s(j['guest_name']),
        guestEmail: _s(j['guest_email']), guestPhone: _s(j['guest_phone']), roomTypeId: _i(j['room_type_id']),
        roomName: _s(j['room_name']), roomImage: _s(j['room_image']), checkIn: parseYmd(_s(j['check_in'])),
        checkOut: parseYmd(_s(j['check_out'])), guests: _i(j['guests']), nights: _i(j['nights']),
        roomTotal: _d(j['room_total']), addonsTotal: _d(j['addons_total']), total: _d(j['total']),
        status: _s(j['status']), paymentMethod: _s(j['payment_method']), note: _s(j['note']), staffNote: _s(j['staff_note']),
        createdAt: _s(j['created_at']), updatedAt: _s(j['updated_at']),
        addons: (j['addons'] as List? ?? []).map((e) => BookingAddon.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        reviewed: _b(j['reviewed']));
}

/// What a guest submits from the "Book a room" screen.
class BookingRequest {
  final int roomTypeId, guests;
  final DateTime checkIn, checkOut;
  final List<int> addonIds;
  final String paymentMethod, note;
  const BookingRequest({required this.roomTypeId, required this.guests, required this.checkIn, required this.checkOut,
      required this.addonIds, required this.paymentMethod, required this.note});

  Map<String, dynamic> toJson() => {
        'room_type_id': roomTypeId, 'guests': guests, 'check_in': ymd(checkIn), 'check_out': ymd(checkOut),
        'addons': addonIds, 'payment_method': paymentMethod, 'note': note,
      };
}

/// An active stay without personal data — used to count free rooms per night.
class StayRange {
  final int roomTypeId;
  final DateTime checkIn, checkOut;
  const StayRange(this.roomTypeId, this.checkIn, this.checkOut);
  factory StayRange.fromJson(Map<String, dynamic> j) =>
      StayRange(_i(j['room_type_id']), parseYmd(_s(j['check_in'])), parseYmd(_s(j['check_out'])));
  bool coversNight(DateTime d) => !checkIn.isAfter(d) && checkOut.isAfter(d);
}

class Review {
  final int id, userId, roomTypeId, rating;
  final int? bookingId;
  final String userName, comment, createdAt;
  const Review({required this.id, required this.userId, required this.roomTypeId, required this.rating, this.bookingId,
      required this.userName, required this.comment, required this.createdAt});
  factory Review.fromJson(Map<String, dynamic> j) => Review(
      id: _i(j['id']), userId: _i(j['user_id']), roomTypeId: _i(j['room_type_id']), rating: _i(j['rating']),
      bookingId: j['booking_id'] == null ? null : _i(j['booking_id']), userName: _s(j['user_name']),
      comment: _s(j['comment']), createdAt: _s(j['created_at']));
}

class AppException implements Exception {
  final String message;
  AppException(this.message);
  @override
  String toString() => message;
}
