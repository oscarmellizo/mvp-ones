import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_card.dart';
import '../../../../core/ui/widgets/ones_text_field.dart';
import '../auth_controller.dart';

class RegisterPage extends StatefulWidget {
  final bool popToRootOnComplete;

  const RegisterPage({
    super.key,
    this.popToRootOnComplete = true,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _preferredNameController =
      TextEditingController();
  bool _showValidation = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthController>();
      final seed =
          auth.preferredName ?? _guessPreferredName(auth.user?.displayName);
      if (seed != null && seed.trim().isNotEmpty) {
        _preferredNameController.text = seed.trim();
      }
    });
  }

  @override
  void dispose() {
    _preferredNameController.dispose();
    super.dispose();
  }

  String? _guessPreferredName(String? displayName) {
    if (displayName == null) return null;
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return null;
    return parts.first;
  }

  ({String firstName, String lastName}) _splitDisplayName(String? displayName) {
    final safe = (displayName ?? '').trim();
    if (safe.isEmpty) {
      return (firstName: '', lastName: '');
    }

    final parts =
        safe.split(RegExp(r'\s+')).where((p) => p.trim().isNotEmpty).toList();
    if (parts.isEmpty) {
      return (firstName: '', lastName: '');
    }
    if (parts.length == 1) {
      return (firstName: parts.first, lastName: '');
    }
    return (firstName: parts.first, lastName: parts.sublist(1).join(' '));
  }

  String? _preferredNameError() {
    if (!_showValidation) return null;
    if (_preferredNameController.text.trim().isEmpty) {
      return 'Preferred name is required.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    final size = MediaQuery.sizeOf(context);
    final horizontalPadding = size.width >= 520 ? 32.0 : 20.0;

    final user = auth.user;
    final split = _splitDisplayName(user?.displayName);
    final email = user?.email ?? '';
    final preferredNameError = _preferredNameError();

    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(
        backgroundColor: OnesColors.background,
        elevation: 0,
        foregroundColor: OnesColors.black,
        title: const Text('Create your account'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Register',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: OnesColors.black,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Use your Google account to create your Ones profile.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: OnesColors.black.withOpacity(0.7),
                          height: 1.3,
                        ),
                  ),
                  const SizedBox(height: 20),
                  if (auth.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: OnesColors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Text(
                        'Error: ${auth.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: OnesColors.danger),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  OnesCard(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (user == null) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : () async {
                                      final step =
                                          await auth.beginRegistration();
                                      if (!context.mounted) return;
                                      if (step == AuthNextStep.failed) {
                                        return;
                                      }
                                      setState(() {
                                        _showValidation = false;
                                      });
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: OnesColors.white,
                                foregroundColor: OnesColors.black,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                auth.isLoading
                                    ? 'Connecting...'
                                    : 'Continue with Google',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ] else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: OnesColors.yellowLight,
                                backgroundImage: (user.pictureUrl != null &&
                                        user.pictureUrl!.trim().isNotEmpty)
                                    ? NetworkImage(user.pictureUrl!)
                                    : null,
                                child: (user.pictureUrl == null ||
                                        user.pictureUrl!.trim().isEmpty)
                                    ? const Icon(Icons.person,
                                        color: OnesColors.black)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: OnesColors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (split.firstName.isNotEmpty)
                                      Text(
                                        'Name: ${split.firstName}',
                                        style: TextStyle(
                                          color: OnesColors.black
                                              .withOpacity(0.70),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    if (split.lastName.isNotEmpty)
                                      Text(
                                        'Last name: ${split.lastName}',
                                        style: TextStyle(
                                          color: OnesColors.black
                                              .withOpacity(0.70),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Preferred name',
                            style: TextStyle(
                              color: OnesColors.black,
                              fontWeight: FontWeight.w800,
                            ),
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
                            onChanged: (_) {
                              if (_showValidation) setState(() {});
                            },
                            textInputAction: TextInputAction.done,
                          ),
                          if (preferredNameError != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              preferredNameError,
                              style: const TextStyle(
                                color: OnesColors.danger,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 6),
                            Text(
                              'This name is used to identify your photos.',
                              style: TextStyle(
                                color: OnesColors.black.withOpacity(0.55),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: OnesColors.purpleMid,
                                foregroundColor: OnesColors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                              onPressed: auth.isLoading
                                  ? null
                                  : () async {
                                      setState(() {
                                        _showValidation = true;
                                      });
                                      if (_preferredNameController.text
                                          .trim()
                                          .isEmpty) {
                                        return;
                                      }

                                      FocusScope.of(context).unfocus();
                                      try {
                                        await auth.completeRegistration(
                                          _preferredNameController.text,
                                        );
                                        if (!context.mounted) return;
                                        if (widget.popToRootOnComplete) {
                                          Navigator.of(context)
                                              .popUntil((r) => r.isFirst);
                                        } else {
                                          Navigator.of(context).pop(true);
                                        }
                                      } catch (_) {
                                        if (!context.mounted) return;
                                      }
                                    },
                              child: Text(
                                auth.isLoading
                                    ? 'Creating account...'
                                    : 'Create account',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
