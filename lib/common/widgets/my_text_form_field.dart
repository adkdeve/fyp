import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/core/core.dart';
import '../../common/widgets/smooth_rectangle_border.dart';

class MyTextFormField extends StatefulWidget {
  const MyTextFormField({
    super.key,
    required this.hinttxt,
    this.suffixIcon,
    this.prefixIcon,
    this.validator,
    required this.controller,
    this.obscureTxt = false,
    this.onChange,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
  });

  final String hinttxt;
  final String? prefixIcon;
  final String? suffixIcon;
  final TextInputType keyboardType;
  final bool obscureTxt;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool readOnly;
  final ValueChanged<String>? onChange;

  @override
  State<MyTextFormField> createState() => _MyTextFormFieldState();
}

class _MyTextFormFieldState extends State<MyTextFormField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _hasError = false;
  String? _errorText;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _passwordVisible = false;

    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lightMode = Theme.of(context).brightness == Brightness.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔹 Outer container with custom border
        Container(
          padding: const EdgeInsets.all(2),
          decoration: ShapeDecoration(
            shape: SmoothRectangleBorder(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              side: BorderSide(
                color: _hasError
                    ? R.theme.error
                    : _isFocused
                    ? R.theme.borderFocused
                    : R.theme.borderUnfocused,
              ),
            ),
          ),
          child: TextFormField(
            onChanged: (value) {
              widget.onChange?.call(value);
              if (_hasError) {
                // Reset error state when user types again
                setState(() {
                  _hasError = false;
                  _errorText = null;
                });
              }
            },
            focusNode: _focusNode,
            readOnly: widget.readOnly,
            obscureText: widget.obscureTxt ? !_passwordVisible : false,
            controller: widget.controller,
            keyboardType: widget.keyboardType,
            cursorColor: R.theme.cursorColor,
            maxLines: 1,
            style: GoogleFonts.inter().copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
            validator: (value) {
              final result = widget.validator?.call(value);
              setState(() {
                _hasError = result != null && result.isNotEmpty;
                _errorText = result;
              });
              return null; // prevent default Flutter error display
            },
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppConfig.defaultPadding,
                vertical: 12,
              ),
              hintText: widget.hinttxt,
              hintStyle: GoogleFonts.inter().copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.3,
              ),
              suffixIcon: widget.obscureTxt
                  ? IconButton(
                iconSize: 20,
                icon: Icon(
                  _passwordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: R.theme.color400,
                ),
                onPressed: () {
                  setState(() {
                    _passwordVisible = !_passwordVisible;
                  });
                },
              )
                  : (widget.suffixIcon != null
                  ? Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConfig.defaultPadding),
                child: SvgPicture.asset(widget.suffixIcon ?? ''),
              )
                  : null),
              prefixIcon: widget.prefixIcon != null
                  ? Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConfig.defaultPadding, vertical: 14),
                child: SvgPicture.asset(
                  widget.prefixIcon ?? '',
                  color: _isFocused
                      ? (lightMode
                      ? R.theme.light.primaryColor
                      : R.theme.dark.primaryColor)
                      : R.theme.color400,
                ),
              )
                  : null,
              border: InputBorder.none,
            ),
          ),
        ),

        // 🔻 Error message displayed *outside* the field
        if (_hasError && _errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 6),
            child: Text(
              _errorText!,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: R.theme.error,
                height: 1.2,
              ),
            ),
          ),
      ],
    );
  }
}
