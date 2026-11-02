"""Generates the dummy data for BOTH the MySQL database (XAMPP) and the
Flutter offline/demo mode, so the two always match.

Run:  python3 tools/gen_seed.py
Outputs:
  xampp/database/tala_hotel.sql
  lib/data/seed_data.dart
"""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Free photos from Unsplash (Unsplash License). Every id below was checked on unsplash.com.
# fm=jpg forces plain JPEG so every browser / Flutter renderer can decode it.
IMG_BASE = "https://images.unsplash.com/"
IMG_QUERY = "?fm=jpg&q=70&w=1000&fit=crop"


def img(pid):
    return f"{IMG_BASE}{pid}{IMG_QUERY}"


# ---------------------------------------------------------------- users & staff
PRIVS = ["bookings.view", "bookings.manage", "bookings.cancel", "guests.view",
         "rooms.manage", "calendar.manage", "reports.view", "staff.manage"]
PRESETS = {
    "Owner": PRIVS,
    "Manager": [p for p in PRIVS if p != "staff.manage"],
    "Front desk": ["bookings.view", "bookings.manage", "guests.view"],
}

def U(id, name, email, phone, pw, role="guest", staff_role=None, active=1, joined=100, last_h=None, last_ip=None):
    return dict(id=id, name=name, email=email, phone=phone, password=pw, role=role, staff_role=staff_role,
                privileges=PRESETS.get(staff_role, []) if role == "admin" else [], active=active,
                joined=joined, last_h=last_h, last_ip=last_ip)

USERS = [
    U(1, "Tala Admin", "admin@talahotel.ph", "0917 000 0000", "admin123", "admin", "Owner", joined=400, last_h=20, last_ip="192.168.1.10"),
    U(2, "Juan Dela Cruz", "juan.delacruz@gmail.com", "0917 482 1936", "password123", joined=210, last_h=48, last_ip="112.198.4.20"),
    U(3, "Ana Reyes", "ana.reyes@gmail.com", "0918 552 7710", "password123", joined=160, last_h=6, last_ip="49.145.20.7"),
    U(4, "Mark Santos", "mark.santos@yahoo.com", "0927 113 4080", "password123", joined=140),
    U(5, "Rica Lopez", "rica.lopez@gmail.com", "0905 774 2391", "password123", joined=95),
    U(6, "Paolo Garcia", "paolo.garcia@outlook.com", "0919 640 1188", "password123", joined=60),
    U(7, "Liza Manalo", "liza.manalo@gmail.com", "0936 208 5521", "password123", joined=12),
    U(8, "Rafael Mendoza", "manager@talahotel.ph", "0917 111 2020", "manager123", "admin", "Manager", joined=300, last_h=5, last_ip="192.168.1.22"),
    U(9, "Joy Fernandez", "frontdesk@talahotel.ph", "0917 333 4545", "desk1234", "admin", "Front desk", joined=200, last_h=3, last_ip="192.168.1.31"),
    U(10, "Ben Aquino", "ben.aquino@talahotel.ph", "0917 555 6767", "desk1234", "admin", "Front desk", active=0, joined=250, last_h=240, last_ip="192.168.1.40"),
]

# Login history: email, user id, success, reason, portal, ip, device, hours ago
LOGINS = [
    ("ben.aquino@talahotel.ph", 10, 0, "disabled", "staff", "192.168.1.40", "Chrome on Windows", 26),
    ("admin@tala.ph", None, 0, "bad_password", "staff", "203.177.12.8", "Firefox on Linux", 30),
    ("admin@tala.ph", None, 0, "bad_password", "staff", "203.177.12.8", "Firefox on Linux", 30),
    ("admin@talahotel.ph", 1, 1, "ok", "staff", "192.168.1.10", "Chrome on Windows", 20),
    ("juan.delacruz@gmail.com", 2, 1, "ok", "guest", "112.198.4.20", "Safari on iPhone", 48),
    ("ana.reyes@gmail.com", 3, 1, "ok", "guest", "49.145.20.7", "Chrome on Android", 6),
    ("manager@talahotel.ph", 8, 1, "ok", "staff", "192.168.1.22", "Chrome on Android", 5),
    ("frontdesk@talahotel.ph", 9, 0, "bad_password", "staff", "192.168.1.31", "Edge on Windows", 3.1),
    ("frontdesk@talahotel.ph", 9, 0, "bad_password", "staff", "192.168.1.31", "Edge on Windows", 3.05),
    ("frontdesk@talahotel.ph", 9, 1, "ok", "staff", "192.168.1.31", "Edge on Windows", 3),
    ("juan.delacruz@gmail.com", 2, 0, "wrong_portal", "staff", "112.198.4.20", "Safari on iPhone", 47),
]

