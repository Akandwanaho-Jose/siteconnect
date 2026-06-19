import 'package:flutter/material.dart';

class ReportCommentDialog extends StatefulWidget {
  const ReportCommentDialog({
    required this.title,
    required this.actionLabel,
    this.initialComment,
    super.key,
  });

  final String title;
  final String actionLabel;
  final String? initialComment;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String actionLabel,
    String? initialComment,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => ReportCommentDialog(
        title: title,
        actionLabel: actionLabel,
        initialComment: initialComment,
      ),
    );
  }

  @override
  State<ReportCommentDialog> createState() => _ReportCommentDialogState();
}

class _ReportCommentDialogState extends State<ReportCommentDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialComment ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.comment_outlined),
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 4,
        maxLines: 6,
        maxLength: 1000,
        textInputAction: TextInputAction.newline,
        decoration: const InputDecoration(
          labelText: 'Comment',
          hintText: 'Write a clear note for the report submitter',
          alignLabelWithHint: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          icon: const Icon(Icons.check),
          label: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
