import 'package:flutter/material.dart';

class SettingsListTile extends StatelessWidget {
  final Widget icon;
  final Widget child;
  final VoidCallback? onTap;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SettingsListTile({
    super.key,
    required this.icon,
    required this.child,
    this.onTap,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              icon,
              const SizedBox(width: 16),
              Expanded(child: child),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
