import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  bool _codeLoading = false;
  String? _error;
  String? _codeError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) { setState(() => _codeError = 'กรุณาใส่รหัสผู้ใช้'); return; }
    setState(() { _codeLoading = true; _codeError = null; });
    try {
      final appUser = await FirestoreService.getAppUserByCode(code);
      if (!mounted) return;
      if (appUser == null) { setState(() => _codeError = 'ไม่พบรหัสผู้ใช้นี้ กรุณาตรวจสอบอีกครั้ง'); return; }
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => HomeScreen(appUser: appUser, isCodeLogin: true),
      ));
      _codeCtrl.clear();
    } catch (e) {
      if (mounted) setState(() => _codeError = 'เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _codeLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 740;
        if (isWide) {
          final heroW = constraints.maxWidth * 0.50 + 40;
          return Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFFF5F5F4)),
              Positioned(
                left: 0, top: 0, bottom: 0,
                width: heroW,
                child: ClipPath(
                  clipper: _WaveClipper(),
                  child: const _HeroPanel(),
                ),
              ),
              Positioned(
                left: constraints.maxWidth * 0.48,
                top: 0, bottom: 0, right: 0,
                child: _FormContent(state: this),
              ),
            ],
          );
        }
        return ColoredBox(
          color: const Color(0xFFF5F5F4),
          child: SingleChildScrollView(
            child: Column(children: [
              const SizedBox(height: 220, child: _HeroPanel(showFeatures: false)),
              _FormContent(state: this, narrowMode: true),
            ]),
          ),
        );
      }),
    );
  }
}

// ── Hero panel ────────────────────────────────────────────────────────────────

class _HeroPanel extends StatelessWidget {
  final bool showFeatures;
  const _HeroPanel({super.key, this.showFeatures = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF8DC), Color(0xFFFFE082), Color(0xFFFFB300)],
        ),
      ),
      child: Stack(children: [
        // ── Dot grids ─────────────────────────────────────────
        const Positioned(top: 18,  left: 36,  child: _DotGrid(4, 4)),
        if (showFeatures)
          const Positioned(bottom: 210, right: 14, child: _DotGrid(3, 5)),

        // ── Background circles ────────────────────────────────
        Positioned(top: -55, right: -30, child: _Bubble(220, 0.13)),
        Positioned(top: 70,  left:  8,   child: _Bubble(65,  0.10)),
        if (showFeatures) ...[
          Positioned(bottom: 140, left: -65, child: _OutlineCircle(185)),
          Positioned(top: 195,   right:  2,  child: _Bubble(42,  0.08)),
        ],

        // ── Floating word chips ───────────────────────────────
        const Positioned(top: 22,  left: 14, child: _WordChip('Aa')),
        if (showFeatures) ...[
          Positioned(top: 138, right: 22,   child: _ChatDotBubble()),
          const Positioned(top: 268, left: 22,  child: _WordChip('Hello')),
          const Positioned(top: 358, right: 28, child: _WordChip('Hi!')),
          const Positioned(bottom: 218, left: 14,  child: _WordChip('Learn')),
          const Positioned(bottom: 192, right: 14, child: _WordChip('English')),
        ],

        // ── Small geometric accents ───────────────────────────
        if (showFeatures) ...[
          Positioned(top: 192, right: 78,  child: _Diamond()),
          Positioned(bottom: 288, left: 88, child: _Diamond()),
          Positioned(top: 438, right: 58,
              child: _Bubble(10, 0.35)),
          Positioned(top: 308, left: 104,
              child: _Bubble(8, 0.40)),
        ],

        // ── Skyline silhouette ────────────────────────────────
        if (showFeatures)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SizedBox(
              height: 185,
              child: CustomPaint(painter: _SkylinePainter()),
            ),
          ),

        // ── Center logo + title ───────────────────────────────
        SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.fromLTRB(36, 24, 36, showFeatures ? 200 : 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 130,
                  height: 130,
                  errorBuilder: (_, __, ___) => Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.18),
                      border: Border.all(color: Colors.white.withOpacity(0.35), width: 2),
                    ),
                    child: const Icon(Icons.school_rounded, size: 52, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('7J English',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800,
                        color: Color(0xFF1A237E), letterSpacing: 0.5)),
                const SizedBox(height: 6),
                const Text('ระบบจัดการโรงเรียน',
                    style: TextStyle(fontSize: 15,
                        color: Color(0xFF3949AB), letterSpacing: 0.3)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Hero decorative widgets ───────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final double size;
  final double opacity;
  const _Bubble(this.size, this.opacity);
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity)),
  );
}

