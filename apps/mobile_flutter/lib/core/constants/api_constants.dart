class ApiConstants {
  // Use localhost for Chrome/Web testing
  static const String baseUrl = 'http://localhost:3000';
  
  // Auth endpoints
  static const String register = '$baseUrl/auth/register';
  static const String login = '$baseUrl/auth/login';
  static const String refresh = '$baseUrl/auth/refresh';
  static const String logout = '$baseUrl/auth/logout';
  
  // User endpoints
  static const String userMe = '$baseUrl/users/me';
  
  // Circles endpoints
  static const String circles = '$baseUrl/circles';
  static String circleById(int id) => '$baseUrl/circles/$id';
  static String circleInvite(int id) => '$baseUrl/circles/$id/invite';
  static const String circleJoin = '$baseUrl/circles/join';
  
  // Messages endpoints
  static String circleMessages(int circleId) => '$baseUrl/circles/$circleId/messages';
  
  // Uploads
  static const String uploadRequest = '$baseUrl/uploads/request';
  
  // WebSocket
  static const String socketUrl = 'http://localhost:3000';
}