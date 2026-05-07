import 'package:flutter/material.dart';
import '../theme.dart';

class ParamCard extends StatelessWidget {
  final String label;
  final Widget child;

  const ParamCard({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.elevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