class _OutlineCircle extends StatelessWidget {
  final double size;
  const _OutlineCircle(this.size);
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withOpacity(0.14), width: 2),
    ),
  );
}

class _DotGrid extends StatelessWidget {
  final int rows;
  final int cols;
  const _DotGrid(this.rows, this.cols);
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(rows, (r) => Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(cols, (c) => Padding(
          padding: const EdgeInsets.only(right: 7),
          child: Container(
            width: 5, height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE65100).withOpacity(0.18),
            ),
          ),
        )),
      ),
    )),
  );
}

class _WordChip extends StatelessWidget {
  final String text;
  const _WordChip(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFF8F00).withOpacity(0.22),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE65100).withOpacity(0.35)),
    ),
    child: Text(text,
        style: const TextStyle(color: Color(0xFF7B3500),
            fontWeight: FontWeight.bold, fontSize: 14)),
  );
}

class _ChatDotBubble extends StatelessWidget {
  const _ChatDotBubble();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFF8F00).withOpacity(0.22),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE65100).withOpacity(0.35)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      _dot(), const SizedBox(width: 4),
      _dot(), const SizedBox(width: 4),
      _dot(),
    ]),
  );
  Widget _dot() => Container(
    width: 6, height: 6,
    decoration: const BoxDecoration(
        shape: BoxShape.circle, color: Color(0xFF7B3500)),
  );
}

class _Diamond extends StatelessWidget {
  const _Diamond();
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: math.pi / 4,
    child: Container(
      width: 12, height: 12,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.30),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

// ── Skyline CustomPainter ─────────────────────────────────────────────────────

class _SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Navy ground fill
    final navyFill = Paint()
      ..color = const Color(0xFF0D1B5E)
      ..style = PaintingStyle.fill;
    // Golden amber for landmarks
    final goldFill = Paint()
      ..color = const Color(0xFFFFB300)
      ..style = PaintingStyle.fill;
    final goldLine = Paint()
      ..color = const Color(0xFFE65100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Navy leaves
    final navyLeaf = Paint()
      ..color = const Color(0xFF1A237E)
      ..style = PaintingStyle.fill;
    // Golden wave highlight
    final waveGold = Paint()
      ..color = const Color(0xFFFFB300).withOpacity(0.55)
      ..style = PaintingStyle.fill;

    // Main navy ground wave
    final ground = Path()
      ..moveTo(0, size.height * 0.44)
      ..quadraticBezierTo(size.width * 0.26, size.height * 0.22,
          size.width * 0.52, size.height * 0.38)
      ..quadraticBezierTo(size.width * 0.76, size.height * 0.52,
          size.width, size.height * 0.38)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(ground, navyFill);

    // Golden wave ribbon on top of navy
    final wave = Path()
      ..moveTo(0, size.height * 0.44)
      ..quadraticBezierTo(size.width * 0.26, size.height * 0.22,
          size.width * 0.52, size.height * 0.38)
      ..quadraticBezierTo(size.width * 0.76, size.height * 0.52,
          size.width, size.height * 0.38)
      ..lineTo(size.width, size.height * 0.43)
      ..quadraticBezierTo(size.width * 0.76, size.height * 0.57,
          size.width * 0.52, size.height * 0.43)
      ..quadraticBezierTo(size.width * 0.26, size.height * 0.27,
          0, size.height * 0.49)
      ..close();
    canvas.drawPath(wave, waveGold);

    // Landmarks (golden)
    _bigBen(canvas, goldFill, goldLine,
        size.width * 0.11, size.height * 0.92);
    _ferrisWheel(canvas, goldLine,
        size.width * 0.33, size.height * 0.65, 27);
    _towerBridge(canvas, goldFill, goldLine,
        size.width * 0.57, size.height * 0.89, size.width * 0.21);
    _liberty(canvas, goldLine,
        size.width * 0.86, size.height * 0.70);

    // Leaf clusters at corners
    _leafCluster(canvas, navyLeaf, size, true);
    _leafCluster(canvas, navyLeaf, size, false);
  }

