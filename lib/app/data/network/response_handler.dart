// import 'network_exception.dart';
// import 'package:http/http.dart' as http;
//
// dynamic handleResponse(http.Response response) {
//   final statusCode = response.statusCode;
//   final body = response.body;
//
//   if (statusCode >= 200 && statusCode < 300) {
//     return body;
//   } else if (statusCode == 401) {
//     throw UnauthorizedException('Session expired');
//   } else if (statusCode >= 500) {
//     throw ServerException('Server error: $statusCode');
//   } else {
//     throw NetworkException('Request failed with status: $statusCode');
//   }
// }
