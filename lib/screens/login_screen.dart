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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Amber gradient background ─────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF8DC), Color(0xFFFFE082), Color(0xFFFFB300)],
              ),
            ),
          ),

          // ── Background decorations ────────────────────────────────
          Positioned(top: -50, right: -30, child: _Bubble(200, 0.13)),
          Positioned(bottom: 60, left: -50, child: _OutlineCircle(180)),
          Positioned(top: 60, left: 8,     child: _Bubble(55, 0.10)),
          const Positioned(top: 18,  left: 38, child: _DotGrid(4, 4)),
          const Positioned(bottom: 40, right: 16, child: _DotGrid(3, 4)),
          const Positioned(top: 22,   left: 14, child: _WordChip('Aa')),
          const Positioned(top: 90,   right: 18, child: _WordChip('Hello')),
          Positioned(bottom: 100, left: 14,   child: const _WordChip('Learn')),
          Positioned(bottom: 76, right: 14,   child: const _WordChip('English')),
          Positioned(top: 170,  right: 20,    child: const _ChatDotBubble()),
          Positioned(top: 192,  right: 74,    child: const _Diamond()),
          Positioned(bottom: 200, left: 80,   child: const _Diamond()),

          // ── Centered login card ───────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    elevation: 10,
                    shadowColor: Colors.amber.withOpacity(0.35),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [

                          // ── Logo ──────────────────────────────────
                          Image.asset(
                            'assets/images/logo.png',
                            width: 110, height: 110,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.school_rounded,
                                size: 80, color: Color(0xFFF97316)),
                          ),
                          const SizedBox(height: 8),
                          const Text('7J English Center',
                              style: TextStyle(fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A237E))),
                          const SizedBox(height: 4),
                          const Text('ระบบจัดการโรงเรียน',
                              style: TextStyle(fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 24),

                          // ── ครู / นักเรียน ────────────────────────
                          const _SectionBadge(
                              label: 'ครู / นักเรียน',
                              color: Color(0xFFF97316)),
                          const SizedBox(height: 12),
                          StatefulBuilder(builder: (_, setInner) => _Field(
                            ctrl: _codeCtrl,
                            label: 'รหัสผู้ใช้',
                            hint: 'เช่น T270001 หรือ S270001',
                            icon: Icons.badge_outlined,
                            accent: const Color(0xFFF97316),
                            textCaps: TextCapitalization.characters,
                            onSubmit: _loginWithCode,
                            onChanged: () => setInner(() {}),
                            clearBtn: _codeCtrl.text.isNotEmpty
                                ? () { _codeCtrl.clear(); setInner(() {}); }
                                : null,
                          )),
                          if (_codeError != null) ...[
                            const SizedBox(height: 8),
                            _ErrorRow(_codeError!),
                          ],
                          const SizedBox(height: 14),
                          _ActionButton(
                            label: 'เข้าสู่ระบบด้วยรหัส',
                            loading: _codeLoading,
                            color: const Color(0xFFF97316),
                            icon: Icons.person_pin_rounded,
                            onPressed: _loginWithCode,
                          ),

                          // ── Divider ───────────────────────────────
                          const SizedBox(height: 20),
                          Row(children: [
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('หรือ',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey.shade500)),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                          ]),
                          const SizedBox(height: 20),

                          // ── Admin ─────────────────────────────────
                          const _SectionBadge(
                              label: 'ผู้ดูแลระบบ',
                              color: Color(0xFF1565C0)),
                          const SizedBox(height: 12),
                          _Field(
                              ctrl: _emailCtrl, label: 'อีเมล',
                              icon: Icons.email_outlined,
                              type: TextInputType.emailAddress,
                              accent: const Color(0xFF1565C0)),
                          const SizedBox(height: 10),
                          _Field(
                              ctrl: _passCtrl, label: 'รหัสผ่าน',
                              icon: Icons.lock_outline, obscure: true,
                              accent: const Color(0xFF1565C0),
                              onSubmit: _login),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            _ErrorRow(_error!),
                          ],
                          const SizedBox(height: 14),
                          _ActionButton(
                            label: 'เข้าสู่ระบบ (Admin)',
                            loading: _loading,
                            color: const Color(0xFF1565C0),
                            icon: Icons.login_rounded,
                            onPressed: _login,
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Decorative background widgets ─────────────────────────────────────────────

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
      border: Border.all(color: Colors.white.withOpacity(0.20), width: 2),
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
              color: const Color(0xFFE65100).withOpacity(0.22),
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
            fontWeight: FontWeight.bold, fontSize: 13)),
  );
}

class _ChatDotBubble extends StatelessWidget {
  const _ChatDotBubble();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFF8F00).withOpacity(0.22),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE65100).withOpacity(0.35)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      _dot(), const SizedBox(width: 4), _dot(), const SizedBox(width: 4), _dot(),
    ]),
  );
  Widget _dot() => Container(
    width: 5, height: 5,
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
      width: 10, height: 10,
      decoration: BoxDecoration(
        color: const Color(0xFFFF8F00).withOpacity(0.30),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

// ── Form widgets ──────────────────────────────────────────────────────────────

class _SectionBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ),
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
          ? IconButton(
              icon: Icon(Icons.clear, size: 18, color: Colors.grey.shade400),
              onPressed: clearBtn)
          : null,
      filled: true, fillColor: Colors.grey.shade50,
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
  const _ActionButton({required this.label, required this.loading,
      required this.color, required this.icon, required this.onPressed});
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
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.error_outline, size: 14, color: Colors.red),
      const SizedBox(width: 5),
      Expanded(child: Text(message,
          style: const TextStyle(color: Colors.red, fontSize: 12))),
    ],
  );
}
