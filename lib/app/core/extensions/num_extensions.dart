import 'package:flutter/material.dart';

extension NumSpacing on num {
  SizedBox get sbh => SizedBox(height: toDouble()); // vertical space
  SizedBox get sbw => SizedBox(width: toDouble()); // horizontal space

  EdgeInsets get all => EdgeInsets.all(toDouble());
  EdgeInsets get horizontal => EdgeInsets.symmetric(horizontal: toDouble());
  EdgeInsets get vertical => EdgeInsets.symmetric(vertical: toDouble());

  BorderRadius get radius => BorderRadius.circular(toDouble());
}
