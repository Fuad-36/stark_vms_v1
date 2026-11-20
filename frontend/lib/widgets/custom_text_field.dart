import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable accessible text field with label, icons, and error handling.
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final bool enabled;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final MaxLengthEnforcement maxLengthEnforcement;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
    this.errorText,
    this.enabled = true,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.maxLengthEnforcement = MaxLengthEnforcement.none,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          maxLength: maxLength,
          maxLengthEnforcement: maxLengthEnforcement,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          onChanged: onChanged,
          enabled: enabled,
          style: theme.textTheme.bodyMedium,
          buildCounter: maxLength != null
              ? (context, {required currentLength, required isFocused, maxLength}) => null
              : null,
          decoration: InputDecoration(
            hintText: hintText,
            errorText: errorText,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 20, color: theme.colorScheme.outline)
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled
                ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
                width: 1.8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
