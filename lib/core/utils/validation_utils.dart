class ValidationUtils {
  // Checks if the given text is empty.
  static bool isEmpty(String text) {
    return text.isEmpty; // Check if the string is empty or null
  }

  // Validates if the given email is in a valid format.
  static bool isValidEmail(String email) {
    // Regular expression for email validation
    final emailPattern = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$";
    final regex = RegExp(emailPattern);
    return regex.hasMatch(email);
  }

  // Checks if the given email and confirmEmail are the same.
  static bool areEmailsMatching(String email, String confirmEmail) {
    return email == confirmEmail;
  }

  // Checks if the given password and confirmPassword are the same.
  static bool arePasswordsMatching(String password, String confirmPassword) {
    return password == confirmPassword;
  }

  // Validates if the given password meets the minimum length requirement.
  // Password must be at least 6 characters long.
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  // Validates if the given full name is in a valid format.
  // Full name should contain at least two words, each with only alphabetic characters.
  static bool isValidFullName(String fullName) {
    final regex = RegExp(r"^[a-zA-Z][a-zA-Z'\- ]{1,}$");
    return regex.hasMatch(fullName.trim());
  }

  static bool isValidPhone(String phone) {
    final regex = RegExp(r'^(\+?\d{1,4}[-\s]?)?(\d{10})$');
    return regex.hasMatch(phone.trim());
  }

  static String? getPasswordError(String password) {
    if (password.isEmpty) return "Please enter password";

    if (password.length < 8) {
      return "Use at least 8 characters";
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return "Must include at least one uppercase letter";
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return "Must include at least one lowercase letter";
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return "Must include at least one number";
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return "Must include at least one symbol (!@# etc.)";
    }

    return null;
  }

}



class ValidationErrors {
  // Email validation
  static const String ERROR_ENTER_EMAIL = "Please enter Email";
  static const String ERROR_ENTER_PHONE = "Please enter Phone";
  static const String ERROR_INVALID_PHONE = "Please enter correct Phone";
  static const String ERROR_INVALID_EMAIL = "Please enter correct email";

  // Confirm email validation
  static const String ERROR_ENTER_CONFIRM_EMAIL = "Please enter Confirm Email";
  static const String ERROR_EMAIL_CONFIRM_MISMATCH = "Email and Confirm Email are not the same";

  // Password validation
  static const String ERROR_PASSWORD_MISMATCH = "Password and Confirm Password are not the same";
  static const String ERROR_PASSWORD_LENGTH = "Password must be at least 8 characters";
  static const String ERROR_ENTER_PASSWORD = "Please enter Password";
  static const String ERROR_ENTER_CONFIRM_PASSWORD = "Please enter Confirm Password";

  // Full name validation
  static const String ERROR_ENTER_FULL_NAME = "Please enter Full Name";
  static const String ERROR_INVALID_FULL_NAME = "Please enter correct Full Name";
}