  void _leafCluster(Canvas canvas, Paint paint, Size size, bool isLeft) {
    final bx = isLeft ? -10.0 : size.width + 10;
    final by = size.height;
    final angles = isLeft
        ? [-0.6, -0.3, 0.0, 0.3, 0.6, -0.9, -1.2]
        : [math.pi + 0.6, math.pi + 0.3, math.pi, math.pi - 0.3, math.pi - 0.6, math.pi + 0.9, math.pi + 1.2];
    final offsets = [
      Offset(bx + (isLeft ? 30 : -30), by - 30),
      Offset(bx + (isLeft ? 50 : -50), by - 55),
      Offset(bx + (isLeft ? 20 : -20), by - 65),
      Offset(bx + (isLeft ? 45 : -45), by - 85),
      Offset(bx + (isLeft ? 10 : -10), by - 95),
      Offset(bx + (isLeft ? 60 : -60), by - 35),
      Offset(bx + (isLeft ? 70 : -70), by - 70),
    ];
    for (int i = 0; i < offsets.length; i++) {
      _leaf(canvas, paint, offsets[i], 42, angles[i % angles.length]);
    }
  }

  void _leaf(Canvas canvas, Paint paint, Offset tip, double len, double angle) {
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(-len * 0.28, -len * 0.30, -len * 0.42, -len * 0.65, 0, -len)
      ..cubicTo(len * 0.42, -len * 0.65, len * 0.28, -len * 0.30, 0, 0);
    canvas.drawPath(path, paint);
    // Midrib
    final midrib = Paint()
      ..color = const Color(0xFF0D1B5E).withOpacity(0.25)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(0, -len * 0.85), midrib);
    canvas.restore();
  }

  void _bigBen(Canvas canvas, Paint fill, Paint line, double x, double base) {
    // Base plinth
    final plinth = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 16, base - 12, 32, 12), const Radius.circular(1));
    canvas.drawRRect(plinth, fill);
    canvas.drawRRect(plinth, line);
    // Shaft
    canvas.drawRect(Rect.fromLTWH(x - 10, base - 72, 20, 62), fill);
    canvas.drawRect(Rect.fromLTWH(x - 10, base - 72, 20, 62), line);
    // Clock box
    canvas.drawRect(Rect.fromLTWH(x - 14, base - 88, 28, 18), fill);
    canvas.drawRect(Rect.fromLTWH(x - 14, base - 88, 28, 18), line);
    // Clock face
    canvas.drawCircle(Offset(x, base - 79), 7, line);
    // Spire
    final spire = Path()
      ..moveTo(x - 8, base - 88)
      ..lineTo(x, base - 120)
      ..lineTo(x + 8, base - 88)
      ..close();
    canvas.drawPath(spire, fill);
    canvas.drawPath(spire, line);
  }

  void _ferrisWheel(Canvas canvas, Paint line,
      double cx, double cy, double r) {
    canvas.drawCircle(Offset(cx, cy), r, line);
    canvas.drawCircle(Offset(cx, cy), 4, line);
    for (int i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      canvas.drawLine(Offset(cx, cy),
          Offset(cx + r * math.cos(a), cy + r * math.sin(a)), line);
    }
    canvas.drawLine(Offset(cx - r * 0.5, cy + r), Offset(cx, cy + r + 18), line);
    canvas.drawLine(Offset(cx + r * 0.5, cy + r), Offset(cx, cy + r + 18), line);
  }

  void _towerBridge(Canvas canvas, Paint fill, Paint line,
      double cx, double base, double span) {
    final lx = cx - span / 2;
    final rx = cx + span / 2;
    _bridgeTower(canvas, fill, line, lx, base);
    _bridgeTower(canvas, fill, line, rx, base);
    canvas.drawLine(Offset(lx, base - 22), Offset(rx, base - 22), line);
    canvas.drawLine(Offset(lx, base - 38), Offset(rx, base - 38), line);
    canvas.drawLine(Offset(lx, base - 76), Offset(cx - span * 0.12, base - 38), line);
    canvas.drawLine(Offset(rx, base - 76), Offset(cx + span * 0.12, base - 38), line);
  }

  void _bridgeTower(Canvas canvas, Paint fill, Paint line,
      double x, double base) {
    canvas.drawRect(Rect.fromLTWH(x - 9, base - 78, 18, 78), fill);
    canvas.drawRect(Rect.fromLTWH(x - 9, base - 78, 18, 78), line);
    canvas.drawRect(Rect.fromLTWH(x - 12, base - 90, 24, 14), fill);
    canvas.drawRect(Rect.fromLTWH(x - 12, base - 90, 24, 14), line);
    final sp = Path()
      ..moveTo(x - 10, base - 90)
      ..lineTo(x - 7, base - 106)
      ..lineTo(x - 4, base - 90)
      ..moveTo(x + 4, base - 90)
      ..lineTo(x + 7, base - 106)
      ..lineTo(x + 10, base - 90);
    canvas.drawPath(sp, fill);
    canvas.drawPath(sp, line);
  }

  void _liberty(Canvas canvas, Paint line, double x, double base) {
    final robe = Path()
      ..moveTo(x - 9, base)
      ..lineTo(x - 14, base + 28)
      ..lineTo(x + 14, base + 28)
      ..lineTo(x + 9, base)
      ..close();
    canvas.drawPath(robe, line);
    canvas.drawRect(Rect.fromLTWH(x - 7, base - 22, 14, 24), line);
    canvas.drawCircle(Offset(x, base - 32), 10, line);
    for (int i = -1; i <= 1; i++) {
      canvas.drawLine(Offset(x + i * 5, base - 41),
          Offset(x + i * 5, base - 54), line);
    }
    canvas.drawLine(Offset(x + 7, base - 14), Offset(x + 24, base - 30), line);
    canvas.drawLine(Offset(x + 24, base - 30), Offset(x + 24, base - 45), line);
    canvas.drawCircle(Offset(x + 24, base - 49), 5, line);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Wave clipper ──────────────────────────────────────────────────────────────

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(w - 50, 0)
      ..cubicTo(w + 15, h * 0.12, w - 55, h * 0.38, w - 20, h * 0.50)
      ..cubicTo(w + 35, h * 0.62, w - 45, h * 0.88, w - 50, h)
      ..lineTo(0, h)
      ..close();
  }
  @override
  bool shouldReclip(_) => false;
}

