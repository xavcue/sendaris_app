abstract final class EmailIdentityNormalizer {
  static String normalize(String email) {
    final trimmedEmail = email.trim();

    final firstAtIndex = trimmedEmail.indexOf('@');
    final lastAtIndex = trimmedEmail.lastIndexOf('@');

    if (firstAtIndex <= 0 ||
        firstAtIndex != lastAtIndex ||
        firstAtIndex == trimmedEmail.length - 1) {
      return trimmedEmail;
    }

    final localPart = trimmedEmail.substring(0, firstAtIndex);

    final domain = trimmedEmail.substring(firstAtIndex + 1).toLowerCase();

    return '$localPart@$domain';
  }
}
