# Tala Hotel: hotel booking app (Flutter + XAMPP)

A guest app and a staff (admin) portal in one Flutter project, with:

* **Light, dark, or follow the phone.** Pick it in Account → Appearance, or tap the sun/moon button.
* **Landscape and tablet layouts.** Rotate the phone and the bottom bar becomes a side rail. Lists spread into 2–3 equal columns, and detail screens split into two panes.
* **Staff roles and privileges.** Owner, Manager, Front desk or Custom. Each staff member sees only the tabs and buttons their privileges allow, and the server checks every action too.
* **Security features.** See the list below.

All records (accounts, bookings, rooms, logins, audit log) are stored in the **XAMPP MySQL database** `tala_hotel`
through `xampp/htdocs/tala_api/api.php`. The server button (🖧) on the login screen sets the API address.

## Starting accounts (created by `tala_hotel.sql`)

Everyone uses the **same login page**: the app sees which account signed in and opens the guest app or the staff dashboard. **Every staff account must choose its own
password at its first sign-in.** Until then the dashboard stays locked (the server refuses all staff actions).

| Role | Email | Starting password |
|---|---|---|
| **Owner** (everything, manages staff) | admin@talahotel.ph | admin123 |
| **Manager** (everything except staff) | manager@talahotel.ph | manager123 |
| **Front desk** (bookings + guests) | frontdesk@talahotel.ph | desk1234 |
| Front desk, **disabled** | ben.aquino@talahotel.ph | — |

Sample guests (for testing bookings): juan.delacruz@gmail.com, ana.reyes@gmail.com … all `password123`. New guests use **Create an account**.

---

## Staff privileges

| Privilege | Owner | Manager | Front desk |
|---|:-:|:-:|:-:|
| View bookings (Today, Bookings, Calendar tabs) | ✓ | ✓ | ✓ |
| Confirm, check in & check out | ✓ | ✓ | ✓ |
| Cancel confirmed bookings | ✓ | ✓ | |
| See guest list & contact details (otherwise masked, e.g. `ju•••@gmail.com`) | ✓ | ✓ | ✓ |
| Edit rooms, prices & extras | ✓ | ✓ | |
| Close days & change room inventory | ✓ | ✓ | |
| See revenue & occupancy | ✓ | ✓ | |
| Manage staff, login activity & audit log | ✓ | | |

The owner can create a **Custom** role and tick any combination of privileges (Account → Staff & privileges).

### Admin dashboard and login information
* **Today** shows a *Signed in as* card with your role, your previous sign-in (time and IP), how many privileges you have, and when your session ends.
* Owners also get a **Security** card: failed sign-ins in the last 24 hours, locked accounts and open staff sessions.
* **Account**: your sign-in information, your privileges, change password, your own sign-in history, appearance and log out.
* Owner-only screens: **Staff & privileges** (add staff, change roles, disable accounts, reset passwords), **Login activity** (every sign-in attempt, with a filter for failed ones), and **Audit log** (who confirmed, cancelled or edited what, and when).

## Security features
1. **Passwords are never stored in plain text.** The server uses bcrypt (`password_hash`); only a SHA-256 hash of each session token is stored.
2. **Password rules:** at least 8 characters with letters and numbers, plus a strength meter.
3. **One login page, role-based access.** The account's role (guest, owner, manager, front desk) decides what opens, and the server checks the role on every action.
4. **Account lockout.** After 5 wrong passwords in 15 minutes, the account is locked for 15 minutes. The message warns when 2 tries are left.
5. **Session tokens.** Each is a random 64-character token, and only its SHA-256 hash is stored. Staff sessions expire after 12 hours, guest sessions after 30 days.
6. **Automatic sign-out** after 10 minutes without activity for staff.
7. **Logging out ends the session on the server.** Changing your password signs out your other devices.
8. **Disabled accounts and password resets** sign that person out everywhere immediately.
9. **Default and reset passwords must be changed** before the staff dashboard opens. **Re-enter your password** before sensitive actions (saving staff accounts, deleting a room type).
10. **Every action is checked against the person's privileges on the server**, not only hidden in the app. Owners can't disable or downgrade themselves by accident, and only an Owner can manage other Owners.
11. **Login history and an audit log** record every sign-in attempt (with IP and device) and every staff action.
12. **API hardening:** prepared statements only (no SQL injection), input length limits, security headers (`nosniff`, `DENY` framing, `no-store`), an allow-list of payment methods, a limit of 5 pending bookings per guest, and an optional list of allowed origins in `config.php`.

