<?php
// ==================================================================
//  TALA HOTEL — JSON API for the Flutter app (XAMPP)
//  URL:  http://localhost/tala_api/api.php?action=<name>
//  Reads use GET, writes use POST with a JSON body.
//  Auth: send the token from `login` in the "X-Auth-Token" header.
//
//  Security: bcrypt passwords, hashed + expiring session tokens,
//  login lockout, one shared login page (role decides the dashboard), per-staff privileges
//  checked on every action, audit log, prepared statements only.
// ==================================================================
require __DIR__ . '/config.php';

// ---------------------------------------------------------- headers
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if (in_array('*', ALLOWED_ORIGINS, true) || in_array($origin, ALLOWED_ORIGINS, true)) {
    header('Access-Control-Allow-Origin: ' . ($origin ?: '*'));
}
header('Vary: Origin');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-Auth-Token');
header('Access-Control-Allow-Private-Network: true');   // Chrome: public site -> localhost
header('Access-Control-Max-Age: 600');
header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Referrer-Policy: no-referrer');
header('Cache-Control: no-store');
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') { http_response_code(204); exit; }

const ACTIVE = "('pending','confirmed','checked_in')";
const PRIVS = ['bookings.view', 'bookings.manage', 'bookings.cancel', 'guests.view', 'rooms.manage', 'calendar.manage', 'reports.view', 'staff.manage'];
const STAFF_ROLES = ['Owner', 'Manager', 'Front desk', 'Custom'];

