import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/services/terminal_service.dart';

class TerminalTab extends StatefulWidget {
  final TerminalSession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const TerminalTab({
    super.key,
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<TerminalTab> createState() => TerminalTabState();
}

class TerminalTabState extends State<TerminalTab> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: LinearDuration.fast,
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.spacing4,
            vertical: LinearSpacing.spacing8,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.spacing12,
            vertical: LinearSpacing.spacing4,
          ),
          decoration: BoxDecoration(
            color: widget.isActive
                ? LinearColors.surface
                : (isHovered ? LinearColors.fillSurface : Colors.transparent),
            borderRadius: BorderRadius.circular(LinearRadius.card),
            border: widget.isActive
                ? const Border(
                    bottom: BorderSide(
                      color: LinearColors.accentInteractive,
                      width: 2,
                    ),
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  widget.session.name,
                  style: TextStyle(
                    color: widget.isActive
                        ? LinearColors.textPrimary
                        : LinearColors.textTertiary,
                    fontWeight: widget.isActive
                        ? const FontWeight(510)
                        : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: LinearSpacing.spacing8),
              AnimatedOpacity(
                opacity: isHovered || widget.isActive ? 1.0 : 0.0,
                duration: LinearDuration.fast,
                child: InkWell(
                  onTap: widget.onClose,
                  borderRadius: BorderRadius.circular(LinearRadius.micro),
                  child: const Padding(
                    padding: EdgeInsets.all(LinearSpacing.spacing4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: LinearColors.textTertiary,
                    ),
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
