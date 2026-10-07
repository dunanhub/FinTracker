import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/theme_controller.dart';
import '../../core/theme/theme_preset.dart';
import '../controllers/shake_settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<ThemeController>();
    final shakeSettings = context.watch<ShakeSettingsController>();

    final width = MediaQuery.sizeOf(context).width;

    final compact = width < 360;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          compact ? 16 : 20,
          8,
          compact ? 16 : 20,
          40,
        ),
        children: [
          Text('Внешний вид', style: theme.textTheme.headlineMedium),

          const SizedBox(height: 5),

          Text(
            'Настрой FinTracker под себя',
            style: theme.textTheme.bodyMedium,
          ),

          const SizedBox(height: 24),

          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Режим', style: theme.textTheme.titleMedium),

                const SizedBox(height: 14),

                _ModeSelector(
                  value: controller.themeMode,
                  onChanged: controller.setThemeMode,
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Цвет интерфейса', style: theme.textTheme.titleMedium),

                const SizedBox(height: 5),

                Text(
                  'Выбери мягкую цветовую палитру',
                  style: theme.textTheme.bodyMedium,
                ),

                const SizedBox(height: 18),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth < 300 ? 1 : 2;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: AppThemePreset.values.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: columns == 1 ? 3.3 : 1.65,
                      ),
                      itemBuilder: (context, index) {
                        final preset = AppThemePreset.values[index];

                        return _ThemeOption(
                          preset: preset,
                          selected: controller.preset == preset,
                          onTap: () {
                            controller.setPreset(preset);
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Text('Быстрые действия', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          _SettingsCard(
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Встряхнуть для добавления'),
              subtitle: const Text(
                'Быстро открыть новую операцию встряхиванием телефона',
              ),
              value: shakeSettings.enabled,
              onChanged: shakeSettings.setEnabled,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  const _ModeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeButton(
            icon: Icons.light_mode_outlined,
            label: 'Light',
            selected: value == ThemeMode.light,
            onTap: () {
              onChanged(ThemeMode.light);
            },
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: _ModeButton(
            icon: Icons.dark_mode_outlined,
            label: 'Dark',
            selected: value == ThemeMode.dark,
            onTap: () {
              onChanged(ThemeMode.dark);
            },
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: _ModeButton(
            icon: Icons.smartphone_rounded,
            label: 'Система',
            selected: value == ThemeMode.system,
            onTap: () {
              onChanged(ThemeMode.system);
            },
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
          decoration: BoxDecoration(
            color:
                selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color:
                    selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.primary,
              ),

              const SizedBox(height: 5),

              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color:
                        selected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final AppThemePreset preset;

  final bool selected;

  final VoidCallback onTap;

  const _ThemeOption({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _previewColors(preset);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.last.withValues(alpha: 0.20),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child:
                    selected
                        ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 21,
                        )
                        : null,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  preset.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<Color> _previewColors(AppThemePreset preset) {
  switch (preset) {
    case AppThemePreset.white:
      return const [Color(0xFFEDEAE4), Color(0xFFCFC9C0)];

    case AppThemePreset.black:
      return const [Color(0xFF55585F), Color(0xFF222428)];

    case AppThemePreset.gray:
      return const [Color(0xFFA8B0BD), Color(0xFF6B7587)];

    case AppThemePreset.pink:
      return const [Color(0xFFE39AB2), Color(0xFFC56E8B)];

    case AppThemePreset.navy:
      return const [Color(0xFF6079AD), Color(0xFF334A79)];

    case AppThemePreset.blue:
      return const [Color(0xFF73A9E7), Color(0xFF477DBF)];
  }
}
