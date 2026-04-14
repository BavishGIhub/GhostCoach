import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_text_styles.dart';

class ScoreGauge extends StatefulWidget {
  final double score;
  final String letterGrade;
  final Color gradeColor;

  const ScoreGauge({
    super.key,
    required this.score,
    required this.letterGrade,
    required this.gradeColor,
  });

  @override
  State<ScoreGauge> createState() => _ScoreGaugeState();
}

class _ScoreGaugeState extends State<ScoreGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.score,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
  }

  @override
  void didUpdateWidget(ScoreGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _animation = Tween<double>(begin: oldWidget.score, end: widget.score)
          .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
          );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getColorForScore(double s) {
    if (s < 40) return const Color(0xFFFF4444);
    if (s < 70) return const Color(0xFFFFBB33);
    return const Color(0xFF76FF03);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final currentScore = _animation.value;
        final color = _getColorForScore(currentScore);
        return FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 200,
            height: 200,
            child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(200, 200),
                painter: _GaugePainter(score: currentScore, color: color),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentScore.toInt().toString(),
                    style: AppTextStyles.brand.copyWith(fontSize: 48),
                  ),
                  Text('OVERALL', style: AppTextStyles.sectionLabel),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: widget.gradeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.gradeColor),
                    ),
                    child: Text(
                      widget.letterGrade,
                      style: AppTextStyles.brandSmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
}

class _GaugePainter extends CustomPainter {
  final double score;
  final Color color;

  _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Background arc (240 degrees sweep starting at 150)
    final startAngle = 150 * pi / 180;
    final sweepAngle = 240 * pi / 180;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width,
      height: size.height,
    );

    final bgPaint = Paint()
      ..color = const Color(0xFF2C2C2C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, bgPaint);

    // Foreground arc
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: [
        const Color(0xFFFF4444),
        const Color(0xFFFFBB33),
        const Color(0xFF76FF03),
      ],
      stops: const [0.2, 0.5, 0.8],
    );

    final fgPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final currentSweep = (score / 100) * sweepAngle;
    canvas.drawArc(rect, startAngle, currentSweep, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.color != color;
  }
}