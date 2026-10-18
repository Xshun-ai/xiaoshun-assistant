import 'package:flutter/material.dart';

class GradeFilterBar extends StatelessWidget {
  final ThemeData theme;
  final List<String> semesters;
  final String? selectedTermId;
  final ValueChanged<String> onTermChanged;
  final List<String> attributes;
  final String selectedAttribute;
  final ValueChanged<String> onAttributeChanged;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  const GradeFilterBar({
    super.key,
    required this.theme,
    required this.semesters,
    required this.selectedTermId,
    required this.onTermChanged,
    required this.attributes,
    required this.selectedAttribute,
    required this.onAttributeChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final fieldBackground = theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: 0.3);

    return Container(
      color: backgroundColor ?? theme.colorScheme.surface,
      padding: padding,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: fieldBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedTermId,
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  items: semesters.map((semester) {
                    return DropdownMenuItem(
                      value: semester,
                      child: Text(
                        semester,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onTermChanged(value);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: fieldBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedAttribute,
                  isExpanded: true,
                  icon: Icon(
                    Icons.filter_list_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                  ),
                  items: attributes.map((attribute) {
                    return DropdownMenuItem(
                      value: attribute,
                      child: Text(attribute),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onAttributeChanged(value);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
