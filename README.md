# 📱 Flutter Project Architecture

A scalable and modular Flutter starter project built with **GetX**, **Clean Architecture**, **Firebase**, and **Secure Storage**. Designed for production-ready mobile apps with built-in state management, localization, networking, theming, and asset generation.

---

## ✨ Overview

This template gives you:

✅ Folder structure that scales  
✅ Clean separation of concerns  
✅ Easy-to-manage state with GetX  
✅ Token-secure authentication  
✅ Reusable network and API layer  
✅ Localization support (i18n)  
✅ Firebase + Notification integration  
✅ Dev productivity tools (like image & locale generators)

---

## 🚀 Features

- ⚙️ **GetX**: Routing, State Management, and Dependency Injection
- 🔐 **Auth & Secure Token Storage** with `flutter_secure_storage`
- 🌐 **HTTP API Integration** with dynamic token headers
- 🔄 **API State Wrappers**: loading, success, error, empty
- 🔔 **FCM Push Notifications** with foreground & background handling
- 🌍 **JSON Localization** with auto key generation (`get generate locales`)
- 🎨 **Theme Management** via `R.color`, `R.textStyle`
- 📷 **Auto-generated Image Constants** via `AppImages`
- 🧱 **GetX CLI Integration** for rapid module scaffolding

---

## 🧱 Architecture

```

lib/
├── app/
│   ├── core/              # Config, theme, localization, constants, extensions
│   ├── data/              # Models, repositories, network, services
│   ├── modules/           # Feature-based structure (UI + logic)
│   ├── routes/            # GetX named routes
│   └── binding/           # Dependency injection bindings
├── assets/
│   ├── images/            # App images & icons
│   └── locales/           # Translation files (en\_US, etc.)
├── tool/
│   └── build\_resources.dart    # Script for generating images + moving locales

````

---

## ⚙️ Technologies Used

- Flutter 3.x
- GetX (state + DI + routing)
- Firebase Core & Messaging
- Flutter Secure Storage
- flutter_local_notifications
- HTTP + Token headers
- Auto asset & localization scripts

---

## 🛠 Setup Instructions

### 1. Clone and install dependencies

```bash
git clone https://github.com/your-name/pcom_app.git
cd pcom_app
flutter pub get
````

---

### 2. Firebase Setup

Ensure you've added:

* ✅ `android/app/google-services.json`
* ✅ `ios/Runner/GoogleService-Info.plist`

Then initialize:

```dart
WidgetsFlutterBinding.ensureInitialized();
await Firebase.initializeApp();
NotificationService.initialize();
```

---

### 3. Run resource generators

```bash
dart tool/build_resources.dart
```

This will:

* ✅ Generate `AppImages` from `assets/images`
* ✅ Move `locales.g.dart` to `lib/app/core/localization`
* ✅ Remove `lib/generated/`

---

## 🧩 GetX CLI Commands

```bash
flutter pub global activate get_cli
```

| Command                               | Description                             |
| ------------------------------------- | --------------------------------------- |
| `get create page:login`               | Full module (view, controller, binding) |
| `get create controller:auth`          | Generate only controller                |
| `get generate locales assets/locales` | Create localization Dart file from JSON |
| `get create service:notification`     | Generate service file                   |

---

## 🔐 Authentication Flow

* ✅ Token and user stored in `FlutterSecureStorage`
* ✅ AuthService handles login/logout globally

```dart
await authService.saveUserData(userMap, token);
final user = await authService.getUserData();
```

Example:

```dart
Future<void> fetchUserProfile() async {
  await fetchSingleWithState<UserModel>(
    state: userState,
    item: user,
    apiMethod: () => fetchItem<UserModel>(
      url: ApiRoutes.getUser,
      rootKey: 'user',
      fromJson: (json) => UserModel.fromJson(json),
    ),
  );
}
```

---

## 🔔 Notifications (FCM + Local)

```dart
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  NotificationService.showLocal(message);
});

FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  NotificationService.navigateFromPayload(message.data);
});
```

You can also navigate using:

```dart
Get.toNamed(message.data['route']);
```

---

## 📸 Image Assets

Auto-generate image keys from `/assets/images/`:

```bash
dart tool/generate_app_images.dart
```

Use in code:

```dart
Image.asset(R.image.img_logo);
SvgPicture.asset(R.image.ic_arrow_back);
```

---

## 🌍 Localization

Translate UI with:

```json
// assets/locales/en_US.json
{
  "login": "Login",
  "welcome_back": "Welcome Back!"
}
```

Then:

```dart
Text(LocaleKeys.welcome_back.tr);
```

Regenerate Dart translation map:

```bash
get generate locales assets/locales
```

---

## ✅ Todo / Enhancements

* [ ] Add CI/CD with GitHub Actions
* [ ] Add refresh token handling
* [ ] Add biometric login option
* [ ] Add dark mode switching
* [ ] Add unit and widget tests
* [ ] Add `settings` and `profile` modules

---

## 👨‍💻 Author

* **Muhammad Asad** – Flutter Architect
* 📧 [asaddq518@gmail.com](mailto:asaddq518@gmail.com)

---
