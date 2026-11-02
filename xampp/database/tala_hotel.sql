-- ============================================================
--  TALA HOTEL — database for XAMPP (MySQL / MariaDB)
--  Import in phpMyAdmin: Import > choose this file > Go
--  Default staff accounts must choose a new password at their first sign-in:
--                Owner       admin@talahotel.ph / admin123
--                Manager     manager@talahotel.ph / manager123
--                Front desk  frontdesk@talahotel.ph / desk1234
--  Sample guest: juan.delacruz@gmail.com / password123
-- ============================================================

SET NAMES utf8mb4;
DROP DATABASE IF EXISTS tala_hotel;
CREATE DATABASE tala_hotel CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE tala_hotel;

CREATE TABLE users (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(120) NOT NULL,
  email         VARCHAR(160) NOT NULL UNIQUE,
  phone         VARCHAR(40)  NOT NULL DEFAULT '',
  password_hash VARCHAR(255) NOT NULL,                 -- bcrypt via password_hash()
  role          ENUM('guest','admin') NOT NULL DEFAULT 'guest',   -- admin = hotel staff
  staff_role    VARCHAR(40)  NULL,                     -- Owner / Manager / Front desk / Custom
  privileges    TEXT         NULL,                     -- JSON array, e.g. ["bookings.view","rooms.manage"]
  active        TINYINT(1)   NOT NULL DEFAULT 1,       -- disabled accounts cannot log in
  must_change_password TINYINT(1) NOT NULL DEFAULT 0, -- 1 = must set a new password before using the staff dashboard
  last_login_at DATETIME     NULL,
  last_login_ip VARCHAR(64)  NULL,
  password_changed_at DATETIME NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Login sessions. Only a SHA-256 hash of each token is stored.
CREATE TABLE sessions (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  token_hash CHAR(64) NOT NULL UNIQUE,
  user_id    INT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at DATETIME NOT NULL,
  last_seen  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ip         VARCHAR(64)  NOT NULL DEFAULT '',
  user_agent VARCHAR(255) NOT NULL DEFAULT '',
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Every login attempt (success or failure) — used for lockout and the login history screens.
CREATE TABLE login_attempts (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  email      VARCHAR(160) NOT NULL,
  user_id    INT NULL,
  success    TINYINT(1) NOT NULL DEFAULT 0,
  reason     VARCHAR(40) NOT NULL DEFAULT '',   -- ok, bad_password, locked, disabled, wrong_portal
  portal     VARCHAR(10) NOT NULL DEFAULT 'guest',
  ip         VARCHAR(64)  NOT NULL DEFAULT '',
  user_agent VARCHAR(255) NOT NULL DEFAULT '',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX (email), INDEX (created_at)
) ENGINE=InnoDB;

-- Who did what (staff actions).
CREATE TABLE audit_log (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  user_id    INT NULL,
  user_name  VARCHAR(120) NOT NULL DEFAULT '',
  action     VARCHAR(60)  NOT NULL,
  details    VARCHAR(255) NOT NULL DEFAULT '',
  ip         VARCHAR(64)  NOT NULL DEFAULT '',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX (created_at)
) ENGINE=InnoDB;

CREATE TABLE room_types (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(120) NOT NULL,
  category    VARCHAR(40)  NOT NULL DEFAULT 'Standard',
  description TEXT,
  price       DECIMAL(10,2) NOT NULL DEFAULT 0,
  capacity    INT NOT NULL DEFAULT 2,
  size_sqm    INT NOT NULL DEFAULT 20,
  beds        VARCHAR(80) NOT NULL DEFAULT '',
  units       INT NOT NULL DEFAULT 1,
  popular     TINYINT(1) NOT NULL DEFAULT 0,
  visible     TINYINT(1) NOT NULL DEFAULT 1,
  images      TEXT,           -- JSON array of image URLs
  amenities   TEXT            -- JSON array of strings
) ENGINE=InnoDB;

CREATE TABLE addons (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(120) NOT NULL,
  description VARCHAR(255) NOT NULL DEFAULT '',
  price       DECIMAL(10,2) NOT NULL DEFAULT 0,
  image       VARCHAR(500) NOT NULL DEFAULT '',
  active      TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB;

CREATE TABLE bookings (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  code           VARCHAR(20) NOT NULL DEFAULT '',
  user_id        INT NOT NULL,
  room_type_id   INT NOT NULL,
  check_in       DATE NOT NULL,
  check_out      DATE NOT NULL,
  guests         INT NOT NULL DEFAULT 1,
  nights         INT NOT NULL DEFAULT 1,
  room_total     DECIMAL(10,2) NOT NULL DEFAULT 0,
  addons_total   DECIMAL(10,2) NOT NULL DEFAULT 0,
  total          DECIMAL(10,2) NOT NULL DEFAULT 0,
  status         ENUM('pending','confirmed','checked_in','checked_out','cancelled') NOT NULL DEFAULT 'pending',
  payment_method VARCHAR(60) NOT NULL DEFAULT 'Pay at front desk',
  note           TEXT,
  staff_note     TEXT,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX (check_in), INDEX (check_out), INDEX (status),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (room_type_id) REFERENCES room_types(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE booking_addons (
  booking_id INT NOT NULL,
  addon_id   INT NOT NULL,
  name       VARCHAR(120) NOT NULL,     -- copied so old bookings keep their price
  price      DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (booking_id, addon_id),
  FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE reviews (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  user_id      INT NOT NULL,
  room_type_id INT NOT NULL,
  booking_id   INT NULL,
  rating       TINYINT NOT NULL,
  comment      TEXT,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (room_type_id) REFERENCES room_types(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE favorites (
  user_id      INT NOT NULL,
  room_type_id INT NOT NULL,
  PRIMARY KEY (user_id, room_type_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (room_type_id) REFERENCES room_types(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Days when the hotel takes no new check-ins (events, maintenance)
CREATE TABLE closed_dates (
  date   DATE PRIMARY KEY,
  reason VARCHAR(160) NOT NULL DEFAULT ''
) ENGINE=InnoDB;


-- ============================================================ DUMMY DATA

INSERT INTO users (id, name, email, phone, password_hash, role, staff_role, privileges, active, must_change_password, last_login_at, last_login_ip, password_changed_at, created_at) VALUES
(1, 'Tala Admin', 'admin@talahotel.ph', '0917 000 0000', '$2y$10$9KLce5yXMgArAexU3dOlc.6MXJpPF7d11/pgTNt4B3rgkLpiuy2vy', 'admin', 'Owner', '["bookings.view", "bookings.manage", "bookings.cancel", "guests.view", "rooms.manage", "calendar.manage", "reports.view", "staff.manage"]', 1, 1, DATE_SUB(NOW(), INTERVAL 1200 MINUTE), '192.168.1.10', DATE_SUB(NOW(), INTERVAL 400 DAY), DATE_SUB(NOW(), INTERVAL 400 DAY)),
(2, 'Juan Dela Cruz', 'juan.delacruz@gmail.com', '0917 482 1936', '$2y$10$hD5CDeqFVwGTsMjCCpOiROebqP5J/UMpz2ujpLh6hoZ4lc7FrdTEm', 'guest', NULL, NULL, 1, 0, DATE_SUB(NOW(), INTERVAL 2880 MINUTE), '112.198.4.20', DATE_SUB(NOW(), INTERVAL 210 DAY), DATE_SUB(NOW(), INTERVAL 210 DAY)),
(3, 'Ana Reyes', 'ana.reyes@gmail.com', '0918 552 7710', '$2y$10$0xLFtzkuIkyamzIzrOLZWewoJ86iaaFceezlOTqDNORfwWOIvU7W2', 'guest', NULL, NULL, 1, 0, DATE_SUB(NOW(), INTERVAL 360 MINUTE), '49.145.20.7', DATE_SUB(NOW(), INTERVAL 160 DAY), DATE_SUB(NOW(), INTERVAL 160 DAY)),
(4, 'Mark Santos', 'mark.santos@yahoo.com', '0927 113 4080', '$2y$10$JJesFzkhzjQsil9olQFCmebOUMskFqJfBV8U6aKXBr86DUmU3XNWu', 'guest', NULL, NULL, 1, 0, NULL, NULL, DATE_SUB(NOW(), INTERVAL 140 DAY), DATE_SUB(NOW(), INTERVAL 140 DAY)),
(5, 'Rica Lopez', 'rica.lopez@gmail.com', '0905 774 2391', '$2y$10$qK/qK9zjv.PLp.9DStZj7Oasg5n6SKpkb5kNrYWycvgQxHlknVydC', 'guest', NULL, NULL, 1, 0, NULL, NULL, DATE_SUB(NOW(), INTERVAL 95 DAY), DATE_SUB(NOW(), INTERVAL 95 DAY)),
(6, 'Paolo Garcia', 'paolo.garcia@outlook.com', '0919 640 1188', '$2y$10$deVI3mblHu9ckoflrUOwWeO2AxmLynsKtsbYyIXylW.QDfnWLDpSe', 'guest', NULL, NULL, 1, 0, NULL, NULL, DATE_SUB(NOW(), INTERVAL 60 DAY), DATE_SUB(NOW(), INTERVAL 60 DAY)),
(7, 'Liza Manalo', 'liza.manalo@gmail.com', '0936 208 5521', '$2y$10$eSVX9HKsC5DYRG0wDJrON.UJZATgxKKdVJNqOKuRm9oZr7Nn02P.i', 'guest', NULL, NULL, 1, 0, NULL, NULL, DATE_SUB(NOW(), INTERVAL 12 DAY), DATE_SUB(NOW(), INTERVAL 12 DAY)),
(8, 'Rafael Mendoza', 'manager@talahotel.ph', '0917 111 2020', '$2y$10$5Qth9ZaQO/D6foidlqkn7uplPwo5ScdXVy/InaH3A69zZdwvWMcba', 'admin', 'Manager', '["bookings.view", "bookings.manage", "bookings.cancel", "guests.view", "rooms.manage", "calendar.manage", "reports.view"]', 1, 1, DATE_SUB(NOW(), INTERVAL 300 MINUTE), '192.168.1.22', DATE_SUB(NOW(), INTERVAL 300 DAY), DATE_SUB(NOW(), INTERVAL 300 DAY)),
(9, 'Joy Fernandez', 'frontdesk@talahotel.ph', '0917 333 4545', '$2y$10$X9wS75zwCu641OdVDFx.xOjDQhfCMb40byUGoY0dzaPJddul0xfES', 'admin', 'Front desk', '["bookings.view", "bookings.manage", "guests.view"]', 1, 1, DATE_SUB(NOW(), INTERVAL 180 MINUTE), '192.168.1.31', DATE_SUB(NOW(), INTERVAL 200 DAY), DATE_SUB(NOW(), INTERVAL 200 DAY)),
(10, 'Ben Aquino', 'ben.aquino@talahotel.ph', '0917 555 6767', '$2y$10$q3PTlmyJRIK5bO9MLWUW7.ah3QNeXwz4yHXj2uCCjfC4gaSnYoduy', 'admin', 'Front desk', '["bookings.view", "bookings.manage", "guests.view"]', 0, 1, DATE_SUB(NOW(), INTERVAL 14400 MINUTE), '192.168.1.40', DATE_SUB(NOW(), INTERVAL 250 DAY), DATE_SUB(NOW(), INTERVAL 250 DAY));

INSERT INTO login_attempts (email, user_id, success, reason, portal, ip, user_agent, created_at) VALUES
('juan.delacruz@gmail.com', 2, 1, 'ok', 'guest', '112.198.4.20', 'Safari on iPhone', DATE_SUB(NOW(), INTERVAL 2880 MINUTE)),
('juan.delacruz@gmail.com', 2, 0, 'wrong_portal', 'staff', '112.198.4.20', 'Safari on iPhone', DATE_SUB(NOW(), INTERVAL 2820 MINUTE)),
('admin@tala.ph', NULL, 0, 'bad_password', 'staff', '203.177.12.8', 'Firefox on Linux', DATE_SUB(NOW(), INTERVAL 1800 MINUTE)),
('admin@tala.ph', NULL, 0, 'bad_password', 'staff', '203.177.12.8', 'Firefox on Linux', DATE_SUB(NOW(), INTERVAL 1800 MINUTE)),
('ben.aquino@talahotel.ph', 10, 0, 'disabled', 'staff', '192.168.1.40', 'Chrome on Windows', DATE_SUB(NOW(), INTERVAL 1560 MINUTE)),
('admin@talahotel.ph', 1, 1, 'ok', 'staff', '192.168.1.10', 'Chrome on Windows', DATE_SUB(NOW(), INTERVAL 1200 MINUTE)),
('ana.reyes@gmail.com', 3, 1, 'ok', 'guest', '49.145.20.7', 'Chrome on Android', DATE_SUB(NOW(), INTERVAL 360 MINUTE)),
('manager@talahotel.ph', 8, 1, 'ok', 'staff', '192.168.1.22', 'Chrome on Android', DATE_SUB(NOW(), INTERVAL 300 MINUTE)),
('frontdesk@talahotel.ph', 9, 0, 'bad_password', 'staff', '192.168.1.31', 'Edge on Windows', DATE_SUB(NOW(), INTERVAL 186 MINUTE)),
('frontdesk@talahotel.ph', 9, 0, 'bad_password', 'staff', '192.168.1.31', 'Edge on Windows', DATE_SUB(NOW(), INTERVAL 183 MINUTE)),
('frontdesk@talahotel.ph', 9, 1, 'ok', 'staff', '192.168.1.31', 'Edge on Windows', DATE_SUB(NOW(), INTERVAL 180 MINUTE));

INSERT INTO audit_log (user_id, user_name, action, details, ip, created_at) VALUES
(8, 'Rafael Mendoza', 'room.update', 'Deluxe King · price ₱3,450', '192.168.1.10', DATE_SUB(NOW(), INTERVAL 50 HOUR)),
(8, 'Rafael Mendoza', 'calendar.close', 'Closed a day · Private event — hotel buy-out', '192.168.1.10', DATE_SUB(NOW(), INTERVAL 40 HOUR)),
(1, 'Tala Admin', 'staff.update', 'Disabled Ben Aquino', '192.168.1.10', DATE_SUB(NOW(), INTERVAL 26 HOUR)),
(9, 'Joy Fernandez', 'booking.check_in', 'TL-1006 · Mark Santos', '192.168.1.10', DATE_SUB(NOW(), INTERVAL 24 HOUR)),
(9, 'Joy Fernandez', 'booking.check_in', 'TL-1015 · Paolo Garcia', '192.168.1.10', DATE_SUB(NOW(), INTERVAL 23 HOUR)),
(9, 'Joy Fernandez', 'booking.check_in', 'TL-1007 · Rica Lopez', '192.168.1.10', DATE_SUB(NOW(), INTERVAL 22 HOUR)),
(9, 'Joy Fernandez', 'booking.confirm', 'TL-1014 · Liza Manalo', '192.168.1.10', DATE_SUB(NOW(), INTERVAL 4 HOUR));

INSERT INTO room_types (id, name, category, description, price, capacity, size_sqm, beds, units, popular, visible, images, amenities) VALUES
(1, 'Standard Queen', 'Standard', 'A calm, compact room with a plush queen bed, rain shower and a work desk by the window. Ideal for solo travellers and couples.', 2450.00, 2, 22, '1 Queen bed', 8, 0, 1, '["https://images.unsplash.com/photo-1631049307264-da0ec9d70304?fm=jpg&q=70&w=1000&fit=crop", "https://images.unsplash.com/photo-1629140727571-9b5c6f6267b4?fm=jpg&q=70&w=1000&fit=crop", "https://images.unsplash.com/photo-1631049552057-403cdb8f0658?fm=jpg&q=70&w=1000&fit=crop"]', '["Free Wi-Fi", "Air-conditioning", "Smart TV", "Rain shower", "Work desk"]'),
(2, 'Deluxe King', 'Deluxe', 'Our most-booked room: a king bed, floor-to-ceiling windows with a city view, a lounge chair and a minibar.', 3450.00, 2, 28, '1 King bed', 6, 1, 1, '["https://images.unsplash.com/photo-1618773928121-c32242e63f39?fm=jpg&q=70&w=1000&fit=crop", "https://images.unsplash.com/photo-1781572725438-ac8c41476752?fm=jpg&q=70&w=1000&fit=crop", "https://images.unsplash.com/photo-1765423587693-afd93c579a2d?fm=jpg&q=70&w=1000&fit=crop"]', '["Free Wi-Fi", "City view", "Minibar", "Smart TV", "Coffee maker", "Bathtub"]'),
(3, 'Deluxe Twin', 'Deluxe', 'Two double beds for friends or small families, with extra wardrobe space and a sitting nook.', 3200.00, 3, 26, '2 Double beds', 5, 0, 1, '["https://images.unsplash.com/photo-1611892440504-42a792e24d32?fm=jpg&q=70&w=1000&fit=crop", "https://images.unsplash.com/photo-1711059985570-4c32ed12a12c?fm=jpg&q=70&w=1000&fit=crop", "https://images.unsplash.com/photo-1562438668-bcf0ca6578f0?fm=jpg&q=70&w=1000&fit=crop"]', '["Free Wi-Fi", "Air-conditioning", "Smart TV", "Minibar", "Sofa nook"]'),
(4, 'Family Room', 'Deluxe', 'Room for everyone: a king bed plus a bunk nook, a dining corner and a larger bathroom with tub.', 5200.00, 4, 40, '1 King + 1 Bunk bed', 4, 0, 1, '["https://images.unsplash.com/photo-1578683010236-d716f9a3f461?fm=jpg&q=70&w=1000&fit=crop", "https://images.unsplash.com/photo-1583847268964-b28dc8f51f92?fm=jpg&q=70&w=1000&fit=crop", "https://images.unsplash.com/photo-1765547090903-348b711f0eee?fm=jpg&q=70&w=1000&fit=crop"]', '["Free Wi-Fi", "Bathtub", "Dining corner", "Smart TV", "Microwave", "Kids'' kit"]'),
(5, 'Executive Suite', 'Suite', 'A separate living room, king bedroom and a deep soaking tub, plus Executive Lounge access and evening canapés.', 7800.00, 3, 55, '1 King bed + Sofa bed', 2, 1, 1, '["https://images.unsplash.com/photo-1778205015308-1ed324aea202?fm=jpg&q=70&w=1000&fit=crop", "https://images.unsplash.com/photo-1768144092684-c1a5dd6c7aad?fm=jpg&q=70&w=1000&fit=crop", "https://images.unsplash.com/photo-1564078516393-cf04bd966897?fm=jpg&q=70&w=1000&fit=crop"]', '["Lounge access", "Living room", "Soaking tub", "Nespresso", "Bathrobes", "City view"]'),
(6, 'Sky Loft Suite', 'Suite', 'Our top-floor two-level loft with a private terrace, panoramic sunset view over the river and a butler on call.', 12500.00, 4, 80, '1 King + 2 Single beds', 1, 0, 1, '["https://images.unsplash.com/photo-1761602866012-ae9f888255dc?fm=jpg&q=70&w=1000&fit=crop", "https://images.unsplash.com/photo-1761971976519-7e27a35c9c49?fm=jpg&q=70&w=1000&fit=crop", "https://images.unsplash.com/photo-1590381105924-c72589b9ef3f?fm=jpg&q=70&w=1000&fit=crop"]', '["Private terrace", "Butler on call", "Panoramic view", "Bathtub", "Kitchenette", "Lounge access"]');

INSERT INTO addons (id, name, description, price, image, active) VALUES
(1, 'Breakfast for two', 'Daily buffet at Kusina, 6:00–10:00 AM', 650.00, 'https://images.unsplash.com/photo-1596701062351-8c2c14d1fdd0?fm=jpg&q=70&w=1000&fit=crop', 1),
(2, 'Airport / terminal pickup', 'Private car from the airport or bus terminal', 800.00, 'https://images.unsplash.com/photo-1772468237159-674f05233185?fm=jpg&q=70&w=1000&fit=crop', 1),
(3, '60-min spa massage', 'Hilot or Swedish at the Tala Spa', 1200.00, 'https://images.unsplash.com/photo-1600334089648-b0d9d3028eb2?fm=jpg&q=70&w=1000&fit=crop', 1),
(4, 'Late checkout (4 PM)', 'Keep your room until 4:00 PM', 600.00, 'https://images.unsplash.com/photo-1759328257280-28bdb3050be3?fm=jpg&q=70&w=1000&fit=crop', 1),
(5, 'Extra bed', 'Rollaway bed with linens', 900.00, 'https://images.unsplash.com/photo-1631049552057-403cdb8f0658?fm=jpg&q=70&w=1000&fit=crop', 1),
(6, 'Romantic setup', 'Petals, cake and a bottle of wine on arrival', 1500.00, 'https://images.unsplash.com/photo-1620733723572-11c53f73a416?fm=jpg&q=70&w=1000&fit=crop', 1);

INSERT INTO bookings (id, code, user_id, room_type_id, check_in, check_out, guests, nights, room_total, addons_total, total, status, payment_method, note, staff_note, created_at, updated_at) VALUES
(1, 'TL-1001', 2, 2, DATE_ADD(CURDATE(), INTERVAL 5 DAY), DATE_ADD(CURDATE(), INTERVAL 7 DAY), 2, 2, 6900.00, 650.00, 7550.00, 'confirmed', 'Pay at front desk', 'Celebrating our anniversary — a high floor please.', '', DATE_SUB(NOW(), INTERVAL 3 DAY), DATE_SUB(NOW(), INTERVAL 2 DAY)),
(2, 'TL-1002', 2, 4, DATE_ADD(CURDATE(), INTERVAL 12 DAY), DATE_ADD(CURDATE(), INTERVAL 15 DAY), 4, 3, 15600.00, 800.00, 16400.00, 'pending', 'GCash at check-in', 'Arriving by bus around 3 PM.', '', DATE_SUB(NOW(), INTERVAL 1 DAY), DATE_SUB(NOW(), INTERVAL 0 DAY)),
(3, 'TL-1003', 2, 1, DATE_ADD(CURDATE(), INTERVAL -20 DAY), DATE_ADD(CURDATE(), INTERVAL -19 DAY), 2, 1, 2450.00, 0.00, 2450.00, 'checked_out', 'Pay at front desk', '', 'Quiet guests, left room tidy.', DATE_SUB(NOW(), INTERVAL 25 DAY), DATE_SUB(NOW(), INTERVAL 24 DAY)),
(4, 'TL-1004', 2, 3, DATE_ADD(CURDATE(), INTERVAL -45 DAY), DATE_ADD(CURDATE(), INTERVAL -43 DAY), 3, 2, 6400.00, 0.00, 6400.00, 'cancelled', 'Pay at front desk', '', 'Guest cancelled by phone.', DATE_SUB(NOW(), INTERVAL 50 DAY), DATE_SUB(NOW(), INTERVAL 49 DAY)),
(5, 'TL-1005', 3, 5, DATE_ADD(CURDATE(), INTERVAL 0 DAY), DATE_ADD(CURDATE(), INTERVAL 2 DAY), 2, 2, 15600.00, 1850.00, 17450.00, 'confirmed', 'Card at front desk', 'Allergic to feather pillows.', 'Swap to foam pillows.', DATE_SUB(NOW(), INTERVAL 9 DAY), DATE_SUB(NOW(), INTERVAL 8 DAY)),
(6, 'TL-1006', 4, 2, DATE_ADD(CURDATE(), INTERVAL -1 DAY), DATE_ADD(CURDATE(), INTERVAL 2 DAY), 2, 3, 10350.00, 0.00, 10350.00, 'checked_in', 'Pay at front desk', '', 'Requested extra towels.', DATE_SUB(NOW(), INTERVAL 6 DAY), DATE_SUB(NOW(), INTERVAL 5 DAY)),
(7, 'TL-1007', 5, 1, DATE_ADD(CURDATE(), INTERVAL -2 DAY), DATE_ADD(CURDATE(), INTERVAL 0 DAY), 1, 2, 4900.00, 600.00, 5500.00, 'checked_in', 'GCash at check-in', 'Business trip, need early breakfast.', '', DATE_SUB(NOW(), INTERVAL 8 DAY), DATE_SUB(NOW(), INTERVAL 7 DAY)),
(8, 'TL-1008', 6, 3, DATE_ADD(CURDATE(), INTERVAL 1 DAY), DATE_ADD(CURDATE(), INTERVAL 3 DAY), 3, 2, 6400.00, 0.00, 6400.00, 'pending', 'Pay at front desk', '', '', DATE_SUB(NOW(), INTERVAL 0 DAY), DATE_SUB(NOW(), INTERVAL 0 DAY)),
(9, 'TL-1009', 7, 6, DATE_ADD(CURDATE(), INTERVAL 3 DAY), DATE_ADD(CURDATE(), INTERVAL 5 DAY), 4, 2, 25000.00, 2150.00, 27150.00, 'pending', 'Card at front desk', 'Surprise birthday for my mom!', '', DATE_SUB(NOW(), INTERVAL 0 DAY), DATE_SUB(NOW(), INTERVAL 0 DAY)),
(10, 'TL-1010', 4, 4, DATE_ADD(CURDATE(), INTERVAL -30 DAY), DATE_ADD(CURDATE(), INTERVAL -28 DAY), 4, 2, 10400.00, 900.00, 11300.00, 'checked_out', 'Pay at front desk', '', '', DATE_SUB(NOW(), INTERVAL 40 DAY), DATE_SUB(NOW(), INTERVAL 39 DAY)),
(11, 'TL-1011', 3, 2, DATE_ADD(CURDATE(), INTERVAL 0 DAY), DATE_ADD(CURDATE(), INTERVAL 1 DAY), 2, 1, 3450.00, 0.00, 3450.00, 'pending', 'GCash at check-in', 'Can we check in early, around noon?', '', DATE_SUB(NOW(), INTERVAL 0 DAY), DATE_SUB(NOW(), INTERVAL 0 DAY)),
(12, 'TL-1012', 6, 1, DATE_ADD(CURDATE(), INTERVAL -10 DAY), DATE_ADD(CURDATE(), INTERVAL -7 DAY), 2, 3, 7350.00, 650.00, 8000.00, 'checked_out', 'Pay at front desk', '', '', DATE_SUB(NOW(), INTERVAL 15 DAY), DATE_SUB(NOW(), INTERVAL 14 DAY)),
(13, 'TL-1013', 5, 5, DATE_ADD(CURDATE(), INTERVAL 7 DAY), DATE_ADD(CURDATE(), INTERVAL 9 DAY), 2, 2, 15600.00, 800.00, 16400.00, 'confirmed', 'Card at front desk', '', '', DATE_SUB(NOW(), INTERVAL 4 DAY), DATE_SUB(NOW(), INTERVAL 3 DAY)),
(14, 'TL-1014', 7, 1, DATE_ADD(CURDATE(), INTERVAL 0 DAY), DATE_ADD(CURDATE(), INTERVAL 2 DAY), 2, 2, 4900.00, 0.00, 4900.00, 'confirmed', 'Pay at front desk', '', '', DATE_SUB(NOW(), INTERVAL 5 DAY), DATE_SUB(NOW(), INTERVAL 4 DAY)),
(15, 'TL-1015', 6, 5, DATE_ADD(CURDATE(), INTERVAL -1 DAY), DATE_ADD(CURDATE(), INTERVAL 1 DAY), 3, 2, 15600.00, 1200.00, 16800.00, 'checked_in', 'Card at front desk', '', 'VIP — welcome amenity sent.', DATE_SUB(NOW(), INTERVAL 11 DAY), DATE_SUB(NOW(), INTERVAL 10 DAY));

INSERT INTO booking_addons (booking_id, addon_id, name, price) VALUES
(1, 1, 'Breakfast for two', 650.00),
(2, 2, 'Airport / terminal pickup', 800.00),
(5, 1, 'Breakfast for two', 650.00),
(5, 3, '60-min spa massage', 1200.00),
(7, 4, 'Late checkout (4 PM)', 600.00),
(9, 6, 'Romantic setup', 1500.00),
(9, 1, 'Breakfast for two', 650.00),
(10, 5, 'Extra bed', 900.00),
(12, 1, 'Breakfast for two', 650.00),
(13, 2, 'Airport / terminal pickup', 800.00),
(15, 3, '60-min spa massage', 1200.00);

INSERT INTO reviews (id, user_id, room_type_id, booking_id, rating, comment, created_at) VALUES
(1, 2, 1, 3, 5, 'Spotless room and the quickest check-in I''ve had.', DATE_SUB(NOW(), INTERVAL 19 DAY)),
(2, 4, 4, 10, 4, 'Kids loved the bunk nook. Breakfast could be earlier.', DATE_SUB(NOW(), INTERVAL 28 DAY)),
(3, 6, 1, 12, 4, 'Great value. Shower pressure is excellent.', DATE_SUB(NOW(), INTERVAL 7 DAY)),
(4, 3, 2, NULL, 5, 'The city view at night is beautiful. Bed was super comfy.', DATE_SUB(NOW(), INTERVAL 60 DAY)),
(5, 5, 5, NULL, 5, 'Lounge canapés were a treat. Worth every peso.', DATE_SUB(NOW(), INTERVAL 45 DAY)),
(6, 7, 2, NULL, 4, 'Lovely room, a bit of street noise on weekends.', DATE_SUB(NOW(), INTERVAL 30 DAY)),
(7, 4, 6, NULL, 5, 'The terrace sunset is unreal. Butler service was spot on.', DATE_SUB(NOW(), INTERVAL 90 DAY)),
(8, 5, 3, NULL, 4, 'Roomy for three people. Good Wi-Fi.', DATE_SUB(NOW(), INTERVAL 50 DAY));

INSERT INTO favorites (user_id, room_type_id) VALUES (2, 2), (2, 5), (3, 6);

INSERT INTO closed_dates (date, reason) VALUES
(DATE_ADD(CURDATE(), INTERVAL 21 DAY), 'Private event — hotel buy-out');
