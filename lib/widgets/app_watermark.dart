import 'package:flutter/material.dart';

/// พื้นหลังลายน้ำโลโก้ 7J — วางครอบทั้งแอปผ่าน MaterialApp.builder
/// โลโก้ใหญ่ จาง ๆ อยู่กลางหน้า หลังทุกเมนู (Scaffold ต้องโปร่งใส)
class AppWatermark extends StatelessWidget {
  final Widget child;

  /// ความทึบของลายน้ำ (0.0–1.0) — ค่าเริ่มต้นจางมาก
  final double opacity;

  /// สัดส่วนขนาดโลโก้เทียบด้านสั้นของจอ
  final double sizeFactor;

  const AppWatermark({
    super.key,
    required this.child,
    this.opacity = 0.05,
    this.sizeFactor = 0.7,
  });

  @override
  Widget build(BuildContext context) {
    final logoSize = MediaQuery.of(context).size.shortestSide * sizeFactor;
    return Stack(
      children: [
        // พื้นครีมอ่อน ๆ ให้ลายน้ำกลมกลืน
        const Positioned.fill(child: ColoredBox(color: Color(0xFFFBFAF7))),
        // โลโก้ลายน้ำกลางหน้า (กดทะลุได้ ไม่บังการแตะ)
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: opacity,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
