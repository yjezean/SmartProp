import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ControlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final bool isLoading;
  final bool isEnabled;
  final VoidCallback onPressed;

  const ControlButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isActive,
    required this.isLoading,
    this.isEnabled = true,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isEnabled
                      ? AppTheme.primaryGreen
                      : AppTheme.textSecondary.withOpacity(0.5),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: isEnabled
                              ? null
                              : AppTheme.textSecondary.withOpacity(0.5),
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? (isActive ? AppTheme.success : AppTheme.textSecondary)
                        : AppTheme.divider,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'ON' : 'OFF',
                    style: TextStyle(
                      color: isEnabled ? Colors.white : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (isEnabled && !isLoading) ? onPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive
                      ? AppTheme.error
                      : AppTheme.primaryGreen,
                  disabledBackgroundColor: AppTheme.divider,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        isActive ? 'Turn OFF' : 'Turn ON',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

