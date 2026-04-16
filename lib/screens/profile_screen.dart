import 'package:flutter/material.dart';
import 'package:quiz_master_app/controllers/app_controller.dart';
import 'package:quiz_master_app/widgets/progress_visualization.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _organizationController;
  late final TextEditingController _departmentController;
  late final TextEditingController _bioController;

  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final user = widget.controller.currentUser!;
    _nameController = TextEditingController(text: user.name);
    _phoneController = TextEditingController(text: user.phone);
    _organizationController = TextEditingController(text: user.organization);
    _departmentController = TextEditingController(text: user.department);
    _bioController = TextEditingController(text: user.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _organizationController.dispose();
    _departmentController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final error = await widget.controller.updateCurrentUserProfile(
      name: _nameController.text,
      phone: _phoneController.text,
      organization: _organizationController.text,
      department: _departmentController.text,
      bio: _bioController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
      _errorText = error;
    });

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final user = widget.controller.currentUser!;
        final isAdmin = user.isAdmin;
        final roleLabel = isAdmin ? 'Admin Account' : 'Student Account';
        final organizationLabel = isAdmin ? 'Organization' : 'Institution';
        final attempts = isAdmin
            ? widget.controller.attempts
            : widget.controller.attemptsForUser(user.id);
        final progressSummary = attempts.isEmpty
            ? null
            : ProgressSummary.fromAttempts(attempts);

        return Scaffold(
          appBar: AppBar(title: const Text('My Profile')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          child: Text(
                            user.name.isEmpty
                                ? '?'
                                : user.name.substring(0, 1).toUpperCase(),
                            style: theme.textTheme.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          user.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            Chip(
                              avatar: Icon(
                                isAdmin
                                    ? Icons.admin_panel_settings_rounded
                                    : Icons.school_rounded,
                              ),
                              label: Text(roleLabel),
                            ),
                            Chip(
                              avatar: const Icon(Icons.email_outlined),
                              label: Text(user.email),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _ProfileSection(
                  title: 'Profile Details',
                  subtitle:
                      'Keep your account information updated for a better experience.',
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _organizationController,
                        decoration: InputDecoration(
                          labelText: organizationLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _departmentController,
                        decoration: const InputDecoration(
                          labelText: 'Department / Group',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bioController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Bio',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _errorText!,
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _saveProfile,
                          icon: const Icon(Icons.save_rounded),
                          label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _ProfileSection(
                  title: isAdmin
                      ? 'System Progress Snapshot'
                      : 'My Progress Snapshot',
                  subtitle: isAdmin
                      ? 'Quick visualization of overall student performance across the platform.'
                      : 'Quick visualization of your exam and practice progress.',
                  child: progressSummary == null
                      ? const Text('No progress data available yet.')
                      : ProgressVisualization(
                          summary: progressSummary,
                          primaryMetricLabel: isAdmin ? 'Students' : 'Attempts',
                          primaryMetricValue: isAdmin
                              ? '${widget.controller.studentUsers.length}'
                              : null,
                          primaryMetricIcon: isAdmin
                              ? Icons.people_alt_rounded
                              : Icons.assignment_turned_in_rounded,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
