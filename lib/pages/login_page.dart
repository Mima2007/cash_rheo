import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      await supabase.auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error = 'Pogresan email ili lozinka');
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
                  child: Image.asset('assets/logo.png', height: 180),
                ),
              ),
              const SizedBox(height: 48),
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              TextField(controller: _password, decoration: const InputDecoration(labelText: 'Lozinka', prefixIcon: Icon(Icons.lock_outlined)), obscureText: true),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _login, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('PRIJAVI SE'))),
              const SizedBox(height: 12),
              TextButton(onPressed: () => context.go('/register'), child: Text('Nemate nalog? Registrujte se', style: TextStyle(color: Colors.grey[400]))),
            ],
          ),
        ),
      ),
    );
  }
}
