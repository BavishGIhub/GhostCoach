import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ShellScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _BottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
      ),
    );
  }

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: AppColors.border,
                width: 0.5,
              ),
            ),
          ),
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(context, 0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                _navItem(context, 1, Icons.history_outlined, Icons.history_rounded, 'History'),
                _navItem(context, 2, Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = currentIndex == index;
    final color = isSelected ? AppColors.primary : AppColors.textTertiary;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.15),
                          AppColors.secondary.withValues(alpha: 0.08),
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                letterSpacing: isSelected ? 0.5 : 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}