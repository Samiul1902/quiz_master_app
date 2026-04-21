import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quiz_master_app/controllers/app_controller.dart';
import 'package:quiz_master_app/widgets/user_avatar.dart';
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
  final ImagePicker _imagePicker = ImagePicker();

  bool _isSaving = false;
  bool _removeProfileImage = false;
  String? _errorText;
  Uint8List? _selectedProfileImageBytes;
  String? _selectedProfileImageContentType;

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
      profileImageBytes: _selectedProfileImageBytes,
      profileImageContentType: _selectedProfileImageContentType,
      removeProfileImage: _removeProfileImage,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
      _errorText = error;
    });

    if (error == null) {
      setState(() {
        _selectedProfileImageBytes = null;
        _selectedProfileImageContentType = null;
        _removeProfileImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    }
  }

  Future<void> _pickProfileImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (pickedFile == null) {
      return;
    }

    final bytes = await pickedFile.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedProfileImageBytes = bytes;
      _selectedProfileImageContentType = _guessContentType(
        pickedFile.name.isNotEmpty ? pickedFile.name : pickedFile.path,
      );
      _removeProfileImage = false;
      _errorText = null;
    });
  }

  void _removeProfilePhoto() {
    setState(() {
      _selectedProfileImageBytes = null;
      _selectedProfileImageContentType = null;
      _removeProfileImage = true;
      _errorText = null;
    });
  }

  String _guessContentType(String fileName) {
    final normalized = fileName.toLowerCase();
    if (normalized.endsWith('.png')) {
      return 'image/png';
    }
    if (normalized.endsWith('.webp')) {
      return 'image/webp';
    }
    if (normalized.endsWith('.gif')) {
      return 'image/gif';
    }
    return 'image/jpeg';
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
        final previewPhotoUrl = _removeProfileImage ? '' : user.photoUrl;
        final hasProfileImage =
            _selectedProfileImageBytes != null || previewPhotoUrl.isNotEmpty;
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
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            UserAvatar(
                              name: user.name,
                              photoUrl: previewPhotoUrl,
                              imageBytes: _selectedProfileImageBytes,
                              radius: 52,
                            ),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Material(
                                color: theme.colorScheme.primary,
                                shape: const CircleBorder(),
                                child: IconButton(
                                  onPressed: _isSaving
                                      ? null
                                      : _pickProfileImage,
                                  icon: Icon(
                                    hasProfileImage
                                        ? Icons.edit_rounded
                                        : Icons.add_a_photo_rounded,
                                    color: theme.colorScheme.onPrimary,
                                    size: 20,
                                  ),
                                  tooltip: hasProfileImage
                                      ? 'Change Profile Picture'
                                      : 'Set Profile Picture',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isSaving ? null : _pickProfileImage,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: Text(
                                hasProfileImage
                                    ? 'Change Photo'
                                    : 'Set Profile Picture',
                              ),
                            ),
                            if (hasProfileImage)
                              TextButton.icon(
                                onPressed: _isSaving
                                    ? null
                                    : _removeProfilePhoto,
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('Remove Photo'),
                              ),
                          ],
                        ),
                        if (_selectedProfileImageBytes != null ||
                            _removeProfileImage) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Photo changes will be saved when you tap Save Changes.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
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
