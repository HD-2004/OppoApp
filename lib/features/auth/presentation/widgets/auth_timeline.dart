import 'package:flutter/material.dart';
import 'auth_colors.dart';

/// Timeline 3 bước cho forgot password flow.
class AuthTimeline extends StatelessWidget {
  const AuthTimeline({
    super.key,
    required this.steps,
    required this.activeIndex,
  });

  final List<AuthTimelineStep> steps;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          Expanded(
            child: _StepNode(
              step: steps[i],
              state: i < activeIndex
                  ? _StepState.done
                  : i == activeIndex
                  ? _StepState.active
                  : _StepState.pending,
            ),
          ),
          if (i < steps.length - 1) _Connector(isDone: i < activeIndex),
        ],
      ],
    );
  }
}

class AuthTimelineStep {
  const AuthTimelineStep({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

enum _StepState { done, active, pending }

class _StepNode extends StatelessWidget {
  const _StepNode({required this.step, required this.state});

  final AuthTimelineStep step;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final isDone = state == _StepState.done;
    final isActive = state == _StepState.active;

    final bgColor = isDone || isActive
        ? AuthColors.primary
        : AuthColors.outline(context);

    final iconColor = isDone || isActive
        ? Colors.white
        : AuthColors.textSecondary(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          width: isActive ? 44 : 38,
          height: isActive ? 44 : 38,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AuthColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isDone ? Icons.check_rounded : step.icon,
            color: iconColor,
            size: isActive ? 22 : 18,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          step.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive
                ? AuthColors.primary
                : AuthColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.isDone});
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        height: 2,
        width: 32,
        decoration: BoxDecoration(
          color: isDone ? AuthColors.primary : AuthColors.outline(context),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
