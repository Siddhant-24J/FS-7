import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class FS7Logo extends StatelessWidget {
  final double size;
  final bool showText;

  const FS7Logo({super.key, this.size = 80, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(size * 0.18),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.18),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (ctx, _, __) => Image.asset(
                'assets/images/png-01.png',
                fit: BoxFit.contain,
                errorBuilder: (c, _, __) => Image.asset(
                  'assets/images/PNG-01.png',
                  fit: BoxFit.contain,
                  errorBuilder: (c2, _, __) => _fallbackLogo(size),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallbackLogo(double size) {
    return Center(
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'FS-',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.32,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            TextSpan(
              text: '7',
              style: TextStyle(
                color: AppColors.brandOrange,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

