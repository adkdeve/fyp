import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../../../utils/dialogs/internet_connectivity_dialog.dart';
import '../../../utils/dialogs/session_expired.dart';
import 'base_api_services.dart';
import 'dart:io';

class NetworkApiService extends BaseApiServices {

  //========== First Flow ==============
  @override
  Future postApiResponse(data, url) async {
    try {
      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult != ConnectivityResult.none) {
        var response = await http
            .post(Uri.parse(url), body: data)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          // var data = Encryption.instance.decrypt(response.body.toString());
          // print(data);
          return response.body;
        }
      } else {
        internetConnectivityAlterDialog();
        return null;
      }
    } on SocketException {
      throw 'Something went wrong';
    }
  }

  @override
  Future postApiResponseWithToken(data, url, token) async {
    try {
      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult != ConnectivityResult.none) {
        var response =
        await http.post(Uri.parse(url), body: jsonEncode(data), headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        }).timeout(
          const Duration(seconds: 15),
        );
        // if (response.statusCode == 200) {
        // var data = Encryption.instance.decrypt(response.body.toString());
        // print(data);
        return response.body;
        // }else{

        // }
      } else {
        internetConnectivityAlterDialog();
        return null;
      }
    } on SocketException {
      throw 'Something went wrong';
    }
  }

  //========== Second Flow ==============
  @override
  Future getApiResponseWithToken(url, token) async {
    try {
      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult != ConnectivityResult.none) {
        var response = await http.get(Uri.parse(url), headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        }).timeout(
          const Duration(seconds: 15),
        );
        // var data = Encryption.instance.decrypt(response.body.toString());
        // print(response.body);
        if (response.statusCode == 401) {
          sectionExpired(jsonDecode(response.body.toString()));
          print(response.body);
          return null;
        } else {
          return response.body;
        }
      } else {
        internetConnectivityAlterDialog();
        return null;
      }
    } on SocketException {
      throw 'Something went wrong';
    }
  }

  //========== Update Profile  ==============
  @override
  Future postApiResponseProfile(data, url, token) async {
    try {
      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult != ConnectivityResult.none) {
        if (data['image'].toString().isEmpty) {
          final finalData = jsonEncode(data);
          var response = await http
              .post(Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: finalData)
              .timeout(
            const Duration(seconds: 15),
          );
          if (response.statusCode == 401) {
            sectionExpired(jsonDecode(response.body.toString()));
            return null;
          } else {
            return response.body;
          }
        } else {
          var request = http.MultipartRequest("POST", Uri.parse(url));

          File file = File(data["image"]);
          var length = await file.length();
          var stream = http.ByteStream(file.openRead());
          var multiform =
          http.MultipartFile('image', stream, length, filename: file.path);

          request.files.add(multiform);
          request.headers.addAll({
            "Accept": "application/json",
            "Authorization": "Bearer $token",
          });

          request.fields.addAll({
            "first_name": data['first_name'],
            'last_name': data['last_name'],
            "interests": data['interests']??'',
            'country': data['country'],
            'city': data['city'],
            'mother_of': data['mother_of'],
            'age': data['age'],
            'image': data['image']
          });

          var response = await request.send();
          if (response.statusCode == 401) {
            sectionExpired(jsonDecode(await response.stream.bytesToString()));
            return null;
          } else {
            // print(await response.stream.bytesToString());
            return await response.stream.bytesToString();
          }
        }
      } else {
        internetConnectivityAlterDialog();
        return null;
      }
    } on SocketException {
      throw 'Something went wrong';
    }
  }

  @override
  Future deleteApiWithToken(url, token) async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult != ConnectivityResult.none) {
        final response = await http.delete(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 401) {
          sectionExpired(jsonDecode(response.body));
          return null;
        }

        return response.body;
      } else {
        internetConnectivityAlterDialog();
        return null;
      }
    } catch (e) {
      throw 'Delete request failed: $e';
    }
  }

  @override
  Future uploadResumeFile(File file, String url, String token) async {
    try {
      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult != ConnectivityResult.none) {
        var request = http.MultipartRequest('POST', Uri.parse(url));

        // Add the file
        var fileStream = http.ByteStream(Stream.castFrom(file.openRead()));
        var length = await file.length();
        var multipartFile = http.MultipartFile('resume', fileStream, length, filename: file.path.split('/').last);
        request.files.add(multipartFile);

        // Add headers
        request.headers.addAll({
          'Authorization': 'Bearer $token',
        });

        var response = await request.send();
        var responseData = await response.stream.bytesToString();

        if (response.statusCode == 200) {
          return responseData;
        } else {
          // Handle error
          return null;
        }
      } else {
        internetConnectivityAlterDialog();
        return null;
      }
    } on SocketException {
      throw 'Something went wrong';
    }
  }


}
