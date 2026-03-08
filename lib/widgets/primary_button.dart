import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:flutter/cupertino.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final Function()? onPressed;
  final Color? color;
  final TextStyle? style;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: CupertinoButton(
        onPressed: onPressed,
        color: color ?? AppColors.accent,
        child: Text(text, style: style),
      ),
    );
  }
}