// ── Form content ──────────────────────────────────────────────────────────────

class _FormContent extends StatelessWidget {
  final _LoginScreenState state;
  final bool narrowMode;
  const _FormContent({required this.state, this.narrowMode = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(narrowMode ? 28 : 48, 36, 28, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ยินดีต้อนรับ',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                      color: Color(0xFF1565C0))),
              const SizedBox(height: 4),
              Text('กรุณาเข้าสู่ระบบเพื่อดำเนินการต่อ',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 30),

              // ── Teacher / Student ─────────────────────────────────────
              _SectionBadge(label: 'ครู / นักเรียน', color: const Color(0xFFF97316)),
              const SizedBox(height: 14),
              StatefulBuilder(builder: (_, setInner) => _Field(
                ctrl: state._codeCtrl,
                label: 'รหัสผู้ใช้',
                hint: 'เช่น T270001 หรือ S270001',
                icon: Icons.badge_outlined,
                accent: const Color(0xFFF97316),
                textCaps: TextCapitalization.characters,
                onSubmit: state._loginWithCode,
                onChanged: () => setInner(() {}),
                clearBtn: state._codeCtrl.text.isNotEmpty
                    ? () { state._codeCtrl.clear(); setInner(() {}); }
                    : null,
              )),
              if (state._codeError != null) ...[
                const SizedBox(height: 8), _ErrorRow(state._codeError!),
              ],
              const SizedBox(height: 16),
              _ActionButton(
                label: 'เข้าสู่ระบบด้วยรหัส', loading: state._codeLoading,
                color: const Color(0xFFF97316), icon: Icons.person_pin_rounded,
                onPressed: state._loginWithCode,
              ),

              // ── Divider ───────────────────────────────────────────────
              const SizedBox(height: 28),
              Row(children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text('หรือ',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ]),
              const SizedBox(height: 24),

              // ── Admin ─────────────────────────────────────────────────
              _SectionBadge(label: 'ผู้ดูแลระบบ', color: const Color(0xFF1565C0)),
              const SizedBox(height: 14),
              _Field(ctrl: state._emailCtrl, label: 'อีเมล',
                  icon: Icons.email_outlined, type: TextInputType.emailAddress,
                  accent: const Color(0xFF1565C0)),
              const SizedBox(height: 12),
              _Field(ctrl: state._passCtrl, label: 'รหัสผ่าน',
                  icon: Icons.lock_outline, obscure: true,
                  accent: const Color(0xFF1565C0), onSubmit: state._login),
              if (state._error != null) ...[
                const SizedBox(height: 8), _ErrorRow(state._error!),
              ],
              const SizedBox(height: 16),
              _ActionButton(
                label: 'เข้าสู่ระบบ (Admin)', loading: state._loading,
                color: const Color(0xFF1565C0), icon: Icons.login_rounded,
                onPressed: state._login,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.30)),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? hint;
  final IconData icon;
  final TextInputType? type;
  final bool obscure;
  final Color accent;
  final TextCapitalization textCaps;
  final VoidCallback? onSubmit;
  final VoidCallback? onChanged;
  final VoidCallback? clearBtn;

  const _Field({
    required this.ctrl, required this.label, this.hint,
    required this.icon, this.type, this.obscure = false,
    required this.accent, this.textCaps = TextCapitalization.none,
    this.onSubmit, this.onChanged, this.clearBtn,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: type,
    obscureText: obscure,
    textCapitalization: textCaps,
    onChanged: onChanged != null ? (_) => onChanged!() : null,
    onSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade500),
      suffixIcon: clearBtn != null
          ? IconButton(icon: Icon(Icons.clear, size: 18, color: Colors.grey.shade400),
              onPressed: clearBtn)
          : null,
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool loading;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;
  const _ActionButton({required this.label, required this.loading, required this.color,
      required this.icon, required this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 50,
    child: ElevatedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Icon(icon, size: 18),
      label: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withOpacity(0.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        shadowColor: color.withOpacity(0.40),
      ),
    ),
  );
}

class _ErrorRow extends StatelessWidget {
  final String message;
  const _ErrorRow(this.message);
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.error_outline, size: 14, color: Colors.red),
      const SizedBox(width: 5),
      Expanded(child: Text(message,
          style: const TextStyle(color: Colors.red, fontSize: 12))),
    ]);
}
