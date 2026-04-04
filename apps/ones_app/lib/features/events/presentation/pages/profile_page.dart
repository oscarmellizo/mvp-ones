import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_card.dart';
import '../../../../core/ui/widgets/ones_text_field.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../admin/presentation/pages/admin_home_page.dart';

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

    final stored = auth.preferredName;
    if (stored != null && stored.trim().isNotEmpty) {
      _preferredNameController.text = stored.trim();
      return;
    }

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
    final pictureUrl = user?.pictureUrl;
    final parts = _splitDisplayName(displayName);
    final firstName = parts.$1;
    final lastName = parts.$2;

    return Scaffold(
      backgroundColor: OnesColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user == null)
                OnesCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No authenticated user.',
                    style: TextStyle(color: OnesColors.black.withOpacity(0.6)),
                  ),
                )
              else ...[
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: OnesColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: (pictureUrl != null && pictureUrl.isNotEmpty)
                          ? Image.network(
                              pictureUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, __) => const Center(
                                child: Icon(
                                  Icons.person,
                                  size: 44,
                                  color: Colors.black54,
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.person,
                                size: 44,
                                color: Colors.black54,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _Card(
                  title: 'Account',
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _ReadOnlyField(
                            label: 'First name',
                            value: firstName,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ReadOnlyField(
                            label: 'Last name',
                            value: lastName,
                          ),
                        ),
                      ],
                    ),
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
                    OnesTextField(
                      controller: _preferredNameController,
                      hintText: 'Preferred name',
                      fillColor: OnesColors.yellowLight.withOpacity(0.35),
                      borderSide: BorderSide.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This name is used to indicate which are your photos.',
                      style: TextStyle(
                        color: OnesColors.black.withOpacity(0.55),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: OnesColors.purpleMid,
                          foregroundColor: OnesColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: auth.isLoading
                            ? null
                            : () async {
                                final value =
                                    _preferredNameController.text.trim();
                                FocusScope.of(context).unfocus();
                                try {
                                  await auth.savePreferredName(value);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        value.isEmpty
                                            ? 'Preferences saved.'
                                            : 'Preferences saved: $value',
                                      ),
                                    ),
                                  );
                                } catch (_) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Could not save preferences.'),
                                    ),
                                  );
                                }
                              },
                        child: const Text(
                          'Save preferences',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
                if (auth.isAdmin) ...[
                  const SizedBox(height: 14),
                  _Card(
                    title: 'Admin',
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: OnesColors.purpleMid,
                            foregroundColor: OnesColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          onPressed: auth.isLoading
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const AdminHomePage(),
                                    ),
                                  );
                                },
                          child: const Text(
                            'Open Admin',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: OnesColors.purpleMid,
                    foregroundColor: OnesColors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
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
    return OnesCard(
      padding: const EdgeInsets.all(14),
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
    final v = value.isEmpty ? '-' : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: OnesColors.black.withOpacity(0.55),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          v,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: OnesColors.black,
          ),
        ),
      ],
    );
  }
}
