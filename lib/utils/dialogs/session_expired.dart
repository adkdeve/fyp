import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../app/core/resources/resources.dart';
import '../helpers/snackbar.dart';

void sectionExpired(var responce) {
  if (!responce['success'] && responce['code'] == 1) {
    // logoutUser();
    SnackBarUtils.showError(responce['message'][0]);
  }
}

Future<dynamic> sectionExpireDialog() {
  return Get.defaultDialog(
    titlePadding: const EdgeInsets.all(0),
    contentPadding: const EdgeInsets.all(0),
    backgroundColor: R.theme.white,
    radius: 30,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Session Expired',
          style: TextStyle(
            color: R.theme.black,
            fontWeight: FontWeight.bold,
            height: 1.5,
            fontSize: 20.sp,
          ),
        ),
        Text(
          'Please log in again.',
          style: TextStyle(
            color: R.theme.black,
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(
          height: 20,
        ),
         Divider(
          height: 1,
        color: R.theme.black,
        ),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: TextButton(
                  onPressed: () {
                    Get.back();
                  },
                  child: Text(
                    'OK',
                    style: TextStyle(
                       color: R.theme.primary,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                      fontSize: 20.sp,
                    ),
                  )),
            ),
          ],
        )
      ],
    ),
  );
}

// Future<void> logoutUser() async {
//   const storage = FlutterSecureStorage();
//   await storage.delete(key: MyConstants.token);
//   await storage.delete(key: MyConstants.userId);
//   await storage.delete(key: MyConstants.userFirstName);
//   await storage.delete(key: MyConstants.userlastName);

//   await storage.delete(key: MyConstants.age);
//   await storage.delete(key: MyConstants.motherOf);
//   await storage.delete(key: MyConstants.city);
//   await storage.delete(key: MyConstants.country);
//   await storage.delete(key: MyConstants.image);
//   await storage.delete(key: MyConstants.followers);
//   await storage.delete(key: MyConstants.following);
//   await storage.delete(key: MyConstants.bio);

//   await storage.delete(key: MyConstants.email);
//   await storage.delete(key: MyConstants.phoneNumber);

//   // // statusBar(color: primaryColor);
//   Get.offAllNamed(Routes.AUTH);
//   // sectionExpireDialog();
// }

// Future<Map<String, String?>> getUserData() async {
//   const storage = FlutterSecureStorage();

//   return {
//     MyConstants.token: await storage.read(key: MyConstants.token),
//     MyConstants.userId: await storage.read(key: MyConstants.userId),
//     MyConstants.userFirstName:
//         await storage.read(key: MyConstants.userFirstName),
//     MyConstants.userlastName: await storage.read(key: MyConstants.userlastName),
//     MyConstants.age: await storage.read(key: MyConstants.age),
//     MyConstants.motherOf: await storage.read(key: MyConstants.motherOf),
//     MyConstants.city: await storage.read(key: MyConstants.city),
//     MyConstants.country: await storage.read(key: MyConstants.country),
//     MyConstants.image: await storage.read(key: MyConstants.image),
//     MyConstants.followers: await storage.read(key: MyConstants.followers),
//     MyConstants.following: await storage.read(key: MyConstants.following),
//     MyConstants.bio: await storage.read(key: MyConstants.bio),
//     MyConstants.email: await storage.read(key: MyConstants.email),
//     MyConstants.phoneNumber: await storage.read(key: MyConstants.phoneNumber),
//     MyConstants.interests: await storage.read(key: MyConstants.interests),
//   };
// }