# Audit trail: user id, name, action, details, hours ago
AUDIT = [
    (8, "Rafael Mendoza", "room.update", "Deluxe King · price ₱3,450", 50),
    (8, "Rafael Mendoza", "calendar.close", "Closed a day · Private event — hotel buy-out", 40),
    (1, "Tala Admin", "staff.update", "Disabled Ben Aquino", 26),
    (9, "Joy Fernandez", "booking.check_in", "TL-1006 · Mark Santos", 24),
    (9, "Joy Fernandez", "booking.check_in", "TL-1015 · Paolo Garcia", 23),
    (9, "Joy Fernandez", "booking.check_in", "TL-1007 · Rica Lopez", 22),
    (9, "Joy Fernandez", "booking.confirm", "TL-1014 · Liza Manalo", 4),
]

# ---------------------------------------------------------------- rooms
ROOMS = [
    dict(id=1, name="Standard Queen", category="Standard",
         description="A calm, compact room with a plush queen bed, rain shower and a work desk by the window. Ideal for solo travellers and couples.",
         price=2450, capacity=2, size=22, beds="1 Queen bed", units=8, popular=0, visible=1,
         images=[img("photo-1631049307264-da0ec9d70304"), img("photo-1629140727571-9b5c6f6267b4"), img("photo-1631049552057-403cdb8f0658")],
         amenities=["Free Wi-Fi", "Air-conditioning", "Smart TV", "Rain shower", "Work desk"]),
    dict(id=2, name="Deluxe King", category="Deluxe",
         description="Our most-booked room: a king bed, floor-to-ceiling windows with a city view, a lounge chair and a minibar.",
         price=3450, capacity=2, size=28, beds="1 King bed", units=6, popular=1, visible=1,
         images=[img("photo-1618773928121-c32242e63f39"), img("photo-1781572725438-ac8c41476752"), img("photo-1765423587693-afd93c579a2d")],
         amenities=["Free Wi-Fi", "City view", "Minibar", "Smart TV", "Coffee maker", "Bathtub"]),
    dict(id=3, name="Deluxe Twin", category="Deluxe",
         description="Two double beds for friends or small families, with extra wardrobe space and a sitting nook.",
         price=3200, capacity=3, size=26, beds="2 Double beds", units=5, popular=0, visible=1,
         images=[img("photo-1611892440504-42a792e24d32"), img("photo-1711059985570-4c32ed12a12c"), img("photo-1562438668-bcf0ca6578f0")],
         amenities=["Free Wi-Fi", "Air-conditioning", "Smart TV", "Minibar", "Sofa nook"]),
    dict(id=4, name="Family Room", category="Deluxe",
         description="Room for everyone: a king bed plus a bunk nook, a dining corner and a larger bathroom with tub.",
         price=5200, capacity=4, size=40, beds="1 King + 1 Bunk bed", units=4, popular=0, visible=1,
         images=[img("photo-1578683010236-d716f9a3f461"), img("photo-1583847268964-b28dc8f51f92"), img("photo-1765547090903-348b711f0eee")],
         amenities=["Free Wi-Fi", "Bathtub", "Dining corner", "Smart TV", "Microwave", "Kids' kit"]),
    dict(id=5, name="Executive Suite", category="Suite",
         description="A separate living room, king bedroom and a deep soaking tub, plus Executive Lounge access and evening canapés.",
         price=7800, capacity=3, size=55, beds="1 King bed + Sofa bed", units=2, popular=1, visible=1,
         images=[img("photo-1778205015308-1ed324aea202"), img("photo-1768144092684-c1a5dd6c7aad"), img("photo-1564078516393-cf04bd966897")],
         amenities=["Lounge access", "Living room", "Soaking tub", "Nespresso", "Bathrobes", "City view"]),
    dict(id=6, name="Sky Loft Suite", category="Suite",
         description="Our top-floor two-level loft with a private terrace, panoramic sunset view over the river and a butler on call.",
         price=12500, capacity=4, size=80, beds="1 King + 2 Single beds", units=1, popular=0, visible=1,
         images=[img("photo-1761602866012-ae9f888255dc"), img("photo-1761971976519-7e27a35c9c49"), img("photo-1590381105924-c72589b9ef3f")],
         amenities=["Private terrace", "Butler on call", "Panoramic view", "Bathtub", "Kitchenette", "Lounge access"]),
]

