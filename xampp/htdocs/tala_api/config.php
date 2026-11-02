<?php
// ------------------------------------------------------------------
//  Tala Hotel API — settings (XAMPP defaults)
// ------------------------------------------------------------------
define('DB_HOST', '127.0.0.1');
define('DB_PORT', 3306);
define('DB_NAME', 'tala_hotel');
define('DB_USER', 'root');
define('DB_PASS', '');          // XAMPP's MySQL root has no password by default

// ---------------- security settings
define('MAX_LOGIN_ATTEMPTS', 5);        // failed tries before the account is locked…
define('LOCK_MINUTES', 15);             // …for this many minutes
define('STAFF_SESSION_HOURS', 12);      // staff must log in again after this
define('GUEST_SESSION_DAYS', 30);
// Websites allowed to call the API from a browser. '*' = any (needed for FlutLab).
// For production list them, e.g. ['http://localhost', 'http://192.168.1.5'].
define('ALLOWED_ORIGINS', ['*']);

date_default_timezone_set('Asia/Manila');
