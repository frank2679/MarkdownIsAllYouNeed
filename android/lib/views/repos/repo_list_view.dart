import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/repo_provider.dart';
import '../../providers/file_tree_provider.dart';
import '../files/file_tree_view.dart';
import 'repo_row_view.dart';

class RepoListView extends StatefulWidget {
  const RepoListView({super.key});

  @override
  State<RepoListView> createState() => _RepoListViewState();
}

class _RepoListViewState extends State<RepoListView> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final token = await auth.token;
    if (token != null) {
      await context.read<RepoProvider>().loadRepos(token);
    }
  }

  Future<void> _openRepo(BuildContext context, Repository repo) async {
    final auth = context.read<AuthProvider>();
    final token = await auth.token;
    if (token == null) return;

    final fileTree = context.read<FileTreeProvider>();
    await fileTree.open(repo, token);

    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: fileTree,
        child: FileTreeView(repo: repo),
      ),
    ));
  }

  Future<void> _cloneRepo(BuildContext context, Repository repo) async {
    final auth = context.read<AuthProvider>();
    final token = await auth.token;
    if (token == null) return;

    await context.read<RepoProvider>().clone(repo, token);
  }

  @override
  Widget build(BuildContext context) {
    final repos = context.watch<RepoProvider>();
    final cloned = repos.clonedRepos;
    final all = repos.allRepos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repositories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: repos.isLoading ? null : _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search repositories...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (v) => repos.searchText = v,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          if (repos.isLoading && all.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (repos.error != null && all.isEmpty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(repos.error!),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else
            RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  if (cloned.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: _SectionHeader(title: 'Cloned'),
                    ),
                    SliverList.builder(
                      itemCount: cloned.length,
                      itemBuilder: (_, i) => _repoTile(
                        context,
                        cloned[i],
                        isCloned: true,
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(
                    child: _SectionHeader(title: 'All Repositories'),
                  ),
                  SliverList.builder(
                    itemCount: all.length,
                    itemBuilder: (_, i) => _repoTile(
                      context,
                      all[i],
                      isCloned: cloned.any((r) => r.id == all[i].id),
                    ),
                  ),
                ],
              ),
            ),
          // Clone progress overlay
          if (repos.isCloning)
            Container(
              color: Colors.black45,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(repos.cloneProgress),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _repoTile(BuildContext context, Repository repo,
      {required bool isCloned}) {
    return Dismissible(
      key: ValueKey('repo-${repo.id}'),
      direction: isCloned ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete local copy?'),
            content: Text(
                'This will remove the local copy of "${repo.name}". Remote data is unaffected.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => context.read<RepoProvider>().deleteLocal(repo),
      child: ListTile(
        title: RepoRowView(repo: repo, isCloned: isCloned),
        onTap: isCloned
            ? () => _openRepo(context, repo)
            : () => _showCloneDialog(context, repo),
        trailing: isCloned
            ? const Icon(Icons.chevron_right)
            : IconButton(
                icon: const Icon(Icons.download_outlined),
                onPressed: () => _showCloneDialog(context, repo),
              ),
      ),
    );
  }

  void _showCloneDialog(BuildContext context, Repository repo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clone Repository'),
        content: Text('Clone "${repo.fullName}" to your device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _cloneRepo(context, repo);
            },
            child: const Text('Clone'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

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