EXTRA_PHOTOS = [
    "photo-1551882547-ff40c63fe5fa", "photo-1716667282993-cd8f2bffb91f", "photo-1445019980597-93fa8acb246c",
    "photo-1520250497591-112f2f40a3f4", "photo-1566073771259-6a8506099945", "photo-1782890790046-2aefb0b503cb",
    "photo-1621293954908-907159247fc8", "photo-1504754524776-8f4f37790ca0", "photo-1696841212541-449ca29397cc",
    "photo-1759328257280-28bdb3050be3", "photo-1549294413-26f195200c16", "photo-1781440312665-1d0704995f0d",
]

# ---------------------------------------------------------------- extras (add-ons, price per stay)
ADDONS = [
    (1, "Breakfast for two", "Daily buffet at Kusina, 6:00–10:00 AM", 650, img("photo-1596701062351-8c2c14d1fdd0")),
    (2, "Airport / terminal pickup", "Private car from the airport or bus terminal", 800, img("photo-1772468237159-674f05233185")),
    (3, "60-min spa massage", "Hilot or Swedish at the Tala Spa", 1200, img("photo-1600334089648-b0d9d3028eb2")),
    (4, "Late checkout (4 PM)", "Keep your room until 4:00 PM", 600, img("photo-1759328257280-28bdb3050be3")),
    (5, "Extra bed", "Rollaway bed with linens", 900, img("photo-1631049552057-403cdb8f0658")),
    (6, "Romantic setup", "Petals, cake and a bottle of wine on arrival", 1500, img("photo-1620733723572-11c53f73a416")),
]

ROOM_PRICE = {r["id"]: r["price"] for r in ROOMS}
ADDON_PRICE = {a[0]: a[3] for a in ADDONS}

# ---------------------------------------------------------------- bookings
# id, user, room, check-in offset (days from today), nights, guests, status, addons, payment, note, staff note, created (days ago)
BOOKINGS = [
    (1, 2, 2, 5, 2, 2, "confirmed", [1], "Pay at front desk", "Celebrating our anniversary — a high floor please.", "", 3),
    (2, 2, 4, 12, 3, 4, "pending", [2], "GCash at check-in", "Arriving by bus around 3 PM.", "", 1),
    (3, 2, 1, -20, 1, 2, "checked_out", [], "Pay at front desk", "", "Quiet guests, left room tidy.", 25),
    (4, 2, 3, -45, 2, 3, "cancelled", [], "Pay at front desk", "", "Guest cancelled by phone.", 50),
    (5, 3, 5, 0, 2, 2, "confirmed", [1, 3], "Card at front desk", "Allergic to feather pillows.", "Swap to foam pillows.", 9),
    (6, 4, 2, -1, 3, 2, "checked_in", [], "Pay at front desk", "", "Requested extra towels.", 6),
    (7, 5, 1, -2, 2, 1, "checked_in", [4], "GCash at check-in", "Business trip, need early breakfast.", "", 8),
    (8, 6, 3, 1, 2, 3, "pending", [], "Pay at front desk", "", "", 0),
    (9, 7, 6, 3, 2, 4, "pending", [6, 1], "Card at front desk", "Surprise birthday for my mom!", "", 0),
    (10, 4, 4, -30, 2, 4, "checked_out", [5], "Pay at front desk", "", "", 40),
    (11, 3, 2, 0, 1, 2, "pending", [], "GCash at check-in", "Can we check in early, around noon?", "", 0),
    (12, 6, 1, -10, 3, 2, "checked_out", [1], "Pay at front desk", "", "", 15),
    (13, 5, 5, 7, 2, 2, "confirmed", [2], "Card at front desk", "", "", 4),
    (14, 7, 1, 0, 2, 2, "confirmed", [], "Pay at front desk", "", "", 5),
    (15, 6, 5, -1, 2, 3, "checked_in", [3], "Card at front desk", "", "VIP — welcome amenity sent.", 11),
]

