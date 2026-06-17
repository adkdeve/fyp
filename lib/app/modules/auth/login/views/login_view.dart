import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:construction_safety/app/core/extensions/theme_extensions.dart';
import '../controllers/login_controller.dart';

class LoginView extends GetView<LoginController> {
  LoginView({super.key});

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColor.statusBar,
      child: Scaffold(
        backgroundColor: AppColor.scaffoldBg,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo / Title
                    Icon(Icons.construction, size: 64.r, color: const Color(0xFF3B82F6)),
                    SizedBox(height: 16.h),
                    Text(
                      'Construction Safety',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColor.textPrimary, fontSize: 24.sp, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Supervisor Portal',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColor.textSecondary, fontSize: 14.sp),
                    ),
                    SizedBox(height: 40.h),

                    // Login ID field
                    _buildLabel('Login ID'),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: controller.emailCtrl,
                      keyboardType: TextInputType.text,
                      style: TextStyle(color: AppColor.textPrimary),
                      decoration: _inputDecoration(hint: 'so-spidermon-1359', icon: Icons.person_outlined),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Login ID is required';
                        return null;
                      },
                    ),
                    SizedBox(height: 16.h),

                    // Password field
                    _buildLabel('Password'),
                    SizedBox(height: 6.h),
                    Obx(
                      () => TextFormField(
                        controller: controller.passwordCtrl,
                        obscureText: controller.obscurePassword.value,
                        style: TextStyle(color: AppColor.textPrimary),
                        decoration: _inputDecoration(
                          hint: '••••••••',
                          icon: Icons.lock_outlined,
                          suffix: IconButton(
                            icon: Icon(
                              controller.obscurePassword.value
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColor.textSecondary,
                              size: 20.r,
                            ),
                            onPressed: controller.togglePasswordVisibility,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password is required';
                          if (v.length < 4) return 'Password too short';
                          return null;
                        },
                      ),
                    ),
                    SizedBox(height: 32.h),

                    // Login button
                    Obx(
                      () => ElevatedButton(
                        onPressed: controller.isLoading.value ? null : () => controller.login(_formKey),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          disabledBackgroundColor: const Color(0xFF3B82F6).withOpacity(0.5),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                        ),
                        child: controller.isLoading.value
                            ? SizedBox(
                                height: 20.r,
                                width: 20.r,
                                child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'Sign In',
                                style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: TextStyle(color: AppColor.textSecondary, fontSize: 13.sp),
  );

  InputDecoration _inputDecoration({required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColor.textTertiary),
      prefixIcon: Icon(icon, color: AppColor.textSecondary, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColor.subtleBg,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: AppColor.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: AppColor.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }
}
