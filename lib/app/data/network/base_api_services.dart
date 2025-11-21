import 'dart:io';

abstract class BaseApiServices {
  Future<dynamic> postApiResponse(dynamic data, String url);
  Future<dynamic> postApiResponseWithToken(Map<String, dynamic> data, String url,String token);
  Future<dynamic> getApiResponseWithToken(String url,String token);
  Future<dynamic> deleteApiWithToken(String url,String token);
  //========== Update Profile  ==============
  Future<dynamic> postApiResponseProfile(Map<String, dynamic> data, String url,String token);
  Future<dynamic> uploadResumeFile(File file, String url, String token);

}
