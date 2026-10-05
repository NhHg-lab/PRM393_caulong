import 'package:courtly/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.identifier', () {
    test('rejects empty input', () {
      expect(Validators.identifier(''), isNotNull);
      expect(Validators.identifier('   '), isNotNull);
    });

    test('validates email format when input contains @', () {
      expect(Validators.identifier('demo@courtly.vn'), isNull);
      expect(Validators.identifier('demo@courtly'), isNotNull);
      expect(Validators.identifier('demo@@courtly.vn'), isNotNull);
    });

    test('validates Vietnamese phone numbers with 9 to 11 digits', () {
      expect(Validators.identifier('0912345678'), isNull);
      expect(Validators.identifier('091 234 5678'), isNull);
      expect(Validators.identifier('+84912345678'), isNull);
      expect(Validators.identifier('12345678'), isNotNull);
      expect(Validators.identifier('091234567890'), isNotNull);
      expect(Validators.identifier('abc'), isNotNull);
    });

    test('accepts usernames only when allowed (DummyJSON)', () {
      expect(Validators.identifier('emilys'), isNotNull);
      expect(Validators.identifier('emilys', allowUsername: true), isNull);
    });
  });

  test('loginPassword requires at least 6 characters', () {
    expect(Validators.loginPassword(''), isNotNull);
    expect(Validators.loginPassword('12345'), isNotNull);
    expect(Validators.loginPassword('123456'), isNull);
  });

  test('signupPassword enforces the password policy', () {
    expect(Validators.signupPassword('Abc1234'), isNotNull, reason: '< 8');
    expect(Validators.signupPassword('abcd1234'), isNotNull, reason: 'upper');
    expect(Validators.signupPassword('Abcdefgh'), isNotNull, reason: 'digit');
    expect(Validators.signupPassword(' Abcd1234'), isNotNull, reason: 'space');
    expect(Validators.signupPassword('Abcd1234 '), isNotNull, reason: 'space');
    expect(Validators.signupPassword('Abcd1234'), isNull);
  });

  test('confirmPassword must match', () {
    expect(Validators.confirmPassword('Abcd1234', 'Abcd1234'), isNull);
    expect(Validators.confirmPassword('Abcd1235', 'Abcd1234'), isNotNull);
    expect(Validators.confirmPassword('', 'Abcd1234'), isNotNull);
  });

  test('fullName rejects empty, too short and digits', () {
    expect(Validators.fullName('Nguyễn Văn An'), isNull);
    expect(Validators.fullName(''), isNotNull);
    expect(Validators.fullName('A'), isNotNull);
    expect(Validators.fullName('An 123'), isNotNull);
  });

  test('optionalPhone allows empty but validates when present', () {
    expect(Validators.optionalPhone(''), isNull);
    expect(Validators.optionalPhone('0912345678'), isNull);
    expect(Validators.optionalPhone('09'), isNotNull);
  });
}
