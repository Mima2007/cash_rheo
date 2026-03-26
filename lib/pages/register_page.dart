import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../main.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _register() async {
    if (_password.text != _confirmPassword.text) {
      setState(() => _error = 'Lozinke se ne poklapaju');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Lozinka mora imati minimum 6 karaktera');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await supabase.auth.signUp(email: _email.text.trim(), password: _password.text);
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFB0B0B0), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset('assets/logo.png', height: 140),
                ),
              ),
              const SizedBox(height: 32),
              const Text('REGISTRACIJA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF6FDDCE), letterSpacing: 3)),
              const SizedBox(height: 32),
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              TextField(controller: _password, decoration: const InputDecoration(labelText: 'Lozinka', prefixIcon: Icon(Icons.lock_outlined)), obscureText: true),
              const SizedBox(height: 16),
              TextField(controller: _confirmPassword, decoration: const InputDecoration(labelText: 'Potvrdite lozinku', prefixIcon: Icon(Icons.lock_outlined)), obscureText: true),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _register, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('REGISTRUJ SE'))),
              const SizedBox(height: 12),
              TextButton(onPressed: () => context.go('/login'), child: Text('Vec imate nalog? Prijavite se', style: TextStyle(color: Colors.grey[400]))),
            ],
          ),
        ),
      ),
    );
  }
}
