// Tests for Tala Hotel's booking + security rules, run against the offline demo database.
// Run with:  flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tala_hotel/data/local_repository.dart';
import 'package:tala_hotel/models.dart';
import 'package:tala_hotel/utils/format.dart';

void main() {
  late SharedPreferences prefs;
  late LocalRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = LocalRepository(prefs);
  });

  Future<AppUser> guest() => repo.login('juan.delacruz@gmail.com', 'password123');
  Future<AppUser> owner() => repo.login('admin@talahotel.ph', 'admin123');
  Future<AppUser> frontDesk() => repo.login('frontdesk@talahotel.ph', 'desk1234');

  test('peso formatting', () {
    expect(peso(3450), '₱3,450');
    expect(peso(12500), '₱12,500');
  });

  test('demo login works, wrong password is rejected', () async {
    final u = await guest();
    expect(u.name, 'Juan Dela Cruz');
    expect(u.isAdmin, isFalse);
    expect(u.token, isNotNull);
    await expectLater(repo.login('juan.delacruz@gmail.com', 'wrong'), throwsA(isA<AppException>()));
  });

  test('passwords are stored hashed, never in plain text', () async {
    final stored = prefs.getString('tala_demo_db_v2')!;
    expect(stored.contains('password123'), isFalse);
    expect(stored.contains('admin123'), isFalse);
  });

  test('one login page: the account decides guest app or staff dashboard', () async {
    final g = await guest();
    expect(g.isAdmin, isFalse);
    final o = await owner();
    expect(o.isOwner, isTrue);
    expect(o.can(Priv.staffManage), isTrue);
    final f = await frontDesk();
    expect(f.isAdmin, isTrue);
    expect(f.can(Priv.staffManage), isFalse);
  });

  test('disabled staff accounts cannot sign in', () async {
    await expectLater(repo.login('ben.aquino@talahotel.ph', 'desk1234'), throwsA(isA<AppException>()));
  });

  test('5 wrong passwords lock the account', () async {
    for (var i = 0; i < 5; i++) {
      await expectLater(repo.login('manager@talahotel.ph', 'nope'), throwsA(isA<AppException>()));
    }
    // even the right password is refused while locked
    await expectLater(repo.login('manager@talahotel.ph', 'manager123'), throwsA(isA<AppException>()));
  });

  test('guest can book a free room and the price is correct', () async {
    await guest();
    final b = await repo.createBooking(BookingRequest(
      roomTypeId: 2, // Deluxe King, ₱3,450 / night
      guests: 2,
      checkIn: addDays(today(), 2),
      checkOut: addDays(today(), 4),
      addonIds: [1], // Breakfast for two, ₱650
      paymentMethod: 'Pay at front desk',
      note: '',
    ));
    expect(b.status, BookingStatus.pending);
    expect(b.nights, 2);
    expect(b.total, 3450 * 2 + 650);
  });

  test('a fully booked room cannot be booked', () async {
    await guest();
    // Executive Suite has 2 rooms and both are taken tonight in the dummy data.
    await expectLater(
      repo.createBooking(BookingRequest(
        roomTypeId: 5, guests: 2, checkIn: today(), checkOut: addDays(today(), 1),
        addonIds: const [], paymentMethod: 'Pay at front desk', note: '',
      )),
      throwsA(isA<AppException>()),
    );
  });

  test('closed days block check-in', () async {
    await guest();
    await expectLater(
      repo.createBooking(BookingRequest(
        roomTypeId: 1, guests: 1, checkIn: addDays(today(), 21), checkOut: addDays(today(), 22),
        addonIds: const [], paymentMethod: 'Pay at front desk', note: '',
      )),
      throwsA(isA<AppException>()),
    );
  });

  test('guests cannot confirm bookings, the front desk can', () async {
    await guest();
    await expectLater(repo.updateBooking(2, status: BookingStatus.confirmed), throwsA(isA<AppException>()));

    await frontDesk();
    final b = await repo.updateBooking(2, status: BookingStatus.confirmed);
    expect(b.status, BookingStatus.confirmed);
  });

  test('front desk privileges stop at rooms and staff', () async {
    await frontDesk();
    final rooms = await repo.rooms();
    await expectLater(repo.saveRoom(rooms.first), throwsA(isA<AppException>()));
    await expectLater(repo.staff(), throwsA(isA<AppException>()));
  });

  test('owner can restrict a staff member and every change is audited', () async {
    await owner();
    await repo.saveStaff(const StaffDraft(
      id: 9, name: 'Joy Fernandez', email: 'frontdesk@talahotel.ph', phone: '',
      staffRole: 'Custom', privileges: [Priv.bookingsView], active: true,
    ));
    final log = await repo.auditLog();
    expect(log.first.action, 'staff.update');

    await frontDesk();
    // Joy can still view, but no longer confirm
    await repo.bookings();
    await expectLater(repo.updateBooking(8, status: BookingStatus.confirmed), throwsA(isA<AppException>()));
  });

  test('logging out ends the session', () async {
    await guest();
    await repo.logout();
    await expectLater(repo.bookings(), throwsA(isA<AppException>()));
  });
}
