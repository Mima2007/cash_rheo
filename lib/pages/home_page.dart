import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../main.dart';
import '../services/auth_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFB0B0B0), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset('assets/logo.png', height: 200),
                ),
              ),
              if (AuthService.userEmail != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    AuthService.userEmail!,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ),
              const Spacer(),
              _buildButton(context, Icons.qr_code_scanner, 'SKENIRAJ QR', 'Fiskalni racun', () => context.go('/qr-scan')),
              const SizedBox(height: 16),
              _buildButton(context, Icons.camera_alt_outlined, 'USLIKAJ', 'Ugovor, otpremnica...', () => context.go('/document-scan')),
              const SizedBox(height: 40),
              TextButton.icon(
                onPressed: () async {
                  if (AuthService.isB2C) {
                    await AuthService.signOut();
                  } else {
                    await supabase.auth.signOut();
                  }
                  if (context.mounted) context.go('/login');
                },
                icon: Icon(Icons.logout, color: Colors.grey[600]),
                label: Text('Odjavi se', style: TextStyle(color: Colors.grey[600])),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: const Color(0xFF6FDDCE),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF6FDDCE), size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E), letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF2C2C2E))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
