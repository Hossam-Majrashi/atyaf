import 'package:flutter/material.dart';

class DesktopContent extends StatelessWidget {
  const DesktopContent({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: Padding(
          padding: EdgeInsets.all(constraints.maxWidth < 900 ? 20 : 32),
          child: child,
        ),
      ),
    ),
  );
}

class DesktopDialog extends StatelessWidget {
  const DesktopDialog({
    super.key,
    required this.title,
    required this.children,
    required this.actions,
  });
  final String title;
  final List<Widget> children, actions;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Dialog(
      child: SizedBox(
        width: constraints.maxWidth.clamp(280, 760) - 64,
        height: (constraints.maxHeight * .86).clamp(240, 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 8,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
