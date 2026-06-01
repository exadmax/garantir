import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/auth_service.dart';
import 'register_page.dart';

const _brand = Color(0xFF1F6E8C);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthService.errorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      await _authService.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      const silentCodes = {
        'popup-closed-by-user',
        'cancelled-popup-request',
        'web-context-cancelled',
      };
      if (silentCodes.contains(e.code)) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthService.errorMessage(e))),
        );
      }
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled') return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Erro ao entrar com Google.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao entrar com Google: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final ctrl = TextEditingController(text: _emailController.text.trim());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Redefinir senha'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'E-mail', hintText: 'seu@email.com'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar')),
        ],
      ),
    );
    final email = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || !mounted || email.isEmpty) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-mail de redefinição enviado!')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthService.errorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 64),
              // Logo
              Center(child: _GarantirMark()),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Acesse sua conta para continuar',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7785)),
                ),
              ),
              const SizedBox(height: 40),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                        if (!v.contains('@')) return 'E-mail inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Informe a senha';
                        return null;
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        child: const Text('Esqueci minha senha'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: _brand,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('ou', style: Theme.of(context).textTheme.bodySmall),
                      ),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: (_isLoading || _isGoogleLoading) ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFDDE1E7)),
                      ),
                      icon: _isGoogleLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const _GoogleIcon(),
                      label: const Text('Entrar com Google'),
                    ),
                    const SizedBox(height: 32),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('Não tem conta?', style: TextStyle(color: Color(0xFF6B7785))),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
                        ),
                        child: const Text('Cadastre-se', style: TextStyle(color: _brand, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GarantirMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: _brand,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.verified_outlined, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 10),
        const Text(
          'Garantir',
          style: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700,
            color: _brand, letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(18, 18), painter: _GooglePainter());
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final red    = Paint()..color = const Color(0xFFEA4335);
    final blue   = Paint()..color = const Color(0xFF4285F4);
    final yellow = Paint()..color = const Color(0xFFFBBC05);
    final green  = Paint()..color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromLTWH(0, 0, w, h), -2.6,  1.85, false, red  ..strokeWidth = w*0.22..style = PaintingStyle.stroke);
    canvas.drawArc(Rect.fromLTWH(0, 0, w, h), -0.75, 1.57, false, blue ..strokeWidth = w*0.22..style = PaintingStyle.stroke);
    canvas.drawArc(Rect.fromLTWH(0, 0, w, h),  0.82, 1.0,  false, yellow..strokeWidth = w*0.22..style = PaintingStyle.stroke);
    canvas.drawArc(Rect.fromLTWH(0, 0, w, h),  1.82, 0.78, false, green ..strokeWidth = w*0.22..style = PaintingStyle.stroke);
    canvas.drawLine(
      Offset(w*0.5, h*0.5), Offset(w*0.95, h*0.5),
      Paint()..color = const Color(0xFF4285F4)..strokeWidth = h*0.22..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GooglePainter old) => false;
}
