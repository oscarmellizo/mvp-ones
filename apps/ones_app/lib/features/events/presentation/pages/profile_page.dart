import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/auth_controller.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _preferredNameController = TextEditingController();

  String? _seedUserId;

  @override
  void dispose() {
    _preferredNameController.dispose();
    super.dispose();
  }

  void _seedPreferredNameIfNeeded(AuthController auth) {
    final user = auth.user;
    if (user == null) return;

    if (_seedUserId == user.userId) return;
    _seedUserId = user.userId;

    final parts = _splitDisplayName(user.displayName);
    final first = parts.$1;
    _preferredNameController.text = first.isNotEmpty ? first : 'Guest';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    _seedPreferredNameIfNeeded(auth);

    final user = auth.user;
    final displayName = user?.displayName;
    final email = user?.email;
    final parts = _splitDisplayName(displayName);
    final firstName = parts.$1;
    final lastName = parts.$2;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              if (user == null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'No authenticated user.',
                    style: TextStyle(color: Colors.black.withOpacity(0.6)),
                  ),
                )
              else ...[
                _Card(
                  title: 'Account',
                  children: [
                    _ReadOnlyField(label: 'First name', value: firstName),
                    const SizedBox(height: 12),
                    _ReadOnlyField(label: 'Last name', value: lastName),
                    const SizedBox(height: 12),
                    _ReadOnlyField(label: 'Email', value: email ?? ''),
                  ],
                ),
                const SizedBox(height: 14),
                _Card(
                  title: 'Preferences',
                  children: [
                    const Text(
                      'How do you like to be called?',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _preferredNameController,
                      decoration: InputDecoration(
                        hintText: 'Preferred name',
                        filled: true,
                        fillColor: const Color(0xFFF7F3EA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This is only used for how the app addresses you.',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.55),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6A0D73),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: auth.isLoading ? null : () => auth.logout(),
                  child: auth.isLoading
                      ? const Text('Signing out...')
                      : const Text(
                          'Logout',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

(String, String) _splitDisplayName(String? displayName) {
  final dn = (displayName ?? '').trim();
  if (dn.isEmpty) return ('', '');
  final parts = dn.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return ('', '');
  if (parts.length == 1) return (parts[0], '');
  return (parts.first, parts.sublist(1).join(' '));
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Card({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.black.withOpacity(0.55),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F3EA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