# ---------------------------------------------------------------- reviews
# id, user, room, booking or None, rating, comment, days ago
REVIEWS = [
    (1, 2, 1, 3, 5, "Spotless room and the quickest check-in I've had.", 19),
    (2, 4, 4, 10, 4, "Kids loved the bunk nook. Breakfast could be earlier.", 28),
    (3, 6, 1, 12, 4, "Great value. Shower pressure is excellent.", 7),
    (4, 3, 2, None, 5, "The city view at night is beautiful. Bed was super comfy.", 60),
    (5, 5, 5, None, 5, "Lounge canapés were a treat. Worth every peso.", 45),
    (6, 7, 2, None, 4, "Lovely room, a bit of street noise on weekends.", 30),
    (7, 4, 6, None, 5, "The terrace sunset is unreal. Butler service was spot on.", 90),
    (8, 5, 3, None, 4, "Roomy for three people. Good Wi-Fi.", 50),
]

CLOSED = [(21, "Private event — hotel buy-out")]


def money(v):
    return f"{v:.2f}"


def sql_str(s):
    if s is None:
        return "NULL"
    return "'" + str(s).replace("\\", "\\\\").replace("'", "''") + "'"


def php_hash(pw):
    out = subprocess.check_output(["php", "-r", f"echo password_hash({json.dumps(pw)}, PASSWORD_DEFAULT);"])
    return out.decode()


