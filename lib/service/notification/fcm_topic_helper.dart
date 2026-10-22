/// Firebase Cloud Messaging topic names used for admin broadcast pushes.
///
/// The app subscribes the device to topics matching the logged-in user type
/// so the backend (Firebase Admin SDK) can send with:
///   admin.messaging().send({ topic: 'external', ... })
class FcmTopicHelper {
  FcmTopicHelper._();

  static const String allUsers = 'all_users';

  /// Normalizes user type to a valid FCM topic segment.
  static String? topicForUserType(String userType) {
    final normalized = userType.trim().toLowerCase();
    switch (normalized) {
      case 'external':
      case 'vip':
      case 'vvip':
      case 'admin':
      case 'internal':
        return normalized;
      default:
        return null;
    }
  }

  static List<String> topicsForUserType(String userType) {
    final topics = <String>[allUsers];
    final roleTopic = topicForUserType(userType);
    if (roleTopic != null) topics.add(roleTopic);
    return topics;
  }
}
