import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import '../../../../common/widgets/smooth_rectangle_border.dart';
import '../../app/core/resources/r.dart';

class MyBackBtn extends StatelessWidget {
  const MyBackBtn({
    super.key,
    this.onTap,
    this.icon = 'assets/icons/ic_arrow_bck.svg', // R.image.ic_arrow_bck
  });
  final VoidCallback? onTap;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;

    return Container(
      decoration: ShapeDecoration(
        shape: SmoothRectangleBorder(
          smoothness: 1,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: BorderSide(
            color: light ? R.theme.color600 :  R.theme.color400,
          ),
        ),
      ),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        onTap:
        onTap ??
                () {
              Get.back();
            },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SvgPicture.asset(
            icon,
            color: light ? R.theme.color600 : R.theme.color400,
            // color: light? whiteColor:nul,
            width: 24,
            height: 24,
          ),
        ),
      ),
    );
  }
}
