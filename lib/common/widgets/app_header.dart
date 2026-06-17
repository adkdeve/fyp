import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:construction_safety/app/core/extensions/theme_extensions.dart';

/// Consistent, mobile-friendly screen header used across all screens.
///
/// Layout: [optional back button]  Title (+ optional subtitle)  [actions…]
/// with an optional [bottom] area for a search bar / filter chips / tabs.
/// Theme-aware (cardBg surface + bottom border).
class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? bottom;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.onBack,
    this.actions = const [],
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColor.cardBg,
        border: Border(bottom: BorderSide(color: AppColor.borderColor)),
      ),
      padding: EdgeInsets.fromLTRB(showBack ? 6 : 16, 10, 12, bottom == null ? 16 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showBack)
                IconButton(
                  onPressed: onBack ?? Get.back,
                  icon: Icon(Icons.arrow_back, color: AppColor.textPrimary, size: 22),
                  splashRadius: 22,
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColor.textPrimary),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 12.5, color: AppColor.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              ...actions,
            ],
          ),
          if (bottom != null) ...[
            const SizedBox(height: 14),
            bottom!,
          ],
        ],
      ),
    );
  }
}
