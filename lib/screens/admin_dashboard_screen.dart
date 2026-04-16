import 'package:flutter/material.dart';
import 'package:quiz_master_app/controllers/app_controller.dart';
import 'package:quiz_master_app/models/exam_settings.dart';
import 'package:quiz_master_app/models/question_model.dart';
import 'package:quiz_master_app/screens/profile_screen.dart';
import 'package:quiz_master_app/widgets/progress_visualization.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _countController;
  late final TextEditingController _timeController;
  late final TextEditingController _attemptLimitController;

  late bool _practiceEnabled;
  late bool _showExamReview;
  late bool _showAnswersInPractice;
  late bool _shuffleQuestions;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.settings;
    _titleController = TextEditingController(text: settings.examTitle);
    _countController = TextEditingController(
      text: settings.questionCount.toString(),
    );
    _timeController = TextEditingController(
      text: settings.examDurationMinutes.toString(),
    );
    _attemptLimitController = TextEditingController(
      text: settings.maxExamAttemptsPerStudent.toString(),
    );
    _practiceEnabled = settings.practiceEnabled;
    _showExamReview = settings.showExamReview;
    _showAnswersInPractice = settings.showAnswersInPractice;
    _shuffleQuestions = settings.shuffleQuestions;
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(controller: widget.controller),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _countController.dispose();
    _timeController.dispose();
    _attemptLimitController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final questionCount = int.tryParse(_countController.text) ?? 5;
    final examDurationMinutes = int.tryParse(_timeController.text) ?? 10;
    final attemptLimit = int.tryParse(_attemptLimitController.text) ?? 0;

    final settings = ExamSettings(
      examVersion: widget.controller.settings.examVersion,
      examTitle: _titleController.text.trim().isEmpty
          ? 'Weekly Mock Exam'
          : _titleController.text.trim(),
      questionCount: questionCount,
      examDurationMinutes: examDurationMinutes,
      showExamReview: _showExamReview,
      maxExamAttemptsPerStudent: attemptLimit,
      practiceEnabled: _practiceEnabled,
      showAnswersInPractice: _showAnswersInPractice,
      shuffleQuestions: _shuffleQuestions,
    );

    await widget.controller.updateSettings(settings);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Admin settings updated.')));
  }

  Future<void> _showAddQuestionDialog() async {
    final subjectController = TextEditingController();
    final questionController = TextEditingController();
    final explanationController = TextEditingController();
    final optionControllers = List.generate(4, (_) => TextEditingController());
    int correctIndex = 0;

    final question = await showDialog<QuestionModel>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Question'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(labelText: 'Subject'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: questionController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Question'),
                    ),
                    const SizedBox(height: 12),
                    for (int i = 0; i < 4; i++) ...[
                      TextField(
                        controller: optionControllers[i],
                        decoration: InputDecoration(
                          labelText: 'Option ${i + 1}',
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    DropdownButtonFormField<int>(
                      initialValue: correctIndex,
                      decoration: const InputDecoration(
                        labelText: 'Correct Option',
                      ),
                      items: List.generate(
                        4,
                        (index) => DropdownMenuItem(
                          value: index,
                          child: Text('Option ${index + 1}'),
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          correctIndex = value ?? 0;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: explanationController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Explanation',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (subjectController.text.trim().isEmpty ||
                        questionController.text.trim().isEmpty ||
                        optionControllers.any(
                          (controller) => controller.text.trim().isEmpty,
                        )) {
                      return;
                    }

                    Navigator.pop(
                      context,
                      QuestionModel(
                        id: 'q-${DateTime.now().millisecondsSinceEpoch}',
                        subject: subjectController.text.trim(),
                        question: questionController.text.trim(),
                        options: optionControllers
                            .map((controller) => controller.text.trim())
                            .toList(),
                        correctAnswerIndex: correctIndex,
                        explanation: explanationController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    for (final controller in optionControllers) {
      controller.dispose();
    }
    subjectController.dispose();
    questionController.dispose();
    explanationController.dispose();

    if (question == null) {
      return;
    }

    final error = await widget.controller.addQuestion(question);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Question added successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final leaderboard = controller.leaderboard.take(8).toList();
    final students = controller.studentUsers;
    final adminCount = controller.users.where((user) => user.isAdmin).length;
    final progressSummary = controller.attempts.isEmpty
        ? null
        : ProgressSummary.fromAttempts(controller.attempts);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: _openProfile,
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Profile',
          ),
          TextButton.icon(
            onPressed: controller.logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _SummaryCard(
                  title: 'Students',
                  value: '${students.length}',
                  icon: Icons.school_rounded,
                ),
                _SummaryCard(
                  title: 'Admins',
                  value: '$adminCount',
                  icon: Icons.admin_panel_settings_rounded,
                ),
                _SummaryCard(
                  title: 'Questions',
                  value: '${controller.questions.length}',
                  icon: Icons.help_center_rounded,
                ),
                _SummaryCard(
                  title: 'Exam Attempts',
                  value: '${controller.totalClientAttempts}',
                  icon: Icons.leaderboard_rounded,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Platform Progress Visualization',
              subtitle:
                  'See overall student performance and subject trends across the whole system.',
              child: progressSummary == null
                  ? const Text('No exam or practice attempts yet.')
                  : ProgressVisualization(
                      summary: progressSummary,
                      primaryMetricLabel: 'Students',
                      primaryMetricValue: '${students.length}',
                      primaryMetricIcon: Icons.school_rounded,
                    ),
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Exam Controls',
              subtitle:
                  'Admin can change question quantity, review visibility, attempt limit, and other important settings here. Saving any change starts a new exam cycle and resets current exam attempt counters.',
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Exam Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _countController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Question Quantity',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _timeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Exam Duration (Minutes)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _attemptLimitController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Exam Attempts Per Student',
                      hintText: '0 means unlimited',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _practiceEnabled,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Allow Practice Mode'),
                    onChanged: (value) {
                      setState(() {
                        _practiceEnabled = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    value: _showExamReview,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Exam Review To Students'),
                    subtitle: const Text(
                      'If enabled, students can see the review section before submit and detailed answer review after the exam.',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _showExamReview = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    value: _showAnswersInPractice,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Answers In Practice'),
                    onChanged: (value) {
                      setState(() {
                        _showAnswersInPractice = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    value: _shuffleQuestions,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Shuffle Questions'),
                    onChanged: (value) {
                      setState(() {
                        _shuffleQuestions = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _saveSettings,
                      child: const Text('Save Settings'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Question Bank',
              subtitle:
                  'Add or remove questions. Students will receive exams based on this bank.',
              action: FilledButton.icon(
                onPressed: _showAddQuestionDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Question'),
              ),
              child: Column(
                children: controller.questions
                    .map(
                      (question) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(question.question),
                          subtitle: Text(
                            '${question.subject} • Correct: ${question.correctAnswer}',
                          ),
                          trailing: IconButton(
                            onPressed: () =>
                                controller.deleteQuestion(question.id),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Student Progress & Leaderboard',
              subtitle:
                  'Admin can monitor how students are performing in the configured exam system.',
              child: leaderboard.isEmpty
                  ? const Text('No exam attempts yet.')
                  : Column(
                      children: leaderboard
                          .map(
                            (attempt) => Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                    '${(attempt.accuracy * 100).round()}%',
                                  ),
                                ),
                                title: Text(
                                  '${attempt.userName} • ${attempt.scoreLabel}',
                                ),
                                subtitle: Text(
                                  '${attempt.analysis.headline}\n${attempt.completedAt.toLocal()}',
                                ),
                                isThreeLine: true,
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(title, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 6),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
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
                    ],
                  ),
                ),
                if (action != null) ...[const SizedBox(width: 12), action!],
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}
