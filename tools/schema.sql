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