def gen_sql():
    schema = (ROOT / "tools" / "schema.sql").read_text()
    lines = [schema, "", "-- ============================================================ DUMMY DATA", ""]
    lines.append("INSERT INTO users (id, name, email, phone, password_hash, role, staff_role, privileges, active, must_change_password, last_login_at, last_login_ip, password_changed_at, created_at) VALUES")
    rows = []
    for u in USERS:
        last = f"DATE_SUB(NOW(), INTERVAL {int(u['last_h'] * 60)} MINUTE)" if u['last_h'] is not None else "NULL"
        privs = sql_str(json.dumps(u['privileges'])) if u['role'] == 'admin' else "NULL"
        rows.append(f"({u['id']}, {sql_str(u['name'])}, {sql_str(u['email'])}, {sql_str(u['phone'])}, {sql_str(php_hash(u['password']))}, "
                    f"{sql_str(u['role'])}, {sql_str(u['staff_role'])}, {privs}, {u['active']}, {1 if u['role'] == 'admin' else 0}, {last}, {sql_str(u['last_ip'])}, "
                    f"DATE_SUB(NOW(), INTERVAL {u['joined']} DAY), DATE_SUB(NOW(), INTERVAL {u['joined']} DAY))")
    lines.append(",\n".join(rows) + ";\n")

    lines.append("INSERT INTO login_attempts (email, user_id, success, reason, portal, ip, user_agent, created_at) VALUES")
    lines.append(",\n".join(f"({sql_str(e)}, {uid if uid else 'NULL'}, {s}, {sql_str(r)}, {sql_str(po)}, {sql_str(ip)}, {sql_str(ua)}, DATE_SUB(NOW(), INTERVAL {int(h * 60)} MINUTE))"
                             for (e, uid, s, r, po, ip, ua, h) in sorted(LOGINS, key=lambda x: -x[7])) + ";\n")

    lines.append("INSERT INTO audit_log (user_id, user_name, action, details, ip, created_at) VALUES")
    lines.append(",\n".join(f"({uid}, {sql_str(n)}, {sql_str(a)}, {sql_str(d)}, '192.168.1.10', DATE_SUB(NOW(), INTERVAL {h} HOUR))"
                             for (uid, n, a, d, h) in sorted(AUDIT, key=lambda x: -x[4])) + ";\n")

    lines.append("INSERT INTO room_types (id, name, category, description, price, capacity, size_sqm, beds, units, popular, visible, images, amenities) VALUES")
    rows = []
    for r in ROOMS:
        rows.append("({id}, {name}, {cat}, {desc}, {price}, {cap}, {size}, {beds}, {units}, {pop}, {vis}, {imgs}, {am})".format(
            id=r["id"], name=sql_str(r["name"]), cat=sql_str(r["category"]), desc=sql_str(r["description"]),
            price=money(r["price"]), cap=r["capacity"], size=r["size"], beds=sql_str(r["beds"]), units=r["units"],
            pop=r["popular"], vis=r["visible"], imgs=sql_str(json.dumps(r["images"])), am=sql_str(json.dumps(r["amenities"]))))
    lines.append(",\n".join(rows) + ";\n")

    lines.append("INSERT INTO addons (id, name, description, price, image, active) VALUES")
    lines.append(",\n".join(f"({i}, {sql_str(n)}, {sql_str(d)}, {money(p)}, {sql_str(im)}, 1)" for (i, n, d, p, im) in ADDONS) + ";\n")

    lines.append("INSERT INTO bookings (id, code, user_id, room_type_id, check_in, check_out, guests, nights, room_total, addons_total, total, status, payment_method, note, staff_note, created_at, updated_at) VALUES")
    rows = []
    for (i, u, r, off, n, g, st, ads, pay, note, staff, ago) in BOOKINGS:
        rt = ROOM_PRICE[r] * n
        at = sum(ADDON_PRICE[a] for a in ads)
        rows.append(f"({i}, 'TL-{1000 + i}', {u}, {r}, DATE_ADD(CURDATE(), INTERVAL {off} DAY), DATE_ADD(CURDATE(), INTERVAL {off + n} DAY), {g}, {n}, {money(rt)}, {money(at)}, {money(rt + at)}, {sql_str(st)}, {sql_str(pay)}, {sql_str(note)}, {sql_str(staff)}, DATE_SUB(NOW(), INTERVAL {ago} DAY), DATE_SUB(NOW(), INTERVAL {max(ago - 1, 0)} DAY))")
    lines.append(",\n".join(rows) + ";\n")

    lines.append("INSERT INTO booking_addons (booking_id, addon_id, name, price) VALUES")
    rows = []
    names = {a[0]: a[1] for a in ADDONS}
    for b in BOOKINGS:
        for a in b[7]:
            rows.append(f"({b[0]}, {a}, {sql_str(names[a])}, {money(ADDON_PRICE[a])})")
    lines.append(",\n".join(rows) + ";\n")

    lines.append("INSERT INTO reviews (id, user_id, room_type_id, booking_id, rating, comment, created_at) VALUES")
    lines.append(",\n".join(f"({i}, {u}, {r}, {b if b else 'NULL'}, {rt}, {sql_str(c)}, DATE_SUB(NOW(), INTERVAL {ago} DAY))" for (i, u, r, b, rt, c, ago) in REVIEWS) + ";\n")

    lines.append("INSERT INTO favorites (user_id, room_type_id) VALUES (2, 2), (2, 5), (3, 6);\n")
    lines.append("INSERT INTO closed_dates (date, reason) VALUES")
    lines.append(",\n".join(f"(DATE_ADD(CURDATE(), INTERVAL {o} DAY), {sql_str(r)})" for (o, r) in CLOSED) + ";\n")
    (ROOT / "xampp" / "database" / "tala_hotel.sql").write_text("\n".join(lines))


def dart_str(s):
    return json.dumps(s, ensure_ascii=False).replace("$", "\\$")


