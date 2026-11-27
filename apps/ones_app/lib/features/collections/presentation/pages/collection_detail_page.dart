import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/i18n/translations_service.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../../features/auth/presentation/auth_controller.dart';
import '../../domain/collection.dart';
import '../collections_controller.dart';
import '../widgets/collection_photos_tab.dart';

class CollectionDetailPage extends StatefulWidget {
  final OnesCollection collection;

  const CollectionDetailPage({super.key, required this.collection});

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  late Future<List<CollectionMember>> _members;

  @override
  void initState() {
    super.initState();
    _members =
        context.read<CollectionsController>().members(widget.collection.id);
  }

  Future<void> _refreshMembers() async {
    setState(() {
      _members =
          context.read<CollectionsController>().members(widget.collection.id);
    });
    await _members;
  }

  Future<void> _manageMember(CollectionMember member, String action) async {
    final controller = context.read<CollectionsController>();
    if (action == 'remove') {
      try {
        await controller.removeMember(widget.collection.id, member.memberKey);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo quitar a la persona: $error')),
          );
        }
        return;
      }
      if (!mounted) return;
      try {
        await _refreshMembers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Se quitó a la persona de la colección.'),
            ),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'La persona se quitó, pero no se pudo actualizar la lista: $error',
              ),
            ),
          );
        }
      }
      return;
    }
    final userId = member.userId;
    if (userId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Transferir propiedad'),
        content: const Text(
            'La otra persona será la propietaria de esta colección.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Transferir'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await controller.transferOwnership(widget.collection.id, userId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _invite() async {
    final t = context.read<TranslationsService>();
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.translate('collections.invite', fallback: 'Invitar')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: t.translate('common.email', fallback: 'Correo'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.translate('common.cancel', fallback: 'Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(t.translate('collections.send_invite',
                fallback: 'Enviar invitación')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.trim().isEmpty || !mounted) return;
    try {
      await context
          .read<CollectionsController>()
          .invite(widget.collection.id, [email.trim()]);
      await _refreshMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.translate(
              'collections.invitation_sent',
              fallback: 'Invitación enviada.',
            )),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _showQr() async {
    final controller = context.read<CollectionsController>();
    final t = context.read<TranslationsService>();
    try {
      final url = await controller.rotateJoinQr(widget.collection.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.translate(
            'collections.join_qr',
            fallback: 'QR para unirse',
          )),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: url,
                size: 220,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: OnesColors.purpleDeep,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: OnesColors.purpleDeep,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(url, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                t.translate(
                  'collections.qr_rotates',
                  fallback:
                      'Este enlace se activa al generarlo y deja de servir cuando lo rotes o desactives.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.translate('common.close', fallback: 'Cerrar')),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TranslationsService>();
    final auth = context.watch<AuthController>();
    final collection = widget.collection;
    final isOwner = collection.ownerId == auth.user?.userId;
    final canInvite = collection.type != CollectionType.private;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: OnesColors.surfaceWarm,
        appBar: AppBar(
          title: Text(collection.name),
          actions: [
            if (canInvite && !collection.isLifeCollection)
              IconButton(
                onPressed: _showQr,
                tooltip: t.translate('collections.join_qr', fallback: 'QR'),
                icon: const Icon(Icons.qr_code_2),
              ),
            if (canInvite)
              IconButton(
                onPressed: _invite,
                tooltip: t.translate('collections.invite', fallback: 'Invitar'),
                icon: const Icon(Icons.person_add_alt_1),
              ),
            if (isOwner && !collection.isLifeCollection)
              IconButton(
                onPressed: _deleteCollection,
                tooltip: t.translate('common.delete', fallback: 'Eliminar'),
                icon: const Icon(Icons.delete_outline),
              ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: t.translate('collections.photos', fallback: 'Fotos')),
              Tab(
                  text:
                      t.translate('collections.members', fallback: 'Personas')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            CollectionPhotosTab(collection: collection),
            FutureBuilder<List<CollectionMember>>(
              future: _members,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton(
                      onPressed: _refreshMembers,
                      child: Text(t.translate(
                        'common.retry',
                        fallback: 'Reintentar',
                      )),
                    ),
                  );
                }
                final members = snapshot.data ?? const <CollectionMember>[];
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _MemberTile(
                      title: t.translate(
                        'collections.owner',
                        fallback: 'Propietario',
                      ),
                      subtitle: isOwner
                          ? t.translate('common.you', fallback: 'Tú')
                          : null,
                      icon: Icons.workspace_premium_outlined,
                    ),
                    ...members
                        .where((member) => member.userId != collection.ownerId)
                        .map((member) {
                      final pending = member.status == 'PENDING';
                      final isSelf = member.userId == auth.user?.userId;
                      return _MemberTile(
                        title: member.email ??
                            member.userId ??
                            t.translate('collections.member',
                                fallback: 'Miembro'),
                        subtitle: pending
                            ? t.translate(
                                'collections.pending',
                                fallback: 'Invitación pendiente',
                              )
                            : t.translate(
                                'collections.administrator',
                                fallback: 'Administra esta colección',
                              ),
                        icon: pending
                            ? Icons.hourglass_empty
                            : Icons.person_outline,
                        trailing: isOwner && !isSelf
                            ? PopupMenuButton<String>(
                                onSelected: (action) =>
                                    _manageMember(member, action),
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Quitar persona'),
                                  ),
                                  if (!pending && member.userId != null)
                                    const PopupMenuItem(
                                      value: 'transfer',
                                      child: Text('Transferir propiedad'),
                                    ),
                                ],
                              )
                            : null,
                      );
                    }),
                    if (canInvite)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: OutlinedButton.icon(
                          onPressed: _invite,
                          icon: const Icon(Icons.person_add_alt_1),
                          label: Text(t.translate(
                            'collections.invite',
                            fallback: 'Invitar personas',
                          )),
                        ),
                      ),
                    if (!isOwner)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton.icon(
                          onPressed: () async {
                            await context
                                .read<CollectionsController>()
                                .leave(collection.id);
                            if (context.mounted) Navigator.pop(context);
                          },
                          icon: const Icon(Icons.logout),
                          label: Text(t.translate(
                            'collections.leave',
                            fallback: 'Salir de la colección',
                          )),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCollection() async {
    final t = context.read<TranslationsService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.translate(
          'collections.delete_title',
          fallback: 'Eliminar colección',
        )),
        content: Text(t.translate(
          'collections.delete_confirmation',
          fallback:
              'Se revocará el acceso de inmediato y las fotos se eliminarán definitivamente. Esta acción no se puede deshacer.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.translate('common.cancel', fallback: 'Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.translate('common.delete', fallback: 'Eliminar')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await context.read<CollectionsController>().delete(widget.collection.id);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }
}

class _MemberTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? trailing;

  const _MemberTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: OnesColors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: OnesColors.purpleMid.withValues(alpha: .12),
          child: Icon(icon, color: OnesColors.purpleMid),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: trailing,
      ),
    );
  }
}
