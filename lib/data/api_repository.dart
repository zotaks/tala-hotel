import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';
import 'repository.dart';

/// Talks to xampp/htdocs/tala_api/api.php (PHP + MySQL).
class ApiRepository implements Repository {
  ApiRepository(this.baseUrl);

  /// e.g. http://localhost/tala_api/api.php
  final String baseUrl;
  String? _token;

  @override
  void restoreSession(AppUser user) => _token = user.token;
  @override
  void clearSession() => _token = null;

  Uri _uri(String action, [Map<String, String>? params]) {
    final base = Uri.parse(baseUrl);
    return base.replace(queryParameters: {...base.queryParameters, 'action': action, ...?params});
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'X-Auth-Token': _token!,
      };

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    http.Response res;
    try {
      res = await call().timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw AppException('The server took too long to answer. Is XAMPP running?');
    } catch (_) {
      throw AppException("Can't reach the server at $baseUrl.\nStart Apache + MySQL in XAMPP, or switch to Demo mode.");
    }
    Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw AppException('The server sent an unexpected reply (HTTP ${res.statusCode}). Check the API URL.');
    }
    if (body['ok'] != true) throw AppException('${body['error'] ?? 'Something went wrong.'}');
    return body['data'];
  }

  Future<dynamic> _get(String action, [Map<String, String>? params]) =>
      _send(() => http.get(_uri(action, params), headers: _headers));

  Future<dynamic> _post(String action, Map<String, dynamic> data) =>
      _send(() => http.post(_uri(action), headers: _headers, body: jsonEncode(data)));

  List<Map<String, dynamic>> _list(dynamic d) => (d as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  @override
  Future<String> ping() async {
    final d = await _get('ping');
    return '${d['server']} · ${d['rooms']} room types';
  }

  @override
  Future<AppUser> login(String email, String password) async {
    final u = AppUser.fromJson(Map<String, dynamic>.from(await _post('login', {'email': email, 'password': password})));
    _token = u.token;
    return u;
  }

  @override
  Future<void> logout() async {
    try {
      await _post('logout', {});
    } finally {
      _token = null;
    }
  }

  @override
  Future<AppUser> register({required String name, required String email, required String phone, required String password}) async {
    final u = AppUser.fromJson(Map<String, dynamic>.from(
        await _post('register', {'name': name, 'email': email, 'phone': phone, 'password': password})));
    _token = u.token;
    return u;
  }

  @override
  Future<AppUser> updateMe({required String name, required String phone}) async =>
      AppUser.fromJson(Map<String, dynamic>.from(await _post('me_update', {'name': name, 'phone': phone})));

  @override
  Future<void> verifyPassword(String password) async => _post('verify_password', {'password': password});

  @override
  Future<void> changePassword(String current, String next) async => _post('change_password', {'current': current, 'password': next});

  @override
  Future<List<AppUser>> staff() async => _list(await _get('staff')).map(AppUser.fromJson).toList();

  @override
  Future<AppUser> saveStaff(StaffDraft draft) async => AppUser.fromJson(Map<String, dynamic>.from(await _post('staff_save', draft.toJson())));

  @override
  Future<List<LoginEvent>> loginHistory({bool mine = false, bool failedOnly = false}) async =>
      _list(await _get('login_history', {if (mine) 'mine': '1', if (failedOnly) 'failed': '1'})).map(LoginEvent.fromJson).toList();

  @override
  Future<List<AuditEntry>> auditLog() async => _list(await _get('audit_log')).map(AuditEntry.fromJson).toList();

  @override
  Future<SecuritySummary> securitySummary() async => SecuritySummary.fromJson(Map<String, dynamic>.from(await _get('security_summary')));

  @override
  Future<void> setRoomUnits(int roomId, int units) async => _post('room_units', {'id': roomId, 'units': units});

  @override
  Future<List<RoomType>> rooms() async => _list(await _get('rooms')).map(RoomType.fromJson).toList();

  @override
  Future<RoomType> saveRoom(RoomType room) async => RoomType.fromJson(Map<String, dynamic>.from(await _post('room_save', room.toJson())));

  @override
  Future<void> deleteRoom(int id) async => _post('room_delete', {'id': id});

  @override
  Future<List<Addon>> addons() async => _list(await _get('addons')).map(Addon.fromJson).toList();

  @override
  Future<Addon> saveAddon(Addon addon) async => Addon.fromJson(Map<String, dynamic>.from(await _post('addon_save', addon.toJson())));

  @override
  Future<void> deleteAddon(int id) async => _post('addon_delete', {'id': id});

  @override
  Future<List<StayRange>> ranges() async => _list(await _get('ranges')).map(StayRange.fromJson).toList();

  @override
  Future<Map<String, String>> closedDates() async =>
      {for (final r in _list(await _get('closed_dates'))) '${r['date']}': '${r['reason'] ?? ''}'};

  @override
  Future<void> setClosed(String ymd, bool closed, String reason) async =>
      _post('closed_set', {'date': ymd, 'closed': closed, 'reason': reason});

  @override
  Future<List<Booking>> bookings() async => _list(await _get('bookings')).map(Booking.fromJson).toList();

  @override
  Future<Booking> createBooking(BookingRequest request) async =>
      Booking.fromJson(Map<String, dynamic>.from(await _post('booking_create', request.toJson())));

  @override
  Future<Booking> updateBooking(int id, {String? status, String? staffNote}) async => Booking.fromJson(Map<String, dynamic>.from(
      await _post('booking_update', {'id': id, if (status != null) 'status': status, if (staffNote != null) 'staff_note': staffNote})));

  @override
  Future<List<GuestSummary>> guests() async => _list(await _get('guests')).map(GuestSummary.fromJson).toList();

  @override
  Future<Set<int>> favorites() async => (await _get('favorites') as List).map((e) => (e as num).toInt()).toSet();

  @override
  Future<bool> toggleFavorite(int roomTypeId) async => await _post('favorite_toggle', {'room_type_id': roomTypeId}) == true;

  @override
  Future<List<Review>> reviews() async => _list(await _get('reviews')).map(Review.fromJson).toList();

  @override
  Future<void> addReview(int bookingId, int rating, String comment) async =>
      _post('review_add', {'booking_id': bookingId, 'rating': rating, 'comment': comment});
}
