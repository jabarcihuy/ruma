import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app/theme.dart';

class RumaIcon extends StatelessWidget {
  const RumaIcon(
    this.name, {
    super.key,
    this.size = 22,
    this.color = RumaColors.muted,
  });
  final String name;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SvgPicture.asset(
      'design/assets/ruma/icons/$name.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    ),
  );
}

// Shared geometry for phone pages: forms, details, and secondary screens.
class RumaPageBody extends StatelessWidget {
  const RumaPageBody({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    ),
  );
}

// Paired actions stack when labels need room, rather than compressing the text.
class RumaActionPair extends StatelessWidget {
  const RumaActionPair({
    super.key,
    required this.first,
    required this.second,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });
  final Widget first, second;
  final CrossAxisAlignment crossAxisAlignment;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) =>
        size.maxWidth < 280 || MediaQuery.textScalerOf(context).scale(13) > 18
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 8), second],
          )
        : Row(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              Expanded(child: first),
              const SizedBox(width: 12),
              Expanded(child: second),
            ],
          ),
  );
}

// Keep the whole decision scrollable, including its actions, above a small IME viewport.
class RumaDialog extends StatelessWidget {
  const RumaDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });
  final Widget title, content;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: title,
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [content, const SizedBox(height: 24), ...actions],
      ),
    ),
  );
}

class RumaCard extends StatelessWidget {
  const RumaCard({
    super.key,
    required this.child,
    this.color = RumaColors.surface,
    this.padding = 16,
    this.radius = 20,
  });
  final Widget child;
  final Color color;
  final double padding, radius;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Material(
      color: color,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(radius),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    ),
  );
}

class RumaButton extends StatelessWidget {
  const RumaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.busy = false,
    this.destructive = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary, busy, destructive;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    style: secondary
        ? FilledButton.styleFrom(
            backgroundColor: RumaColors.line,
            foregroundColor: RumaColors.ink,
          )
        : destructive
        ? FilledButton.styleFrom(backgroundColor: RumaColors.danger)
        : null,
    child: busy
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          )
        : Text(label, textAlign: TextAlign.center),
  );
}

class RumaHeading extends StatelessWidget {
  const RumaHeading(
    this.title,
    this.subtitle, {
    super.key,
    this.compact = false,
  });
  final String title;
  final String? subtitle;
  final bool compact;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: compact
            ? Theme.of(context).textTheme.headlineSmall
            : Theme.of(context).textTheme.headlineMedium,
      ),
      if (subtitle != null && subtitle!.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
      ],
    ],
  );
}

// Common durations remain optional shortcuts; the field accepts custom values.
class RumaDurationChoices extends StatelessWidget {
  const RumaDurationChoices({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onChanged,
  });
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final minutes in [15, 30, 60])
              ChoiceChip(
                label: Text('$minutes menit'),
                selected: int.tryParse(value.text) == minutes,
                selectedColor: RumaColors.peach,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: enabled
                    ? (_) {
                        controller.text = '$minutes';
                        onChanged?.call();
                      }
                    : null,
              ),
          ],
        ),
      );
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: RumaCard(
      color: RumaColors.soft,
      child: Text(
        message,
        style: const TextStyle(color: RumaColors.danger, height: 1.5),
      ),
    ),
  );
}

void showRumaPrivacy(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Datamu, kendalimu',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          const Text(
            'Akun dikelola melalui Firebase Authentication. Agenda dan catatan keuangan dirancang tersimpan di cloud dan dipisahkan menurut akun. Kata sandi tidak disimpan sebagai catatan aplikasi.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Saat memakai Asisten, pesan serta konteks yang diperlukan akan dikirim ke NaraRouter. Perubahan data memerlukan tinjauan dan persetujuanmu. Persetujuan penggunaan AI akan diminta terpisah sebelum percakapan pertama.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Tanpa pendaftaran email, akun bersifat sementara. Akun ini tidak dapat dipulihkan jika sesi atau instalasi hilang; tautkan email untuk mempertahankan akses.',
          ),
          const SizedBox(height: 24),
          RumaButton(
            label: 'Mengerti',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  ),
);
