import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'profile_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  String _storageSize = '...';

  @override
  void initState() {
    super.initState();
    _computeStorage();
  }

  Future<void> _computeStorage() async {
    final docs = await getApplicationDocumentsDirectory();
    final reposDir = Directory('${docs.path}/repos');
    if (!reposDir.existsSync()) {
      setState(() => _storageSize = '0 MB');
      return;
    }
    int bytes = 0;
    reposDir.listSync(recursive: true).whereType<File>().forEach((f) {
      try {
        bytes += f.statSync().size;
      } catch (_) {}
    });
    final mb = bytes / (1024 * 1024);
    setState(() => _storageSize = '${mb.toStringAsFixed(1)} MB');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.userProfile;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Account section
          _SectionHeader('Account'),
          if (profile != null)
            ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(profile.avatarUrl),
              ),
              title: Text(profile.name ?? profile.login),
              subtitle: Text('@${profile.login}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProfileView(profile: profile)),
              ),
            )
          else
            const ListTile(
              leading: Icon(Icons.account_circle_outlined),
              title: Text('Not signed in'),
            ),
          const Divider(),
          // Storage section
          _SectionHeader('Storage'),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Cloned Repositories'),
            trailing: Text(_storageSize),
          ),
          const Divider(),
          // App info
          _SectionHeader('App'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            trailing: Text('0.6.0'),
          ),
          const Divider(),
          // Sign out
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Sign Out',
              style:
                  TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _confirmSignOut(context, auth),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text(
            'Your local repos will remain on the device. You can re-authenticate anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(context);
              auth.logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
