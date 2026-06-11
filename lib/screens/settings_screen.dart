import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/remote_settings.dart';
import '../services/remote_settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsService = RemoteSettingsService();
  final _smbHostController = TextEditingController();
  final _smbDomainController = TextEditingController();
  final _smbUsernameController = TextEditingController();
  final _smbPasswordController = TextEditingController();
  final _sftpHostController = TextEditingController();
  final _sftpPortController = TextEditingController(text: '22');
  final _sftpUsernameController = TextEditingController();
  final _sftpPasswordController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _smbHostController.dispose();
    _smbDomainController.dispose();
    _smbUsernameController.dispose();
    _smbPasswordController.dispose();
    _sftpHostController.dispose();
    _sftpPortController.dispose();
    _sftpUsernameController.dispose();
    _sftpPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.load();
    if (!mounted) return;

    _smbHostController.text = settings.smb.host;
    _smbDomainController.text = settings.smb.domain;
    _smbUsernameController.text = settings.smb.username;
    _smbPasswordController.text = settings.smb.password;
    _sftpHostController.text = settings.sftp.host;
    _sftpPortController.text = settings.sftp.port.toString();
    _sftpUsernameController.text = settings.sftp.username;
    _sftpPasswordController.text = settings.sftp.password;

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final sftpPort = int.tryParse(_sftpPortController.text.trim());
    if (sftpPort == null || sftpPort < 1 || sftpPort > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid SFTP port (1–65535)')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _settingsService.save(
        RemoteSettings(
          smb: SmbSettings(
            host: _smbHostController.text.trim(),
            domain: _smbDomainController.text.trim(),
            username: _smbUsernameController.text.trim(),
            password: _smbPasswordController.text,
          ),
          sftp: SftpSettings(
            host: _sftpHostController.text.trim(),
            port: sftpPort,
            username: _sftpUsernameController.text.trim(),
            password: _sftpPasswordController.text,
          ),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: _loading || _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Remote connections',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Credentials are stored locally on this device. Configure '
                  'SMB or SFTP here, then use Choose Directory on the home '
                  'screen to pick a remote folder to scan.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                _ConnectionCard(
                  title: 'SMB (Samba)',
                  icon: Icons.lan_outlined,
                  children: [
                    TextField(
                      controller: _smbHostController,
                      decoration: const InputDecoration(
                        labelText: 'Host',
                        hintText: '192.168.1.100',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _smbDomainController,
                      decoration: const InputDecoration(
                        labelText: 'Domain (optional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _smbUsernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _smbPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ConnectionCard(
                  title: 'SFTP',
                  icon: Icons.cloud_outlined,
                  children: [
                    TextField(
                      controller: _sftpHostController,
                      decoration: const InputDecoration(
                        labelText: 'Host',
                        hintText: 'example.com',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _sftpPortController,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _sftpUsernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _sftpPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
