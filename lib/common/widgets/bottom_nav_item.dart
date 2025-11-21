import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/svg.dart';
import '../../app/core/resources/r.dart';

class MyBottomNavItem extends StatelessWidget {
  const MyBottomNavItem({
    super.key,
    required this.icon,
    required this.active,
    required this.onTap,
    required this.activeicon,
  });
  final String icon;
  final String activeicon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      iconSize: 24,
      isSelected: active,
      icon: SvgPicture.asset(
        active ? activeicon : icon,
        width: 25,
        height: 24,
        colorFilter: active
            ? ColorFilter.mode(R.theme.green, BlendMode.srcIn)
            : null,
      ),
    );
  }
}
