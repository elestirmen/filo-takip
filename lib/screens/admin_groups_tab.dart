import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/admin_rules.dart';
import '../core/normalize.dart';
import '../core/strings.dart';
import '../data/backend_exception.dart';
import '../data/fleet_repository.dart';
import '../models/group_config.dart';

/// Yönetimin **Gruplar** sekmesi.
///
/// Yalnızca `groupConfigs` akışını dinler. Araç akışı 5 saniyede bir
/// güncellendiği için buraya bağlanmaz; bağlansaydı liste sürekli yeniden
/// çizilirdi. Düzenleme de ayrı bir diyalogda, kendi yerel state'iyle yapılır
/// — böylece yönetici yazarken gelen hiçbir veri metni sıfırlayamaz.
class AdminGroupsTab extends StatelessWidget {
  const AdminGroupsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final FleetRepository repository = context.read<FleetRepository>();
    return StreamBuilder<List<GroupConfig>>(
      stream: repository.groupConfigs,
      builder:
          (BuildContext context, AsyncSnapshot<List<GroupConfig>> snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final List<GroupConfig> groups = snapshot.data!;
            return Scaffold(
              body: groups.isEmpty
                  ? const _NoGroups()
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: groups.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        return _GroupRow(
                          group: groups[index],
                          allGroups: groups,
                          repository: repository,
                        );
                      },
                    ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _createGroup(context, repository, groups),
                icon: const Icon(Icons.add),
                label: const Text(Strings.adminCreateGroup),
              ),
            );
          },
    );
  }

  Future<void> _createGroup(
    BuildContext context,
    FleetRepository repository,
    List<GroupConfig> groups,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _CreateGroupDialog(groups: groups),
    );
    if (name == null) return;
    try {
      await repository.saveGroupConfig(
        GroupConfig(
          groupId: name,
          visibleGroups: const <String>[],
          showSpeed: true,
          showDriverName: true,
        ),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text(Strings.adminGroupCreated)),
      );
    } on BackendException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.allGroups,
    required this.repository,
  });

  final GroupConfig group;
  final List<GroupConfig> allGroups;
  final FleetRepository repository;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> hidden = <String>[
      if (!group.showSpeed) Strings.adminShowSpeed,
      if (!group.showDriverName) Strings.adminShowDriverName,
    ];

    return ListTile(
      leading: Icon(
        Icons.workspaces_outline,
        color: theme.colorScheme.primary,
      ),
      title: Text(group.groupId, style: theme.textTheme.titleSmall),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 2),
          Text(
            group.visibleGroups.isEmpty
                ? '${Strings.adminVisibleGroupsLabel}: —'
                : '${Strings.adminVisibleGroupsLabel}: '
                      '${formatGroupList(group.visibleGroups)}',
            style: theme.textTheme.bodySmall,
          ),
          if (hidden.isNotEmpty)
            Text(
              'Gizli: ${hidden.join(', ')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
        ],
      ),
      isThreeLine: hidden.isNotEmpty,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: Strings.adminEditGroup,
            icon: const Icon(Icons.tune),
            onPressed: () => _edit(context),
          ),
          IconButton(
            tooltip: Strings.adminDelete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final GroupConfig? updated = await showDialog<GroupConfig>(
      context: context,
      builder: (BuildContext context) => _EditGroupDialog(group: group),
    );
    if (updated == null) return;
    try {
      await repository.saveGroupConfig(updated);
      messenger.showSnackBar(
        const SnackBar(content: Text(Strings.adminGroupSaved)),
      );
    } on BackendException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    // Sayım silme anındaki son duruma göre; liste akışa bağlanmadığı için
    // buradan okunuyor.
    final int affected = vehicleCountInGroup(
      repository.latestVehicles,
      group.groupId,
    );
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text(Strings.adminDeleteGroupTitle),
        content: Text(
          '${group.groupId}\n\n${Strings.adminDeleteGroupMessage}'
          '${affected > 0 ? '\n\n$affected ${Strings.adminVehicleCountSuffix} etkilenecek.' : ''}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(Strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(Strings.adminDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repository.deleteGroup(group.groupId);
      messenger.showSnackBar(
        const SnackBar(content: Text(Strings.adminGroupDeleted)),
      );
    } on BackendException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog({required this.groups});

  final List<GroupConfig> groups;

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = normalizeGroupName(_controller.text);
    if (name.isEmpty) {
      setState(() => _error = Strings.adminGroupNameRequired);
      return;
    }
    if (!isGroupNameAvailable(name, widget.groups)) {
      setState(() => _error = Strings.adminGroupNameExists);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(Strings.adminCreateGroup),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: Strings.adminGroupNameLabel,
          hintText: Strings.adminGroupNameHint,
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(Strings.adminSave),
        ),
      ],
    );
  }
}

/// Grup düzenleme diyaloğu.
///
/// Alanlar açılışta bir kez doldurulur ve diyalog kapanana kadar yalnızca
/// kullanıcı değiştirir. Veri akışı buraya hiç ulaşmaz.
class _EditGroupDialog extends StatefulWidget {
  const _EditGroupDialog({required this.group});

  final GroupConfig group;

  @override
  State<_EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends State<_EditGroupDialog> {
  late final TextEditingController _visibleGroupsController;
  late bool _showSpeed;
  late bool _showDriverName;

  @override
  void initState() {
    super.initState();
    _visibleGroupsController = TextEditingController(
      text: formatGroupList(widget.group.visibleGroups),
    );
    _showSpeed = widget.group.showSpeed;
    _showDriverName = widget.group.showDriverName;
  }

  @override
  void dispose() {
    _visibleGroupsController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      widget.group.copyWith(
        visibleGroups: parseGroupList(_visibleGroupsController.text),
        showSpeed: _showSpeed,
        showDriverName: _showDriverName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: Text('${Strings.adminEditGroup} — ${widget.group.groupId}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _visibleGroupsController,
              decoration: const InputDecoration(
                labelText: Strings.adminVisibleGroupsLabel,
                hintText: Strings.adminVisibleGroupsHint,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              Strings.adminVisibleGroupsHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(Strings.adminShowSpeed),
              value: _showSpeed,
              onChanged: (bool value) => setState(() => _showSpeed = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(Strings.adminShowDriverName),
              value: _showDriverName,
              onChanged: (bool value) =>
                  setState(() => _showDriverName = value),
            ),
            Text(
              Strings.adminFieldVisibilityHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(Strings.adminSave),
        ),
      ],
    );
  }
}

class _NoGroups extends StatelessWidget {
  const _NoGroups();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.workspaces_outline,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(Strings.adminNoGroups, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              Strings.adminNoGroupsHint,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