function out($data, int $code = 200): void {
    http_response_code($code);
    echo json_encode(['ok' => $code < 400, 'data' => $data], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}
function fail(string $msg, int $code = 400): void {
    http_response_code($code);
    echo json_encode(['ok' => false, 'error' => $msg], JSON_UNESCAPED_UNICODE);
    exit;
}

try {
    $pdo = new PDO('mysql:host=' . DB_HOST . ';port=' . DB_PORT . ';dbname=' . DB_NAME . ';charset=utf8mb4', DB_USER, DB_PASS, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
    $pdo->exec("SET time_zone = '+08:00'");
} catch (Throwable $e) {
    fail('Cannot connect to MySQL. Is XAMPP MySQL running and tala_hotel.sql imported?', 500);
}

$body = json_decode(file_get_contents('php://input') ?: '[]', true) ?: [];
$in = array_merge($_GET, $body);
function req(string $k) { global $in; if (!isset($in[$k]) || $in[$k] === '') fail("Missing field: $k"); return $in[$k]; }
function opt(string $k, $d = null) { global $in; return $in[$k] ?? $d; }
function clean($v, int $max = 255): string { return mb_substr(trim((string)$v), 0, $max); }
function q(string $sql, array $p = []): PDOStatement { global $pdo; $s = $pdo->prepare($sql); $s->execute($p); return $s; }
function ip(): string { return substr($_SERVER['REMOTE_ADDR'] ?? '', 0, 64); }
function agent(): string { return substr($_SERVER['HTTP_USER_AGENT'] ?? '', 0, 255); }

function strongPassword(string $pw): void {
    if (strlen($pw) < 8) fail('Password must be at least 8 characters.');
    if (!preg_match('/[A-Za-z]/', $pw) || !preg_match('/\d/', $pw)) fail('Password must contain letters and numbers.');
}

// ---------------------------------------------------------- auth helpers
$ME = null;
function currentUser(): ?array {
    global $ME;
    if ($ME !== null) return $ME;
    $t = $_SERVER['HTTP_X_AUTH_TOKEN'] ?? '';
    if (strlen($t) < 32) return null;
    $u = q('SELECT u.*, s.id session_id, s.expires_at session_expires FROM sessions s JOIN users u ON u.id = s.user_id
            WHERE s.token_hash = ? AND s.expires_at > NOW() AND u.active = 1', [hash('sha256', $t)])->fetch();
    if (!$u) return null;
    q('UPDATE sessions SET last_seen = NOW() WHERE id = ?', [$u['session_id']]);
    return $ME = $u;
}
function needUser(): array { $u = currentUser(); if (!$u) fail('Your session has ended. Please log in again.', 401); return $u; }
function privsOf(array $u): array {
    if ($u['role'] !== 'admin') return [];
    if ($u['staff_role'] === 'Owner') return PRIVS;
    return array_values(array_intersect(PRIVS, json_decode($u['privileges'] ?: '[]', true) ?: []));
}
function can(array $u, string $p): bool { return in_array($p, privsOf($u), true); }
function needStaff(): array {
    $u = needUser();
    if ($u['role'] !== 'admin') fail('Staff only.', 403);
    if (!empty($u['must_change_password'])) fail('Please set a new password before using the staff dashboard.', 403);
    return $u;
}
function needPriv(string $p): array {
    $u = needStaff();
    if (!can($u, $p)) fail("You don't have permission to do this ($p). Ask the hotel owner.", 403);
    return $u;
}
function audit(array $u, string $action, string $details): void {
    q('INSERT INTO audit_log (user_id, user_name, action, details, ip) VALUES (?,?,?,?,?)', [$u['id'], $u['name'], $action, mb_substr($details, 0, 255), ip()]);
}
function newSession(array $u): array {
    $token = bin2hex(random_bytes(32));
    $hours = $u['role'] === 'admin' ? STAFF_SESSION_HOURS : GUEST_SESSION_DAYS * 24;
    q("INSERT INTO sessions (token_hash, user_id, expires_at, ip, user_agent) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL $hours HOUR), ?, ?)",
      [hash('sha256', $token), $u['id'], ip(), agent()]);
    $exp = q('SELECT expires_at FROM sessions WHERE token_hash = ?', [hash('sha256', $token)])->fetchColumn();
    return [$token, $exp];
}

// ---------------------------------------------------------- shapers
function userOut(array $u): array {
    return ['id' => (int)$u['id'], 'name' => $u['name'], 'email' => $u['email'], 'phone' => $u['phone'], 'role' => $u['role'],
        'staff_role' => $u['staff_role'], 'privileges' => privsOf($u), 'active' => (bool)$u['active'], 'created_at' => $u['created_at'],
        'must_change_password' => (bool)($u['must_change_password'] ?? 0),
        'last_login_at' => $u['last_login_at'], 'last_login_ip' => $u['last_login_ip']];
}
function roomOut(array $r): array {
    return ['id' => (int)$r['id'], 'name' => $r['name'], 'category' => $r['category'], 'description' => $r['description'] ?? '',
        'price' => (float)$r['price'], 'capacity' => (int)$r['capacity'], 'size_sqm' => (int)$r['size_sqm'], 'beds' => $r['beds'],
        'units' => (int)$r['units'], 'popular' => (bool)$r['popular'], 'visible' => (bool)$r['visible'],
        'images' => json_decode($r['images'] ?: '[]', true) ?: [], 'amenities' => json_decode($r['amenities'] ?: '[]', true) ?: [],
        'rating' => isset($r['rating']) ? round((float)$r['rating'], 1) : 0, 'review_count' => (int)($r['review_count'] ?? 0)];
}
function addonOut(array $a): array {
    return ['id' => (int)$a['id'], 'name' => $a['name'], 'description' => $a['description'], 'price' => (float)$a['price'],
        'image' => $a['image'], 'active' => (bool)$a['active']];
}
function mask(string $s, bool $email): string {
    if ($s === '') return '';
    if ($email) { [$a, $b] = array_pad(explode('@', $s, 2), 2, ''); return mb_substr($a, 0, 2) . '•••@' . $b; }
    return mb_substr($s, 0, 4) . ' ••• ' . mb_substr($s, -2);
}
function bookingsOut(array $rows): array {
    if (!$rows) return [];
    $me = currentUser();
    $hideContact = $me && $me['role'] === 'admin' && !can($me, 'guests.view');
    $ids = array_column($rows, 'id');
    $ph = implode(',', array_fill(0, count($ids), '?'));
    $adds = [];
    foreach (q("SELECT * FROM booking_addons WHERE booking_id IN ($ph)", $ids)->fetchAll() as $a) {
        $adds[$a['booking_id']][] = ['addon_id' => (int)$a['addon_id'], 'name' => $a['name'], 'price' => (float)$a['price']];
    }
    $reviewed = array_flip(array_column(q("SELECT booking_id FROM reviews WHERE booking_id IN ($ph)", $ids)->fetchAll(), 'booking_id'));
    return array_map(function ($b) use ($adds, $reviewed, $hideContact) {
        $imgs = json_decode($b['room_images'] ?: '[]', true) ?: [];
        return ['id' => (int)$b['id'], 'code' => $b['code'], 'user_id' => (int)$b['user_id'], 'guest_name' => $b['guest_name'],
            'guest_email' => $hideContact ? mask($b['guest_email'], true) : $b['guest_email'],
            'guest_phone' => $hideContact ? mask($b['guest_phone'], false) : $b['guest_phone'],
            'room_type_id' => (int)$b['room_type_id'], 'room_name' => $b['room_name'], 'room_image' => $imgs[0] ?? '',
            'check_in' => $b['check_in'], 'check_out' => $b['check_out'], 'guests' => (int)$b['guests'], 'nights' => (int)$b['nights'],
            'room_total' => (float)$b['room_total'], 'addons_total' => (float)$b['addons_total'], 'total' => (float)$b['total'],
            'status' => $b['status'], 'payment_method' => $b['payment_method'], 'note' => $b['note'] ?? '', 'staff_note' => $b['staff_note'] ?? '',
            'created_at' => $b['created_at'], 'updated_at' => $b['updated_at'], 'addons' => $adds[$b['id']] ?? [],
            'reviewed' => isset($reviewed[$b['id']])];
    }, $rows);
}
const BOOKING_SELECT = "SELECT b.*, u.name guest_name, u.email guest_email, u.phone guest_phone, r.name room_name, r.images room_images
    FROM bookings b JOIN users u ON u.id = b.user_id JOIN room_types r ON r.id = b.room_type_id";

function bookingById(int $id): array {
    $rows = q(BOOKING_SELECT . ' WHERE b.id = ?', [$id])->fetchAll();
    if (!$rows) fail('Booking not found', 404);
    return bookingsOut($rows)[0];
}
function failedRecently(string $email): int {
    // failures in the lock window, counted only after the last successful login
    return (int)q("SELECT COUNT(*) FROM login_attempts WHERE email = ? AND success = 0 AND reason IN ('bad_password','locked')
                   AND created_at > DATE_SUB(NOW(), INTERVAL " . LOCK_MINUTES . " MINUTE)
                   AND created_at > COALESCE((SELECT MAX(created_at) FROM login_attempts WHERE email = ? AND success = 1), '2000-01-01')",
                   [$email, $email])->fetchColumn();
}
function logAttempt(string $email, ?int $uid, bool $ok, string $reason, string $portal): void {
    q('INSERT INTO login_attempts (email, user_id, success, reason, portal, ip, user_agent) VALUES (?,?,?,?,?,?,?)',
      [$email, $uid, $ok ? 1 : 0, $reason, $portal, ip(), agent()]);
}

// ---------------------------------------------------------- routes
$action = $_GET['action'] ?? '';
switch ($action) {

case 'ping':
    out(['server' => 'Tala Hotel API', 'time' => date('c'), 'rooms' => (int)q('SELECT COUNT(*) FROM room_types')->fetchColumn()]);

// ================================================================ auth
case 'login': {
    $email = strtolower(clean(req('email'), 160));
    // One login page for everyone: the account itself decides guest app vs staff dashboard.
    $known = q('SELECT role FROM users WHERE email = ?', [$email])->fetchColumn();
    $portal = $known === 'admin' ? 'staff' : 'guest';   // only recorded in the login history
    if (failedRecently($email) >= MAX_LOGIN_ATTEMPTS) {
        logAttempt($email, null, false, 'locked', $portal);
        fail('Too many failed attempts. For your security this account is locked for ' . LOCK_MINUTES . ' minutes.', 429);
    }
    $u = q('SELECT * FROM users WHERE email = ?', [$email])->fetch();
    if (!$u || !password_verify((string)req('password'), $u['password_hash'])) {
        logAttempt($email, $u ? (int)$u['id'] : null, false, 'bad_password', $portal);
        $left = MAX_LOGIN_ATTEMPTS - failedRecently($email);
        fail('Wrong email or password.' . ($left <= 2 && $left > 0 ? " $left " . ($left == 1 ? 'try' : 'tries') . ' left before a ' . LOCK_MINUTES . '-minute lock.' : ''), 401);
    }
    if (!$u['active']) { logAttempt($email, (int)$u['id'], false, 'disabled', $portal); fail('This account is disabled. Please contact the hotel owner.', 403); }
    $isStaff = $u['role'] === 'admin';

    if (password_needs_rehash($u['password_hash'], PASSWORD_DEFAULT))
        q('UPDATE users SET password_hash = ? WHERE id = ?', [password_hash((string)req('password'), PASSWORD_DEFAULT), $u['id']]);
    q('DELETE FROM sessions WHERE expires_at < NOW()');
    [$token, $exp] = newSession($u);
    logAttempt($email, (int)$u['id'], true, 'ok', $portal);
    $prevAt = $u['last_login_at']; $prevIp = $u['last_login_ip'];
    q('UPDATE users SET last_login_at = NOW(), last_login_ip = ? WHERE id = ?', [ip(), $u['id']]);
    $u = q('SELECT * FROM users WHERE id = ?', [$u['id']])->fetch();
    if ($isStaff) audit($u, 'auth.login', 'Signed in from ' . ip());
    out(userOut($u) + ['token' => $token, 'token_expires' => $exp, 'previous_login_at' => $prevAt, 'previous_login_ip' => $prevIp]);
}
case 'logout': {
    $t = $_SERVER['HTTP_X_AUTH_TOKEN'] ?? '';
    if ($t) q('DELETE FROM sessions WHERE token_hash = ?', [hash('sha256', $t)]);
    out(true);
}
case 'register': {
    $email = strtolower(clean(req('email'), 160));
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) fail('Please enter a valid email.');
    $pw = (string)req('password');
    strongPassword($pw);
    if (q('SELECT id FROM users WHERE email = ?', [$email])->fetch()) fail('That email already has an account.');
    q('INSERT INTO users (name, email, phone, password_hash, role, password_changed_at) VALUES (?,?,?,?,?,NOW())',
        [clean(req('name'), 120), $email, clean(opt('phone', ''), 40), password_hash($pw, PASSWORD_DEFAULT), 'guest']);
    $u = q('SELECT * FROM users WHERE id = ?', [$pdo->lastInsertId()])->fetch();
    [$token, $exp] = newSession($u);
    logAttempt($email, (int)$u['id'], true, 'ok', 'guest');
    q('UPDATE users SET last_login_at = NOW(), last_login_ip = ? WHERE id = ?', [ip(), $u['id']]);
    out(userOut($u) + ['token' => $token, 'token_expires' => $exp]);
}
case 'me_update': {
    $u = needUser();
    $name = clean(req('name'), 120);
    q('UPDATE users SET name = ?, phone = ? WHERE id = ?', [$name, clean(opt('phone', ''), 40), $u['id']]);
    out(userOut(q('SELECT * FROM users WHERE id = ?', [$u['id']])->fetch()));
}
case 'verify_password': {   // re-confirm identity before sensitive actions
    $u = needUser();
    if (!password_verify((string)req('password'), $u['password_hash'])) fail('Wrong password.', 401);
    out(true);
}
case 'change_password': {
    $u = needUser();
    if (!password_verify((string)req('current'), $u['password_hash'])) fail('Your current password is wrong.', 401);
    $pw = (string)req('password');
    strongPassword($pw);
    if (password_verify($pw, $u['password_hash'])) fail('Choose a password different from your current one.');
    q('UPDATE users SET password_hash = ?, password_changed_at = NOW(), must_change_password = 0 WHERE id = ?', [password_hash($pw, PASSWORD_DEFAULT), $u['id']]);
    q('DELETE FROM sessions WHERE user_id = ? AND id <> ?', [$u['id'], $u['session_id']]);   // sign out other devices
    if ($u['role'] === 'admin') audit($u, 'auth.password', 'Changed own password');
    out(true);
}

// ================================================================ staff & security (owner)
case 'staff': {
    needPriv('staff.manage');
    $rows = q("SELECT u.*, (SELECT COUNT(*) FROM sessions s WHERE s.user_id = u.id AND s.expires_at > NOW()) sessions
               FROM users u WHERE u.role = 'admin' ORDER BY u.active DESC, FIELD(u.staff_role,'Owner','Manager','Front desk','Custom'), u.name")->fetchAll();
    out(array_map(fn($u) => userOut($u) + ['active_sessions' => (int)$u['sessions']], $rows));
}
case 'staff_save': {
    $me = needPriv('staff.manage');
    $id = (int)opt('id', 0);
    $role = in_array(opt('staff_role'), STAFF_ROLES, true) ? opt('staff_role') : 'Custom';
    $privs = array_values(array_intersect(PRIVS, (array)opt('privileges', [])));
    $active = opt('active', true) ? 1 : 0;
    $pw = (string)opt('password', '');
    $old = $id ? q("SELECT * FROM users WHERE id = ? AND role = 'admin'", [$id])->fetch() : null;
    if ($id && !$old) fail('Staff account not found.', 404);
    $meOwner = $me['staff_role'] === 'Owner';
    if (($role === 'Owner' || ($old && $old['staff_role'] === 'Owner')) && !$meOwner) fail('Only an Owner can manage Owner accounts.', 403);
    if ($id === (int)$me['id']) { $active = 1; $role = $me['staff_role']; $privs = privsOf($me); }   // can't lock yourself out
    $email = strtolower(clean(req('email'), 160));
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) fail('Please enter a valid email.');
    if (q('SELECT id FROM users WHERE email = ? AND id <> ?', [$email, $id])->fetch()) fail('That email is already used.');
    if ($pw !== '') strongPassword($pw);
    if (!$id && $pw === '') fail('Set a starting password for the new staff member.');
    $fields = [clean(req('name'), 120), $email, clean(opt('phone', ''), 40), $role, json_encode($privs), $active];
    if ($id) {
        q('UPDATE users SET name=?, email=?, phone=?, staff_role=?, privileges=?, active=? WHERE id=?', [...$fields, $id]);
        if ($pw !== '') q('UPDATE users SET password_hash = ?, password_changed_at = NOW(), must_change_password = 1 WHERE id = ?', [password_hash($pw, PASSWORD_DEFAULT), $id]);
        if (!$active || $pw !== '') q('DELETE FROM sessions WHERE user_id = ?', [$id]);   // force sign-out
        $what = [];
        if ($old['active'] && !$active) $what[] = 'disabled';
        if (!$old['active'] && $active) $what[] = 'enabled';
        if ($old['staff_role'] !== $role) $what[] = "role → $role";
        if ((json_decode($old['privileges'] ?: '[]', true) ?: []) != $privs) $what[] = 'privileges changed';
        if ($pw !== '') $what[] = 'password reset';
        audit($me, 'staff.update', $fields[0] . ($what ? ' · ' . implode(', ', $what) : ''));
    } else {
        q("INSERT INTO users (name, email, phone, staff_role, privileges, active, role, password_hash, password_changed_at, must_change_password) VALUES (?,?,?,?,?,?,'admin',?,NOW(),1)",
          [...$fields, password_hash($pw, PASSWORD_DEFAULT)]);
        $id = (int)$pdo->lastInsertId();
        audit($me, 'staff.create', "$fields[0] · $role");
    }
    out(userOut(q('SELECT * FROM users WHERE id = ?', [$id])->fetch()));
}
case 'login_history': {
    $u = needUser();
    $all = opt('mine') ? false : can($u, 'staff.manage');
    $where = $all ? '1=1' : '(a.user_id = ? OR a.email = ?)';
    $params = $all ? [] : [$u['id'], $u['email']];
    if (opt('failed')) $where .= ' AND a.success = 0';
    $rows = q("SELECT a.*, u.name user_name FROM login_attempts a LEFT JOIN users u ON u.id = a.user_id WHERE $where ORDER BY a.created_at DESC, a.id DESC LIMIT 100", $params)->fetchAll();
    out(array_map(fn($r) => ['id' => (int)$r['id'], 'email' => $r['email'], 'user_name' => $r['user_name'], 'success' => (bool)$r['success'],
        'reason' => $r['reason'], 'portal' => $r['portal'], 'ip' => $r['ip'], 'user_agent' => $r['user_agent'], 'created_at' => $r['created_at']], $rows));
}
case 'audit_log': {
    needPriv('staff.manage');
    out(array_map(fn($r) => ['id' => (int)$r['id'], 'user_name' => $r['user_name'], 'action' => $r['action'], 'details' => $r['details'],
        'ip' => $r['ip'], 'created_at' => $r['created_at']], q('SELECT * FROM audit_log ORDER BY created_at DESC, id DESC LIMIT 100')->fetchAll()));
}
case 'security_summary': {
    needPriv('staff.manage');
    out([
        'failed_24h' => (int)q('SELECT COUNT(*) FROM login_attempts WHERE success = 0 AND created_at > DATE_SUB(NOW(), INTERVAL 1 DAY)')->fetchColumn(),
        'locked_accounts' => (int)q("SELECT COUNT(*) FROM (SELECT email FROM login_attempts WHERE success = 0 AND reason IN ('bad_password','locked')
                                      AND created_at > DATE_SUB(NOW(), INTERVAL " . LOCK_MINUTES . " MINUTE) GROUP BY email HAVING COUNT(*) >= " . MAX_LOGIN_ATTEMPTS . ") x")->fetchColumn(),
        'active_sessions' => (int)q("SELECT COUNT(*) FROM sessions s JOIN users u ON u.id = s.user_id WHERE u.role = 'admin' AND s.expires_at > NOW()")->fetchColumn(),
        'staff_active' => (int)q("SELECT COUNT(*) FROM users WHERE role = 'admin' AND active = 1")->fetchColumn(),
        'staff_disabled' => (int)q("SELECT COUNT(*) FROM users WHERE role = 'admin' AND active = 0")->fetchColumn(),
    ]);
}

// ================================================================ catalogue
case 'rooms': {
    $rows = q('SELECT r.*, AVG(v.rating) rating, COUNT(v.id) review_count FROM room_types r
               LEFT JOIN reviews v ON v.room_type_id = r.id GROUP BY r.id ORDER BY r.price')->fetchAll();
    out(array_map('roomOut', $rows));
}
case 'room_save': {
    $me = needPriv('rooms.manage');
    $price = (float)req('price');
    if ($price <= 0) fail('Price must be more than zero.');
    $f = [clean(req('name'), 120), clean(opt('category', 'Standard'), 40), clean(opt('description', ''), 2000), $price, max(1, (int)opt('capacity', 2)),
          max(1, (int)opt('size_sqm', 20)), clean(opt('beds', ''), 80), max(0, (int)opt('units', 1)), opt('popular') ? 1 : 0, opt('visible', true) ? 1 : 0,
          json_encode(array_values(array_map(fn($x) => clean($x, 500), (array)opt('images', [])))),
          json_encode(array_values(array_map(fn($x) => clean($x, 60), (array)opt('amenities', []))))];
    $id = (int)opt('id', 0);
    if ($id > 0) {
        q('UPDATE room_types SET name=?, category=?, description=?, price=?, capacity=?, size_sqm=?, beds=?, units=?, popular=?, visible=?, images=?, amenities=? WHERE id=?', [...$f, $id]);
        audit($me, 'room.update', "$f[0] · price ₱" . number_format($price) . " · $f[7] rooms");
    } else {
        q('INSERT INTO room_types (name, category, description, price, capacity, size_sqm, beds, units, popular, visible, images, amenities) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)', $f);
        $id = (int)$pdo->lastInsertId();
        audit($me, 'room.create', $f[0]);
    }
    out(roomOut(q('SELECT * FROM room_types WHERE id = ?', [$id])->fetch()));
}
case 'room_units': {
    $me = needPriv('calendar.manage');
    $units = max(0, min(99, (int)req('units')));
    q('UPDATE room_types SET units = ? WHERE id = ?', [$units, (int)req('id')]);
    $r = q('SELECT * FROM room_types WHERE id = ?', [(int)req('id')])->fetch();
    if (!$r) fail('Room type not found', 404);
    audit($me, 'room.units', "{$r['name']} · $units rooms");
    out(roomOut($r));
}
case 'room_delete': {
    $me = needPriv('rooms.manage');
    $id = (int)req('id');
    if (q('SELECT COUNT(*) FROM bookings WHERE room_type_id = ? AND status IN ' . ACTIVE, [$id])->fetchColumn() > 0)
        fail('This room type still has active bookings. Hide it from guests instead.');
    $name = q('SELECT name FROM room_types WHERE id = ?', [$id])->fetchColumn();
    q('DELETE FROM room_types WHERE id = ?', [$id]);
    audit($me, 'room.delete', (string)$name);
    out(true);
}
case 'addons':
    out(array_map('addonOut', q('SELECT * FROM addons ORDER BY price')->fetchAll()));
case 'addon_save': {
    $me = needPriv('rooms.manage');
    $f = [clean(req('name'), 120), clean(opt('description', ''), 255), max(0, (float)req('price')), clean(opt('image', ''), 500), opt('active', true) ? 1 : 0];
    $id = (int)opt('id', 0);
    if ($id > 0) q('UPDATE addons SET name=?, description=?, price=?, image=?, active=? WHERE id=?', [...$f, $id]);
    else { q('INSERT INTO addons (name, description, price, image, active) VALUES (?,?,?,?,?)', $f); $id = (int)$pdo->lastInsertId(); }
    audit($me, 'extra.save', "$f[0] · ₱" . number_format($f[2]));
    out(addonOut(q('SELECT * FROM addons WHERE id = ?', [$id])->fetch()));
}
case 'addon_delete': {
    $me = needPriv('rooms.manage');
    $name = q('SELECT name FROM addons WHERE id = ?', [(int)req('id')])->fetchColumn();
    q('DELETE FROM addons WHERE id = ?', [(int)req('id')]);
    audit($me, 'extra.delete', (string)$name);
    out(true);
}

// ================================================================ availability
case 'ranges':
    out(array_map(fn($r) => ['room_type_id' => (int)$r['room_type_id'], 'check_in' => $r['check_in'], 'check_out' => $r['check_out']],
        q('SELECT room_type_id, check_in, check_out FROM bookings WHERE status IN ' . ACTIVE . ' AND check_out >= CURDATE()')->fetchAll()));
case 'closed_dates':
    out(q('SELECT date, reason FROM closed_dates WHERE date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY) ORDER BY date')->fetchAll());
case 'closed_set': {
    $me = needPriv('calendar.manage');
    $date = req('date');
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) fail('Bad date');
    if (opt('closed')) { q('REPLACE INTO closed_dates (date, reason) VALUES (?, ?)', [$date, clean(opt('reason', 'Closed'), 160)]); audit($me, 'calendar.close', "$date · " . clean(opt('reason', 'Closed'), 160)); }
    else { q('DELETE FROM closed_dates WHERE date = ?', [$date]); audit($me, 'calendar.open', $date); }
    out(true);
}

// ================================================================ bookings
case 'bookings': {
    $u = needUser();
    if ($u['role'] === 'admin') { needPriv('bookings.view'); $rows = q(BOOKING_SELECT . ' ORDER BY b.check_in DESC, b.id DESC')->fetchAll(); }
    else $rows = q(BOOKING_SELECT . ' WHERE b.user_id = ? ORDER BY b.check_in DESC', [$u['id']])->fetchAll();
    out(bookingsOut($rows));
}
case 'booking_create': {
    $u = needUser();
    if ($u['role'] === 'admin') fail('Staff accounts cannot make guest bookings.');
    $room = q('SELECT * FROM room_types WHERE id = ?', [(int)req('room_type_id')])->fetch();
    if (!$room || !$room['visible']) fail('That room type is not available.');
    try { $ci = new DateTime(req('check_in')); $co = new DateTime(req('check_out')); } catch (Throwable $e) { fail('Bad dates'); }
    $today = new DateTime('today');
    if ($ci < $today) fail('Check-in date is in the past.');
    $nights = (int)$ci->diff($co)->days;
    if ($co <= $ci || $nights < 1) fail('Check-out must be after check-in.');
    if ($nights > 30) fail('Stays are limited to 30 nights.');
    $guests = max(1, (int)opt('guests', 1));
    if ($guests > (int)$room['capacity']) fail('Too many guests for this room.');
    if (q('SELECT 1 FROM closed_dates WHERE date = ?', [$ci->format('Y-m-d')])->fetch()) fail('The hotel is not taking check-ins on that date.');
    // limit open requests per guest (anti-spam)
    if ((int)q("SELECT COUNT(*) FROM bookings WHERE user_id = ? AND status = 'pending'", [$u['id']])->fetchColumn() >= 5)
        fail('You already have 5 bookings waiting for confirmation.');
    for ($d = clone $ci; $d < $co; $d->modify('+1 day')) {
        $n = (int)q('SELECT COUNT(*) FROM bookings WHERE room_type_id = ? AND status IN ' . ACTIVE . ' AND check_in <= ? AND check_out > ?',
            [$room['id'], $d->format('Y-m-d'), $d->format('Y-m-d')])->fetchColumn();
        if ($n >= (int)$room['units']) fail('Sorry, ' . $room['name'] . ' is fully booked on ' . $d->format('M j') . '.');
    }
    $addons = [];
    $ids = array_map('intval', (array)opt('addons', []));
    if ($ids) {
        $ph = implode(',', array_fill(0, count($ids), '?'));
        $addons = q("SELECT * FROM addons WHERE active = 1 AND id IN ($ph)", $ids)->fetchAll();
    }
    $pay = in_array(opt('payment_method'), ['Pay at front desk', 'GCash at check-in', 'Card at front desk'], true) ? opt('payment_method') : 'Pay at front desk';
    $roomTotal = (float)$room['price'] * $nights;
    $addTotal = array_sum(array_map(fn($a) => (float)$a['price'], $addons));
    $pdo->beginTransaction();
    q('INSERT INTO bookings (user_id, room_type_id, check_in, check_out, guests, nights, room_total, addons_total, total, status, payment_method, note, staff_note)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
       [$u['id'], $room['id'], $ci->format('Y-m-d'), $co->format('Y-m-d'), $guests, $nights, $roomTotal, $addTotal, $roomTotal + $addTotal,
        'pending', $pay, clean(opt('note', ''), 500), '']);
    $id = (int)$pdo->lastInsertId();
    q('UPDATE bookings SET code = ? WHERE id = ?', ['TL-' . (1000 + $id), $id]);
    foreach ($addons as $a) q('INSERT INTO booking_addons (booking_id, addon_id, name, price) VALUES (?,?,?,?)', [$id, $a['id'], $a['name'], $a['price']]);
    $pdo->commit();
    out(bookingById($id), 201);
}
case 'booking_update': {
    $u = needUser();
    $b = q('SELECT b.*, u.name guest_name FROM bookings b JOIN users u ON u.id = b.user_id WHERE b.id = ?', [(int)req('id')])->fetch();
    if (!$b) fail('Booking not found', 404);
    $status = opt('status');
    $allowed = ['pending', 'confirmed', 'checked_in', 'checked_out', 'cancelled'];
    if ($status !== null && !in_array($status, $allowed, true)) fail('Unknown status');
    if ($u['role'] !== 'admin') {
        if ((int)$b['user_id'] !== (int)$u['id']) fail('Not your booking.', 403);
        if ($status !== 'cancelled' || !in_array($b['status'], ['pending', 'confirmed'])) fail('You can only cancel a pending or confirmed booking.');
    } else {
        if ($status === 'cancelled' && $b['status'] !== 'pending') needPriv('bookings.cancel');
        elseif ($status !== null) needPriv('bookings.manage');
        if (opt('staff_note') !== null) needPriv('bookings.manage');
    }
    if ($status !== null) {
        q('UPDATE bookings SET status = ?, updated_at = NOW() WHERE id = ?', [$status, $b['id']]);
        if ($u['role'] === 'admin') {
            $verb = ['confirmed' => 'confirm', 'checked_in' => 'check_in', 'checked_out' => 'check_out', 'cancelled' => $b['status'] === 'pending' ? 'decline' : 'cancel', 'pending' => 'reopen'][$status];
            audit($u, "booking.$verb", "{$b['code']} · {$b['guest_name']}");
        }
    }
    if ($u['role'] === 'admin' && opt('staff_note') !== null) {
        q('UPDATE bookings SET staff_note = ? WHERE id = ?', [clean(opt('staff_note'), 500), $b['id']]);
        audit($u, 'booking.note', $b['code']);
    }
    out(bookingById((int)$b['id']));
}

// ================================================================ guests (staff)
case 'guests': {
    needPriv('guests.view');
    $rows = q("SELECT u.*, MAX(CASE WHEN b.status IN ('checked_in','checked_out') THEN b.check_in END) last_stay,
                      COUNT(b.id) bookings_count,
                      COALESCE(SUM(CASE WHEN b.status = 'checked_out' THEN b.total END), 0) spent
               FROM users u LEFT JOIN bookings b ON b.user_id = u.id
               WHERE u.role = 'guest' GROUP BY u.id ORDER BY u.name")->fetchAll();
    out(array_map(fn($u) => userOut($u) + ['last_stay' => $u['last_stay'], 'bookings_count' => (int)$u['bookings_count'], 'spent' => (float)$u['spent']], $rows));
}

// ================================================================ favourites
case 'favorites': {
    $u = needUser();
    out(array_map('intval', array_column(q('SELECT room_type_id FROM favorites WHERE user_id = ?', [$u['id']])->fetchAll(), 'room_type_id')));
}
case 'favorite_toggle': {
    $u = needUser(); $rid = (int)req('room_type_id');
    if (q('SELECT 1 FROM favorites WHERE user_id = ? AND room_type_id = ?', [$u['id'], $rid])->fetch()) {
        q('DELETE FROM favorites WHERE user_id = ? AND room_type_id = ?', [$u['id'], $rid]); out(false);
    }
    q('INSERT INTO favorites (user_id, room_type_id) VALUES (?, ?)', [$u['id'], $rid]); out(true);
}

// ================================================================ reviews
case 'reviews': {
    $sql = 'SELECT v.*, u.name user_name FROM reviews v JOIN users u ON u.id = v.user_id';
    $rows = opt('room_type_id') ? q($sql . ' WHERE v.room_type_id = ? ORDER BY v.created_at DESC', [(int)opt('room_type_id')])->fetchAll()
                                : q($sql . ' ORDER BY v.created_at DESC')->fetchAll();
    out(array_map(fn($v) => ['id' => (int)$v['id'], 'user_id' => (int)$v['user_id'], 'user_name' => $v['user_name'],
        'room_type_id' => (int)$v['room_type_id'], 'booking_id' => $v['booking_id'] ? (int)$v['booking_id'] : null,
        'rating' => (int)$v['rating'], 'comment' => $v['comment'] ?? '', 'created_at' => $v['created_at']], $rows));
}
case 'review_add': {
    $u = needUser();
    $b = q('SELECT * FROM bookings WHERE id = ? AND user_id = ?', [(int)req('booking_id'), $u['id']])->fetch();
    if (!$b || $b['status'] !== 'checked_out') fail('You can rate a stay after checking out.');
    if (q('SELECT 1 FROM reviews WHERE booking_id = ?', [$b['id']])->fetch()) fail('You already rated this stay.');
    $rating = max(1, min(5, (int)req('rating')));
    q('INSERT INTO reviews (user_id, room_type_id, booking_id, rating, comment) VALUES (?,?,?,?,?)', [$u['id'], $b['room_type_id'], $b['id'], $rating, clean(opt('comment', ''), 1000)]);
    out(true, 201);
}

default:
    fail('Unknown action', 404);
}