---

## Quick start (Windows)
| Double-click | What it does |
|---|---|
| `2_RUN_APP.bat` | `flutter pub get` + runs the app in Chrome (start XAMPP first) |
| `1_SETUP_XAMPP.bat` | copies the API into `C:\xampp\htdocs\tala_api` and creates the database with all dummy data (start Apache + MySQL first) |
| `3_BUILD_FOR_XAMPP.bat` | builds the web app and publishes it to `http://localhost/tala/` |
| `4_MAKE_PORTABLE_PACKAGE.bat` | makes a `Tala_Portable` folder (built app + API + your records). On another laptop only XAMPP is needed: double-click its `INSTALL.bat`. See `RUN_COMMANDS.txt`. |

## 1. Run it on FlutLab.io (XAMPP must be running on the same PC)
1. Create a new Flutter project on FlutLab.
2. Replace `pubspec.yaml` with the one here, then run **Pub get**.
3. Replace FlutLab's `lib/` and `web/` with this project's folders, keeping the sub-folders.
4. Replace `test/widget_test.dart` with the one here.
5. Press **Run** (Web). Chrome may ask to allow access to local network devices — click **Allow** so it can reach XAMPP.

You need Flutter 3.10 or newer (Dart 3).

## 2. Run it on your PC
```
flutter pub get
flutter create . --platforms web     (once; adds the web/ folder)
flutter run -d chrome
flutter test                          (13 tests: booking rules + security, run on an in-memory copy of the data)
```

## 3. Set up the XAMPP database
1. Start **Apache** and **MySQL** in XAMPP.
2. Open http://localhost/phpmyadmin, go to **Import**, choose `xampp/database/tala_hotel.sql` and click **Go**.
   This creates every table and all the dummy data, including staff, login history and the audit log.
   *If you imported an earlier version, import it again: the tables changed.*
3. Copy `xampp/htdocs/tala_api` to `C:\xampp\htdocs\`.
4. Open http://localhost/tala_api/. It should show `"ok":true`.
5. The app already uses `http://localhost/tala_api/api.php`. To change it, tap the server button on the login screen → **Test** → **Save**.

Security settings (lockout, session hours, allowed origins) are in `tala_api/config.php`.

**Most reliable way to present:** run `flutter build web --base-href /tala/`, copy `build/web` to `C:\xampp\htdocs\tala`, and open http://localhost/tala/. The app and the API then share one origin. On a phone, use your PC's IP address instead of `localhost`.

---

## What's inside
```
lib/
  main.dart                    splash → login → guest or staff app; theme switching
  theme.dart                   light + dark palettes, fonts, transitions, Screen helpers
  models.dart                  users, privileges (Priv), rooms, bookings, login events, audit…
  state/app_state.dart         app state, availability maths, idle sign-out, theme mode
  data/  repository.dart · local_repository.dart · api_repository.dart · seed_data.dart
  widgets/
    motion.dart                animations (staggered fade-ins, press-scale, cross-fading tabs…)
    common.dart · cards.dart   buttons, chips, date strip, nav bar, dialogs, cards
    adaptive.dart              landscape/tablet: side rail, equal-width grids, two-pane screens
    security_widgets.dart      theme picker, password strength, re-auth, change password…
  screens/
    auth/                      one login page for everyone, create account, forced password change, server settings
    customer/                  home, rooms, room details, book, bookings, saved, extras, account
    admin/                     today, bookings, guests, rooms & extras, calendar, account,
                               staff & privileges, login activity, audit log
xampp/database/tala_hotel.sql  schema + dummy data
xampp/htdocs/tala_api/         api.php, config.php, index.php
tools/gen_seed.py              regenerates the dummy data for SQL and Dart
```

**Tables:** `users`, `sessions`, `login_attempts`, `audit_log`, `room_types`, `addons`, `bookings`, `booking_addons`, `reviews`, `favorites`, `closed_dates`

**API actions:** `ping, login, logout, register, me_update, verify_password, change_password, staff, staff_save, login_history, audit_log, security_summary, rooms, room_save, room_units, room_delete, addons, addon_save, addon_delete, ranges, closed_dates, closed_set, bookings, booking_create, booking_update, guests, favorites, favorite_toggle, reviews, review_add`
