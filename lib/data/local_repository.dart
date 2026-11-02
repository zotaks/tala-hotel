import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../utils/format.dart';
import 'repository.dart';
import 'seed_data.dart';

/// Offline "Demo mode" database.
/// Follows the same rules as the PHP API (privileges, lockout, sessions, audit log)
/// and is stored as JSON in the browser, so changes survive a page refresh on FlutLab.
class LocalRepository implements Repository {
  LocalRepository(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        _db = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        return;
      } catch (_) {}
    }
    _db = _seed();
    _save();
  }

  static const _key = 'tala_demo_db_v2';
  static const _active = [BookingStatus.pending, BookingStatus.confirmed, BookingStatus.checkedIn];
  static const maxAttempts = 5;
  static const lockMinutes = 15;
  static const staffSessionHours = 12;
  static const guestSessionDays = 30;
  static const _device = 'This device';

  final SharedPreferences _prefs;
  final _rng = Random.secure();
  late Map<String, dynamic> _db;
  String? _token;

  /// Wipes the demo database and loads fresh dummy data.
  Future<void> reset() async {
    _db = _seed();
    _token = null;
    await _save();
  }

  // ================================================================= storage
  Future<void> _save() => _prefs.setString(_key, jsonEncode(_db));
  Future<void> _lag() => Future.delayed(const Duration(milliseconds: 160)); // feels like a network call

  List<Map<String, dynamic>> _t(String table) => (_db[table] as List).cast<Map<String, dynamic>>();
  int _nextId(String table) {
    final ids = Map<String, dynamic>.from(_db['next'] as Map);
    final id = ((ids[table] ?? 1) as num).toInt();
    ids[table] = id + 1;
    _db['next'] = ids;
    return id;
  }

  // ================================================================= crypto helpers
  String _randomHex(int bytes) => List.generate(bytes, (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  /// Salted, stretched SHA-256 (passwords are never stored in plain text).
  String _hashPassword(String password, String salt) {
    List<int> h = utf8.encode('$salt:$password');
    for (var i = 0; i < 1000; i++) {
      h = sha256.convert(h).bytes;
    }
    return base64Url.encode(h);
  }

  String _hashToken(String token) => sha256.convert(utf8.encode(token)).toString();

  bool _checkPassword(Map<String, dynamic> u, String password) =>
      _hashPassword(password, '${u['salt']}') == u['password_hash'];

  void _setPassword(Map<String, dynamic> u, String password) {
    final salt = _randomHex(16);
    u['salt'] = salt;
    u['password_hash'] = _hashPassword(password, salt);
    u['password_changed_at'] = _now();
  }

  // ================================================================= seed
  String _stamp(DateTime d) => d.toIso8601String().substring(0, 19).replaceFirst('T', ' ');
  String _now() => _stamp(DateTime.now());

  Map<String, dynamic> _seed() {
    final t = today();
    final now = DateTime.now();
    String ago(int days) => _stamp(now.subtract(Duration(days: days)));
    String agoH(num hours) => _stamp(now.subtract(Duration(minutes: (hours * 60).round())));
    final roomPrice = {for (final r in seedRooms) r['id'] as int: (r['price'] as num).toDouble()};
    final addonById = {for (final a in seedAddons) a['id'] as int: a};

    final users = <Map<String, dynamic>>[];
    for (final s in seedUsers) {
      final u = <String, dynamic>{
        'id': s['id'], 'name': s['name'], 'email': s['email'], 'phone': s['phone'], 'role': s['role'],
        'staff_role': s['staff_role'], 'privileges': s['privileges'], 'active': s['active'] == 1,
        'last_login_at': s['lastLoginHoursAgo'] == null ? null : agoH(s['lastLoginHoursAgo'] as num),
        'last_login_ip': s['last_login_ip'], 'created_at': ago(s['joinedDaysAgo'] as int),
      };
      _setPassword(u, s['password'] as String);
      users.add(u);
    }
    var loginId = 1;
    var auditId = 1;
    return {
      'users': users,
      'sessions': <Map<String, dynamic>>[],
      'logins': [
        for (final l in seedLogins) {...l, 'id': loginId++, 'success': l['success'] == 1, 'created_at': agoH(l['hoursAgo'] as num)}..remove('hoursAgo'),
      ],
      'audit': [
        for (final a in seedAudit) {...a, 'id': auditId++, 'ip': '192.168.1.10', 'created_at': agoH(a['hoursAgo'] as num)}..remove('hoursAgo'),
      ],
      'rooms': [for (final r in seedRooms) Map<String, dynamic>.from(r)],
      'addons': [for (final a in seedAddons) Map<String, dynamic>.from(a)],
      'bookings': [
        for (final b in seedBookings)
          () {
            final ci = addDays(t, b['offset'] as int);
            final nights = b['nights'] as int;
            final addons = (b['addons'] as List).cast<int>();
            final roomTotal = roomPrice[b['room_type_id']]! * nights;
            final addTotal = addons.fold<double>(0, (s, a) => s + (addonById[a]!['price'] as num).toDouble());
            final created = b['createdDaysAgo'] as int;
            return <String, dynamic>{
              'id': b['id'], 'code': 'TL-${1000 + (b['id'] as int)}', 'user_id': b['user_id'], 'room_type_id': b['room_type_id'],
              'check_in': ymd(ci), 'check_out': ymd(addDays(ci, nights)), 'guests': b['guests'], 'nights': nights,
              'room_total': roomTotal, 'addons_total': addTotal, 'total': roomTotal + addTotal, 'status': b['status'],
              'payment_method': b['payment_method'], 'note': b['note'], 'staff_note': b['staff_note'],
              'created_at': ago(created), 'updated_at': ago(created > 0 ? created - 1 : 0),
              'addons': [for (final a in addons) {'addon_id': a, 'name': addonById[a]!['name'], 'price': addonById[a]!['price']}],
            };
          }(),
      ],
      'reviews': [
        for (final r in seedReviews) {...r, 'created_at': ago(r['daysAgo'] as int)}..remove('daysAgo'),
      ],
      'favorites': [for (final f in seedFavorites) [...f]],
      'closed': {for (final c in seedClosed) ymd(addDays(t, c['offset'] as int)): c['reason']},
      'next': {
        'users': seedUsers.length + 1,
        'rooms': seedRooms.length + 1,
        'addons': seedAddons.length + 1,
        'bookings': seedBookings.length + 1,
        'reviews': seedReviews.length + 1,
        'logins': loginId,
        'audit': auditId,
      },
    };
  }

  // ================================================================= users & privileges
  Map<String, dynamic>? _userById(dynamic id) {
    for (final u in _t('users')) {
      if (u['id'] == id) return u;
    }
    return null;
  }

  Map<String, dynamic>? _userByEmail(String email) {
    for (final u in _t('users')) {
      if (u['email'] == email) return u;
    }
    return null;
  }

  bool _isActive(Map<String, dynamic> u) => u['active'] == true || u['active'] == 1;

  List<String> _privsOf(Map<String, dynamic> u) {
    if (u['role'] != 'admin') return const [];
    if (u['staff_role'] == 'Owner') return Priv.all;
    final mine = ((u['privileges'] as List?) ?? const []).map((e) => '$e').toSet();
    return Priv.all.where(mine.contains).toList();
  }

  bool _can(Map<String, dynamic> u, String p) => _privsOf(u).contains(p);

  /// The signed-in user, from a valid, unexpired session.
  Map<String, dynamic> _me() {
    final tok = _token;
    if (tok != null) {
      final h = _hashToken(tok);
      final now = DateTime.now();
      for (final s in _t('sessions')) {
        if (s['token_hash'] == h && parseDateTime('${s['expires_at']}').isAfter(now)) {
          final u = _userById(s['user_id']);
          if (u != null && _isActive(u)) return u;
        }
      }
    }
    throw AppException('Your session has ended. Please log in again.');
  }

  Map<String, dynamic> _needStaff() {
    final u = _me();
    if (u['role'] != 'admin') throw AppException('Staff only.');
    return u;
  }

  Map<String, dynamic> _need(String p) {
    final u = _needStaff();
    if (!_can(u, p)) throw AppException("You don't have permission to do this ($p). Ask the hotel owner.");
    return u;
  }

  void _audit(Map<String, dynamic> u, String action, String details) => _t('audit').add({
        'id': _nextId('audit'), 'user_id': u['id'], 'user_name': u['name'], 'action': action, 'details': details, 'ip': _device, 'created_at': _now(),
      });

  AppUser _userOut(Map<String, dynamic> u, {String? token, String? expires, String? prevAt, String? prevIp, int sessions = 0}) =>
      AppUser.fromJson({
        'id': u['id'], 'name': u['name'], 'email': u['email'], 'phone': u['phone'], 'role': u['role'], 'staff_role': u['staff_role'],
        'privileges': _privsOf(u), 'active': _isActive(u), 'created_at': u['created_at'], 'last_login_at': u['last_login_at'],
        'last_login_ip': u['last_login_ip'], 'token': token, 'token_expires': expires, 'previous_login_at': prevAt,
        'previous_login_ip': prevIp, 'active_sessions': sessions,
      });

  ({String token, String expires}) _newSession(Map<String, dynamic> u) {
    final token = _randomHex(32);
    final hours = u['role'] == 'admin' ? staffSessionHours : guestSessionDays * 24;
    final expires = _stamp(DateTime.now().add(Duration(hours: hours)));
    final now = DateTime.now();
    _t('sessions').removeWhere((s) => !parseDateTime('${s['expires_at']}').isAfter(now));
    _t('sessions').add({'token_hash': _hashToken(token), 'user_id': u['id'], 'created_at': _now(), 'expires_at': expires, 'ip': _device});
    return (token: token, expires: expires);
  }

  int _activeSessions(dynamic userId) {
    final now = DateTime.now();
    return _t('sessions').where((s) => s['user_id'] == userId && parseDateTime('${s['expires_at']}').isAfter(now)).length;
  }

  int _failedRecently(String email) {
    final now = DateTime.now();
    DateTime? lastOk;
    for (final l in _t('logins')) {
      if (l['email'] == email && l['success'] == true) {
        final d = parseDateTime('${l['created_at']}');
        if (lastOk == null || d.isAfter(lastOk)) lastOk = d;
      }
    }
    return _t('logins').where((l) {
      if (l['email'] != email || l['success'] == true) return false;
      if (l['reason'] != 'bad_password' && l['reason'] != 'locked') return false;
      final d = parseDateTime('${l['created_at']}');
      return now.difference(d).inMinutes < lockMinutes && (lastOk == null || d.isAfter(lastOk));
    }).length;
  }

  void _logAttempt(String email, dynamic userId, bool ok, String reason, String portal) => _t('logins').add({
        'id': _nextId('logins'), 'email': email, 'user_id': userId, 'success': ok, 'reason': reason, 'portal': portal,
        'ip': _device, 'user_agent': 'Web browser', 'created_at': _now(),
      });

  // ================================================================= session
  @override
  void restoreSession(AppUser user) => _token = user.token;
  @override
  void clearSession() => _token = null;

  @override
  Future<String> ping() async => 'Demo database · ${_t('rooms').length} room types (saved in this browser)';

  // ================================================================= auth
  @override
  Future<AppUser> login(String email, String password) async {
    await _lag();
    final e = email.trim().toLowerCase();
    final portal = _userByEmail(e)?['role'] == 'admin' ? 'staff' : 'guest'; // only recorded in the history
    if (_failedRecently(e) >= maxAttempts) {
      _logAttempt(e, null, false, 'locked', portal);
      await _save();
      throw AppException('Too many failed attempts. For your security this account is locked for $lockMinutes minutes.');
    }
    final u = _userByEmail(e);
    if (u == null || !_checkPassword(u, password)) {
      _logAttempt(e, u?['id'], false, 'bad_password', portal);
      await _save();
      final left = maxAttempts - _failedRecently(e);
      throw AppException('Wrong email or password.${left <= 2 && left > 0 ? ' $left ${left == 1 ? 'try' : 'tries'} left before a $lockMinutes-minute lock.' : ''}');
    }
    if (!_isActive(u)) {
      _logAttempt(e, u['id'], false, 'disabled', portal);
      await _save();
      throw AppException('This account is disabled. Please contact the hotel owner.');
    }
    final isStaff = u['role'] == 'admin';
    final s = _newSession(u);
    _token = s.token;
    _logAttempt(e, u['id'], true, 'ok', portal);
    final prevAt = u['last_login_at'] as String?, prevIp = u['last_login_ip'] as String?;
    u['last_login_at'] = _now();
    u['last_login_ip'] = _device;
    if (isStaff) _audit(u, 'auth.login', 'Signed in on $_device');
    await _save();
    return _userOut(u, token: s.token, expires: s.expires, prevAt: prevAt, prevIp: prevIp);
  }

  @override
  Future<void> logout() async {
    final tok = _token;
    if (tok != null) {
      final h = _hashToken(tok);
      _t('sessions').removeWhere((s) => s['token_hash'] == h);
      await _save();
    }
    _token = null;
  }

  @override
  Future<AppUser> register({required String name, required String email, required String phone, required String password}) async {
    await _lag();
    final e = email.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) throw AppException('Please enter a valid email.');
    final problem = PasswordRules.check(password);
    if (problem != null) throw AppException(problem);
    if (_userByEmail(e) != null) throw AppException('That email already has an account.');
    final u = <String, dynamic>{
      'id': _nextId('users'), 'name': name.trim(), 'email': e, 'phone': phone.trim(), 'role': 'guest', 'staff_role': null,
      'privileges': <String>[], 'active': true, 'last_login_at': _now(), 'last_login_ip': _device, 'created_at': _now(),
    };
    _setPassword(u, password);
    _t('users').add(u);
    final s = _newSession(u);
    _token = s.token;
    _logAttempt(e, u['id'], true, 'ok', 'guest');
    await _save();
    return _userOut(u, token: s.token, expires: s.expires);
  }

  @override
  Future<AppUser> updateMe({required String name, required String phone}) async {
    await _lag();
    final u = _me();
    u['name'] = name.trim();
    u['phone'] = phone.trim();
    await _save();
    return _userOut(u);
  }

  @override
  Future<void> verifyPassword(String password) async {
    await _lag();
    if (!_checkPassword(_me(), password)) throw AppException('Wrong password.');
  }

  @override
  Future<void> changePassword(String current, String next) async {
    await _lag();
    final u = _me();
    if (!_checkPassword(u, current)) throw AppException('Your current password is wrong.');
    final problem = PasswordRules.check(next);
    if (problem != null) throw AppException(problem);
    if (_checkPassword(u, next)) throw AppException('Choose a password different from your current one.');
    _setPassword(u, next);
    final mine = _hashToken(_token ?? '');
    _t('sessions').removeWhere((s) => s['user_id'] == u['id'] && s['token_hash'] != mine); // sign out other devices
    if (u['role'] == 'admin') _audit(u, 'auth.password', 'Changed own password');
    await _save();
  }

  // ================================================================= staff & security
  @override
  Future<List<AppUser>> staff() async {
    _need(Priv.staffManage);
    await _lag();
    const order = {'Owner': 0, 'Manager': 1, 'Front desk': 2, 'Custom': 3};
    final list = _t('users').where((u) => u['role'] == 'admin').toList()
      ..sort((a, b) {
        final act = (_isActive(a) ? 0 : 1).compareTo(_isActive(b) ? 0 : 1);
        if (act != 0) return act;
        final r = (order[a['staff_role']] ?? 9).compareTo(order[b['staff_role']] ?? 9);
        return r != 0 ? r : '${a['name']}'.compareTo('${b['name']}');
      });
    return [for (final u in list) _userOut(u, sessions: _activeSessions(u['id']))];
  }

  @override
  Future<AppUser> saveStaff(StaffDraft d) async {
    final me = _need(Priv.staffManage);
    await _lag();
    var role = Priv.roles.contains(d.staffRole) ? d.staffRole : 'Custom';
    var privs = Priv.all.where(d.privileges.contains).toList();
    var active = d.active;
    final old = d.id > 0 ? _userById(d.id) : null;
    if (d.id > 0 && (old == null || old['role'] != 'admin')) throw AppException('Staff account not found.');
    final meOwner = me['staff_role'] == 'Owner';
    if ((role == 'Owner' || old?['staff_role'] == 'Owner') && !meOwner) throw AppException('Only an Owner can manage Owner accounts.');
    if (d.id == me['id']) {
      // you can't lock yourself out
      active = true;
      role = '${me['staff_role']}';
      privs = _privsOf(me);
    }
    final email = d.email.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) throw AppException('Please enter a valid email.');
    if (_t('users').any((u) => u['email'] == email && u['id'] != d.id)) throw AppException('That email is already used.');
    if (d.password.isNotEmpty) {
      final problem = PasswordRules.check(d.password);
      if (problem != null) throw AppException(problem);
    }
    if (d.id == 0 && d.password.isEmpty) throw AppException('Set a starting password for the new staff member.');

    final Map<String, dynamic> u;
    if (old != null) {
      final what = <String>[];
      if (_isActive(old) && !active) what.add('disabled');
      if (!_isActive(old) && active) what.add('enabled');
      if (old['staff_role'] != role) what.add('role → $role');
      if (_privsOf(old).join(',') != privs.join(',') && role != 'Owner') what.add('privileges changed');
      if (d.password.isNotEmpty) what.add('password reset');
      u = old;
      u.addAll({'name': d.name.trim(), 'email': email, 'phone': d.phone.trim(), 'staff_role': role, 'privileges': privs, 'active': active});
      if (d.password.isNotEmpty) _setPassword(u, d.password);
      if (!active || d.password.isNotEmpty) _t('sessions').removeWhere((s) => s['user_id'] == u['id']); // force sign-out
      _audit(me, 'staff.update', '${d.name.trim()}${what.isEmpty ? '' : ' · ${what.join(', ')}'}');
    } else {
      u = <String, dynamic>{
        'id': _nextId('users'), 'name': d.name.trim(), 'email': email, 'phone': d.phone.trim(), 'role': 'admin', 'staff_role': role,
        'privileges': privs, 'active': active, 'last_login_at': null, 'last_login_ip': null, 'created_at': _now(),
      };
      _setPassword(u, d.password);
      _t('users').add(u);
      _audit(me, 'staff.create', '${d.name.trim()} · $role');
    }
    await _save();
    return _userOut(u, sessions: _activeSessions(u['id']));
  }

  @override
  Future<List<LoginEvent>> loginHistory({bool mine = false, bool failedOnly = false}) async {
    final me = _me();
    await _lag();
    final all = !mine && _can(me, Priv.staffManage);
    final rows = _t('logins').where((l) {
      if (!all && l['user_id'] != me['id'] && l['email'] != me['email']) return false;
      if (failedOnly && l['success'] == true) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final c = '${b['created_at']}'.compareTo('${a['created_at']}');
        return c != 0 ? c : ((b['id'] as num).compareTo(a['id'] as num));
      });
    return [for (final l in rows.take(100)) LoginEvent.fromJson({...l, 'user_name': _userById(l['user_id'])?['name']})];
  }

  @override
  Future<List<AuditEntry>> auditLog() async {
    _need(Priv.staffManage);
    await _lag();
    final rows = [..._t('audit')]..sort((a, b) {
        final c = '${b['created_at']}'.compareTo('${a['created_at']}');
        return c != 0 ? c : ((b['id'] as num).compareTo(a['id'] as num));
      });
    return [for (final a in rows.take(100)) AuditEntry.fromJson(a)];
  }

  @override
  Future<SecuritySummary> securitySummary() async {
    _need(Priv.staffManage);
    final now = DateTime.now();
    final emails = _t('logins').map((l) => '${l['email']}').toSet();
    final staffUsers = _t('users').where((u) => u['role'] == 'admin').toList();
    final staffIds = staffUsers.map((u) => u['id']).toSet();
    return SecuritySummary(
      failed24h: _t('logins').where((l) => l['success'] != true && now.difference(parseDateTime('${l['created_at']}')).inHours < 24).length,
      lockedAccounts: emails.where((e) => _failedRecently(e) >= maxAttempts).length,
      activeSessions: _t('sessions').where((s) => staffIds.contains(s['user_id']) && parseDateTime('${s['expires_at']}').isAfter(now)).length,
      staffActive: staffUsers.where(_isActive).length,
      staffDisabled: staffUsers.where((u) => !_isActive(u)).length,
    );
  }

  // ================================================================= rooms & extras
  @override
  Future<List<RoomType>> rooms() async {
    await _lag();
    final list = _t('rooms').map((r) {
      final rv = _t('reviews').where((v) => v['room_type_id'] == r['id']).toList();
      final avg = rv.isEmpty ? 0.0 : rv.fold<num>(0, (s, v) => s + (v['rating'] as num)) / rv.length;
      return RoomType.fromJson({...r, 'rating': (avg * 10).round() / 10, 'review_count': rv.length});
    }).toList()
      ..sort((a, b) => a.price.compareTo(b.price));
    return list;
  }

  @override
  Future<RoomType> saveRoom(RoomType room) async {
    final me = _need(Priv.roomsManage);
    await _lag();
    if (room.price <= 0) throw AppException('Price must be more than zero.');
    final j = room.toJson();
    if (room.id > 0) {
      final i = _t('rooms').indexWhere((r) => r['id'] == room.id);
      if (i < 0) throw AppException('Room type not found.');
      _t('rooms')[i] = j;
      _audit(me, 'room.update', '${room.name} · price ${peso(room.price)} · ${room.units} rooms');
    } else {
      j['id'] = _nextId('rooms');
      _t('rooms').add(j);
      _audit(me, 'room.create', room.name);
    }
    await _save();
    return RoomType.fromJson(j);
  }

  @override
  Future<void> setRoomUnits(int roomId, int units) async {
    final me = _need(Priv.calendarManage);
    final r = _t('rooms').where((x) => x['id'] == roomId).toList();
    if (r.isEmpty) throw AppException('Room type not found.');
    r.first['units'] = clampInt(units, 0, 99);
    _audit(me, 'room.units', '${r.first['name']} · ${r.first['units']} rooms');
    await _save();
  }

  @override
  Future<void> deleteRoom(int id) async {
    final me = _need(Priv.roomsManage);
    if (_t('bookings').any((b) => b['room_type_id'] == id && _active.contains(b['status']))) {
      throw AppException('This room type still has active bookings. Hide it from guests instead.');
    }
    final name = _t('rooms').where((r) => r['id'] == id).map((r) => '${r['name']}').join();
    _t('rooms').removeWhere((r) => r['id'] == id);
    _audit(me, 'room.delete', name);
    await _save();
  }

  @override
  Future<List<Addon>> addons() async {
    final list = _t('addons').map(Addon.fromJson).toList()..sort((a, b) => a.price.compareTo(b.price));
    return list;
  }

  @override
  Future<Addon> saveAddon(Addon addon) async {
    final me = _need(Priv.roomsManage);
    await _lag();
    final j = addon.toJson();
    if (addon.id > 0) {
      final i = _t('addons').indexWhere((a) => a['id'] == addon.id);
      if (i < 0) throw AppException('Extra not found.');
      _t('addons')[i] = j;
    } else {
      j['id'] = _nextId('addons');
      _t('addons').add(j);
    }
    _audit(me, 'extra.save', '${addon.name} · ${peso(addon.price)}');
    await _save();
    return Addon.fromJson(j);
  }

  @override
  Future<void> deleteAddon(int id) async {
    final me = _need(Priv.roomsManage);
    final name = _t('addons').where((a) => a['id'] == id).map((a) => '${a['name']}').join();
    _t('addons').removeWhere((a) => a['id'] == id);
    _audit(me, 'extra.delete', name);
    await _save();
  }

  // ================================================================= availability
  @override
  Future<List<StayRange>> ranges() async {
    final t = today();
    return _t('bookings')
        .where((b) => _active.contains(b['status']) && !parseYmd(b['check_out'] as String).isBefore(t))
        .map(StayRange.fromJson)
        .toList();
  }

  @override
  Future<Map<String, String>> closedDates() async =>
      Map<String, dynamic>.from(_db['closed'] as Map).map((k, v) => MapEntry(k, '$v'));

  @override
  Future<void> setClosed(String day, bool closed, String reason) async {
    final me = _need(Priv.calendarManage);
    final m = Map<String, dynamic>.from(_db['closed'] as Map);
    if (closed) {
      m[day] = reason;
      _audit(me, 'calendar.close', '$day · $reason');
    } else {
      m.remove(day);
      _audit(me, 'calendar.open', day);
    }
    _db['closed'] = m;
    await _save();
  }

  int _bookedOn(int roomId, DateTime night) => _t('bookings').where((b) {
        if (b['room_type_id'] != roomId || !_active.contains(b['status'])) return false;
        final ci = parseYmd(b['check_in'] as String), co = parseYmd(b['check_out'] as String);
        return !ci.isAfter(night) && co.isAfter(night);
      }).length;

  // ================================================================= bookings
  String _mask(String s, bool email) {
    if (s.isEmpty) return '';
    if (email) {
      final at = s.indexOf('@');
      return at < 0 ? '•••' : '${s.substring(0, at < 2 ? at : 2)}•••${s.substring(at)}';
    }
    return s.length < 6 ? '•••' : '${s.substring(0, 4)} ••• ${s.substring(s.length - 2)}';
  }

  Booking _shapeBooking(Map<String, dynamic> b, {bool hideContact = false}) {
    final u = _userById(b['user_id']) ?? {'name': 'Deleted guest', 'email': '', 'phone': ''};
    final r = _t('rooms').firstWhere((x) => x['id'] == b['room_type_id'], orElse: () => {'name': 'Removed room', 'images': []});
    final imgs = (r['images'] as List?) ?? [];
    return Booking.fromJson({
      ...b,
      'guest_name': u['name'],
      'guest_email': hideContact ? _mask('${u['email']}', true) : u['email'],
      'guest_phone': hideContact ? _mask('${u['phone']}', false) : u['phone'],
      'room_name': r['name'], 'room_image': imgs.isEmpty ? '' : imgs.first,
      'reviewed': _t('reviews').any((v) => v['booking_id'] == b['id']),
    });
  }

  @override
  Future<List<Booking>> bookings() async {
    await _lag();
    final me = _me();
    final staff = me['role'] == 'admin';
    if (staff) _need(Priv.bookingsView);
    final hide = staff && !_can(me, Priv.guestsView);
    final rows = staff ? _t('bookings') : _t('bookings').where((b) => b['user_id'] == me['id']);
    final list = rows.map((b) => _shapeBooking(b, hideContact: hide)).toList()
      ..sort((a, b) {
        final c = b.checkIn.compareTo(a.checkIn);
        return c != 0 ? c : b.id.compareTo(a.id);
      });
    return list;
  }

  @override
  Future<Booking> createBooking(BookingRequest req) async {
    final me = _me();
    await _lag();
    if (me['role'] == 'admin') throw AppException('Staff accounts cannot make guest bookings.');
    final room = _t('rooms').where((r) => r['id'] == req.roomTypeId).toList();
    if (room.isEmpty || room.first['visible'] != true && room.first['visible'] != 1) throw AppException('That room type is not available.');
    final r = room.first;
    final ci = dateOnly(req.checkIn), co = dateOnly(req.checkOut);
    final nights = daysBetween(ci, co);
    if (ci.isBefore(today())) throw AppException('Check-in date is in the past.');
    if (nights < 1) throw AppException('Check-out must be after check-in.');
    if (nights > 30) throw AppException('Stays are limited to 30 nights.');
    if (req.guests > (r['capacity'] as num)) throw AppException('Too many guests for this room.');
    if ((_db['closed'] as Map).containsKey(ymd(ci))) throw AppException('The hotel is not taking check-ins on that date.');
    if (_t('bookings').where((b) => b['user_id'] == me['id'] && b['status'] == BookingStatus.pending).length >= 5) {
      throw AppException('You already have 5 bookings waiting for confirmation.');
    }
    for (var d = ci; d.isBefore(co); d = addDays(d, 1)) {
      if (_bookedOn(r['id'] as int, d) >= (r['units'] as num)) {
        throw AppException('Sorry, ${r['name']} is fully booked on ${fmtShort(d)}.');
      }
    }
    final addons = _t('addons').where((a) => req.addonIds.contains(a['id']) && (a['active'] == true || a['active'] == 1)).toList();
    final roomTotal = (r['price'] as num).toDouble() * nights;
    final addTotal = addons.fold<double>(0, (s, a) => s + (a['price'] as num).toDouble());
    final id = _nextId('bookings');
    final note = req.note.trim();
    final b = <String, dynamic>{
      'id': id, 'code': 'TL-${1000 + id}', 'user_id': me['id'], 'room_type_id': r['id'], 'check_in': ymd(ci), 'check_out': ymd(co),
      'guests': req.guests, 'nights': nights, 'room_total': roomTotal, 'addons_total': addTotal, 'total': roomTotal + addTotal,
      'status': BookingStatus.pending, 'payment_method': req.paymentMethod, 'note': note.length > 500 ? note.substring(0, 500) : note,
      'staff_note': '', 'created_at': _now(), 'updated_at': _now(),
      'addons': [for (final a in addons) {'addon_id': a['id'], 'name': a['name'], 'price': a['price']}],
    };
    _t('bookings').add(b);
    await _save();
    return _shapeBooking(b);
  }

  @override
  Future<Booking> updateBooking(int id, {String? status, String? staffNote}) async {
    final me = _me();
    await _lag();
    final b = _t('bookings').firstWhere((x) => x['id'] == id, orElse: () => throw AppException('Booking not found'));
    final staff = me['role'] == 'admin';
    if (!staff) {
      if (b['user_id'] != me['id']) throw AppException('Not your booking.');
      if (status != BookingStatus.cancelled || !(b['status'] == BookingStatus.pending || b['status'] == BookingStatus.confirmed)) {
        throw AppException('You can only cancel a pending or confirmed booking.');
      }
    } else {
      if (status == BookingStatus.cancelled && b['status'] != BookingStatus.pending) {
        _need(Priv.bookingsCancel);
      } else if (status != null) {
        _need(Priv.bookingsManage);
      }
      if (staffNote != null) _need(Priv.bookingsManage);
    }
    final guest = _userById(b['user_id'])?['name'] ?? 'Guest';
    if (status != null) {
      final from = b['status'];
      b['status'] = status;
      b['updated_at'] = _now();
      if (staff) {
        final verb = switch (status) {
          BookingStatus.confirmed => 'confirm',
          BookingStatus.checkedIn => 'check_in',
          BookingStatus.checkedOut => 'check_out',
          BookingStatus.cancelled => from == BookingStatus.pending ? 'decline' : 'cancel',
          _ => 'reopen',
        };
        _audit(me, 'booking.$verb', '${b['code']} · $guest');
      }
    }
    if (staff && staffNote != null) {
      b['staff_note'] = staffNote.length > 500 ? staffNote.substring(0, 500) : staffNote;
      _audit(me, 'booking.note', '${b['code']}');
    }
    await _save();
    return _shapeBooking(b, hideContact: staff && !_can(me, Priv.guestsView));
  }

  // ================================================================= guests
  @override
  Future<List<GuestSummary>> guests() async {
    _need(Priv.guestsView);
    await _lag();
    final list = _t('users').where((u) => u['role'] == 'guest').map((u) {
      final bs = _t('bookings').where((b) => b['user_id'] == u['id']).toList();
      final stays = bs
          .where((b) => b['status'] == BookingStatus.checkedIn || b['status'] == BookingStatus.checkedOut)
          .map((b) => b['check_in'] as String)
          .toList()
        ..sort();
      final spent = bs.where((b) => b['status'] == BookingStatus.checkedOut).fold<double>(0, (s, b) => s + (b['total'] as num).toDouble());
      return GuestSummary(_userOut(u), stays.isEmpty ? null : stays.last, bs.length, spent);
    }).toList()
      ..sort((a, b) => a.user.name.compareTo(b.user.name));
    return list;
  }

  // ================================================================= favourites
  List<List<int>> get _favs => (_db['favorites'] as List).map((e) => (e as List).cast<int>()).toList();

  @override
  Future<Set<int>> favorites() async {
    final me = _me()['id'];
    return _favs.where((f) => f[0] == me).map((f) => f[1]).toSet();
  }

  @override
  Future<bool> toggleFavorite(int roomTypeId) async {
    final me = _me()['id'] as int;
    final favs = _favs;
    final had = favs.any((f) => f[0] == me && f[1] == roomTypeId);
    if (had) {
      favs.removeWhere((f) => f[0] == me && f[1] == roomTypeId);
    } else {
      favs.add([me, roomTypeId]);
    }
    _db['favorites'] = favs;
    await _save();
    return !had;
  }

  // ================================================================= reviews
  @override
  Future<List<Review>> reviews() async {
    final list = _t('reviews').map((v) => Review.fromJson({...v, 'user_name': _userById(v['user_id'])?['name'] ?? 'Guest'})).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> addReview(int bookingId, int rating, String comment) async {
    final me = _me();
    final b = _t('bookings').where((x) => x['id'] == bookingId && x['user_id'] == me['id']).toList();
    if (b.isEmpty || b.first['status'] != BookingStatus.checkedOut) throw AppException('You can rate a stay after checking out.');
    if (_t('reviews').any((v) => v['booking_id'] == bookingId)) throw AppException('You already rated this stay.');
    _t('reviews').add({
      'id': _nextId('reviews'), 'user_id': me['id'], 'room_type_id': b.first['room_type_id'], 'booking_id': bookingId,
      'rating': clampInt(rating, 1, 5), 'comment': comment.trim(), 'created_at': _now(),
    });
    await _save();
  }
}
