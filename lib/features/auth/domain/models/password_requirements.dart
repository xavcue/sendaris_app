class PasswordRequirements {
  const PasswordRequirements({
    required this.hasMinimumLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSpecialCharacter,
  });

  static const int minimumLength = 12;

  static const Set<String> allowedSpecialCharacters = {
    '^',
    r'$',
    '*',
    '.',
    '[',
    ']',
    '{',
    '}',
    '(',
    ')',
    '?',
    '"',
    '!',
    '@',
    '#',
    '%',
    '&',
    '/',
    r'\',
    ',',
    '>',
    '<',
    "'",
    ':',
    ';',
    '|',
    '_',
    '~',
  };

  final bool hasMinimumLength;

  final bool hasUppercase;

  final bool hasLowercase;

  final bool hasNumber;

  final bool hasSpecialCharacter;

  bool get isValid {
    return hasMinimumLength &&
        hasUppercase &&
        hasLowercase &&
        hasNumber &&
        hasSpecialCharacter;
  }

  int get fulfilledCount {
    var count = 0;

    if (hasMinimumLength) {
      count++;
    }

    if (hasUppercase) {
      count++;
    }

    if (hasLowercase) {
      count++;
    }

    if (hasNumber) {
      count++;
    }

    if (hasSpecialCharacter) {
      count++;
    }

    return count;
  }

  static PasswordRequirements evaluate(String password) {
    return PasswordRequirements(
      hasMinimumLength: password.length >= minimumLength,
      hasUppercase: RegExp(r'[A-Z]').hasMatch(password),
      hasLowercase: RegExp(r'[a-z]').hasMatch(password),
      hasNumber: RegExp(r'[0-9]').hasMatch(password),
      hasSpecialCharacter: password
          .split('')
          .any(allowedSpecialCharacters.contains),
    );
  }
}
