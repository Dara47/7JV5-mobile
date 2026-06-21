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
              const ColoredBox(color: Color(0xFFF4F6FA)),
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
          color: const Color(0xFFF4F6FA),
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2A4A), Color(0xFF1E3A5F), Color(0xFF2A5298)],
        ),
      ),
      child: Stack(children: [
        // Decorative bubbles
        Positioned(top: -70, right: 20,   child: _Bubble(220, 0.07)),
        Positioned(bottom: -60, left: -30, child: _Bubble(240, 0.06)),
        Positioned(top: 80,    left: 30,   child: _Bubble(70,  0.10)),
        Positioned.fill(child: Align(alignment: Alignment.center, child: _Bubble(380, 0.04))),
        // Content
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                    border: Border.all(color: Colors.white.withOpacity(0.30), width: 2),
                  ),
                  child: const Icon(Icons.school_rounded, size: 52, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text('7J English',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text('ระบบจัดการโรงเรียน',
                    style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.80),
                        letterSpacing: 0.3)),
                if (showFeatures) ...[
                  const SizedBox(height: 44),
                  const _FeaturePill(Icons.people_outline,         'จัดการนักเรียนและครู'),
                  const SizedBox(height: 12),
                  const _FeaturePill(Icons.calendar_month_outlined, 'ตารางเรียนออนไลน์'),
                  const SizedBox(height: 12),
                  const _FeaturePill(Icons.content_cut_outlined,    'ตัดและติดตามคาบเรียน'),
                  const SizedBox(height: 12),
                  const _FeaturePill(Icons.bar_chart_outlined,      'รายงานสรุปผล'),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

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

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(32),
      border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: Colors.white),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 13,
          fontWeight: FontWeight.w500)),
    ]),
  );
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
                      color: Color(0xFF0F2A4A))),
              const SizedBox(height: 4),
              Text('กรุณาเข้าสู่ระบบเพื่อดำเนินการต่อ',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 30),

              // ── Teacher / Student ─────────────────────────────────────
              _SectionBadge(label: 'ครู / นักเรียน', color: const Color(0xFF2E7D32)),
              const SizedBox(height: 14),
              StatefulBuilder(builder: (_, setInner) => _Field(
                ctrl: state._codeCtrl,
                label: 'รหัสผู้ใช้',
                hint: 'เช่น T270001 หรือ S270001',
                icon: Icons.badge_outlined,
                accent: const Color(0xFF2E7D32),
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
                color: const Color(0xFF2E7D32), icon: Icons.person_pin_rounded,
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
              _SectionBadge(label: 'ผู้ดูแลระบบ', color: const Color(0xFF1E3A5F)),
              const SizedBox(height: 14),
              _Field(ctrl: state._emailCtrl, label: 'อีเมล',
                  icon: Icons.email_outlined, type: TextInputType.emailAddress,
                  accent: const Color(0xFF1E3A5F)),
              const SizedBox(height: 12),
              _Field(ctrl: state._passCtrl, label: 'รหัสผ่าน',
                  icon: Icons.lock_outline, obscure: true,
                  accent: const Color(0xFF1E3A5F), onSubmit: state._login),
              if (state._error != null) ...[
                const SizedBox(height: 8), _ErrorRow(state._error!),
              ],
              const SizedBox(height: 16),
              _ActionButton(
                label: 'เข้าสู่ระบบ (Admin)', loading: state._loading,
                color: const Color(0xFF1E3A5F), icon: Icons.login_rounded,
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