def gen_dart():
    o = ["// GENERATED by tools/gen_seed.py — the same dummy data as xampp/database/tala_hotel.sql.",
         "// Dates are offsets from today so the demo always looks 'live'.",
         "",
         "const seedUsers = <Map<String, dynamic>>["]
    for u in USERS:
        privs = "<String>[" + ", ".join(dart_str(x) for x in u['privileges']) + "]"
        o.append(f"  {{'id': {u['id']}, 'name': {dart_str(u['name'])}, 'email': {dart_str(u['email'])}, 'phone': {dart_str(u['phone'])}, "
                 f"'password': {dart_str(u['password'])}, 'role': '{u['role']}', 'staff_role': {dart_str(u['staff_role']) if u['staff_role'] else 'null'}, "
                 f"'privileges': {privs}, 'active': {u['active']}, 'joinedDaysAgo': {u['joined']}, "
                 f"'lastLoginHoursAgo': {u['last_h'] if u['last_h'] is not None else 'null'}, 'last_login_ip': {dart_str(u['last_ip']) if u['last_ip'] else 'null'}}},")
    o.append("];\n")
    o.append("const seedLogins = <Map<String, dynamic>>[")
    for (e, uid, s, r, po, ip, ua, h) in sorted(LOGINS, key=lambda x: -x[7]):
        o.append(f"  {{'email': {dart_str(e)}, 'user_id': {uid if uid else 'null'}, 'success': {s}, 'reason': '{r}', 'portal': '{po}', 'ip': '{ip}', 'user_agent': {dart_str(ua)}, 'hoursAgo': {h}}},")
    o.append("];\n")
    o.append("const seedAudit = <Map<String, dynamic>>[")
    for (uid, n, a, d, h) in sorted(AUDIT, key=lambda x: -x[4]):
        o.append(f"  {{'user_id': {uid}, 'user_name': {dart_str(n)}, 'action': '{a}', 'details': {dart_str(d)}, 'hoursAgo': {h}}},")
    o.append("];\n")
    o.append("const seedRooms = <Map<String, dynamic>>[")
    for r in ROOMS:
        o.append("  {" + ", ".join([
            f"'id': {r['id']}", f"'name': {dart_str(r['name'])}", f"'category': {dart_str(r['category'])}",
            f"'description': {dart_str(r['description'])}", f"'price': {r['price']}", f"'capacity': {r['capacity']}",
            f"'size_sqm': {r['size']}", f"'beds': {dart_str(r['beds'])}", f"'units': {r['units']}",
            f"'popular': {r['popular']}", f"'visible': {r['visible']}",
            "'images': <String>[" + ", ".join(dart_str(x) for x in r["images"]) + "]",
            "'amenities': <String>[" + ", ".join(dart_str(x) for x in r["amenities"]) + "]",
        ]) + "},")
    o.append("];\n")
    o.append("const seedAddons = <Map<String, dynamic>>[")
    for (i, n, d, p, im) in ADDONS:
        o.append(f"  {{'id': {i}, 'name': {dart_str(n)}, 'description': {dart_str(d)}, 'price': {p}, 'image': {dart_str(im)}, 'active': 1}},")
    o.append("];\n")
    o.append("const seedBookings = <Map<String, dynamic>>[")
    for (i, u, r, off, n, g, st, ads, pay, note, staff, ago) in BOOKINGS:
        o.append(f"  {{'id': {i}, 'user_id': {u}, 'room_type_id': {r}, 'offset': {off}, 'nights': {n}, 'guests': {g}, 'status': '{st}', 'addons': <int>{ads}, 'payment_method': {dart_str(pay)}, 'note': {dart_str(note)}, 'staff_note': {dart_str(staff)}, 'createdDaysAgo': {ago}}},")
    o.append("];\n")
    o.append("const seedReviews = <Map<String, dynamic>>[")
    for (i, u, r, b, rt, c, ago) in REVIEWS:
        o.append(f"  {{'id': {i}, 'user_id': {u}, 'room_type_id': {r}, 'booking_id': {b if b else 'null'}, 'rating': {rt}, 'comment': {dart_str(c)}, 'daysAgo': {ago}}},")
    o.append("];\n")
    o.append("const seedFavorites = <List<int>>[[2, 2], [2, 5], [3, 6]];\n")
    o.append("const seedClosed = <Map<String, dynamic>>[" + ", ".join(f"{{'offset': {off}, 'reason': {dart_str(r)}}}" for (off, r) in CLOSED) + "];\n")
    o.append("/// Extra photos the admin can pick from when editing a room or extra.")
    gallery = sorted({x for r in ROOMS for x in r["images"]} | {a[4] for a in ADDONS} | {img(x) for x in EXTRA_PHOTOS})
    o.append("const photoGallery = <String>[")
    for g in gallery:
        o.append(f"  {dart_str(g)},")
    o.append("];")
    o.append("")
    o.append("/// Hero photos used on login / home.")
    o.append(f"const heroLobby = {dart_str(img('photo-1621293954908-907159247fc8'))};")
    o.append(f"const heroNight = {dart_str(img('photo-1782890790046-2aefb0b503cb'))};")
    o.append(f"const heroPool = {dart_str(img('photo-1551882547-ff40c63fe5fa'))};")
    (ROOT / "lib" / "data").mkdir(parents=True, exist_ok=True)
    (ROOT / "lib" / "data" / "seed_data.dart").write_text("\n".join(o) + "\n")


if __name__ == "__main__":
    gen_sql()
    gen_dart()
    print("ok")
