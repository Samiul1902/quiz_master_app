import 'package:flutter/material.dart';

class OptionButton extends StatelessWidget {
  const OptionButton({
    super.key,
    required this.title,
    required this.isSelected,
    required this.isCorrect,
    required this.isWrong,
    this.onTap,
  });

  final String title;
  final bool isSelected;
  final bool isCorrect;
  final bool isWrong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color backgroundColor = Colors.white;
    Color borderColor = colorScheme.outlineVariant;

    if (isCorrect) {
      backgroundColor = Colors.green.shade50;
      borderColor = Colors.green;
    } else if (isWrong) {
      backgroundColor = Colors.red.shade50;
      borderColor = Colors.red;
    } else if (isSelected) {
      backgroundColor = colorScheme.primaryContainer;
      borderColor = colorScheme.primary;
    }

    return Card(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(title),
      ),
    );
  }
}
