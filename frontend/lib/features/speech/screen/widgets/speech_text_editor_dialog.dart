import 'package:flutter/material.dart';

/// Dialog edit teks OCR sebelum dibacakan TTS.
///
/// Mengembalikan teks baru, atau `null` jika pengguna membatalkan / teks kosong.
Future<String?> showSpeechTextEditor({
  required BuildContext context,
  required String initialText,
  required bool isIndonesian,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _SpeechTextEditorDialog(
      initialText: initialText,
      isIndonesian: isIndonesian,
    ),
  );
}

class _SpeechTextEditorDialog extends StatefulWidget {
  final String initialText;
  final bool isIndonesian;

  const _SpeechTextEditorDialog({
    required this.initialText,
    required this.isIndonesian,
  });

  @override
  State<_SpeechTextEditorDialog> createState() =>
      _SpeechTextEditorDialogState();
}

class _SpeechTextEditorDialogState extends State<_SpeechTextEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isIndonesian ? 'Edit teks' : 'Edit text';
    final hint = widget.isIndonesian
        ? 'Perbaiki kata yang salah sebelum dibacakan.'
        : 'Fix wrong words before reading aloud.';
    final cancel = widget.isIndonesian ? 'Batal' : 'Cancel';
    final save = widget.isIndonesian ? 'Simpan' : 'Save';

    return AlertDialog(
      title: Text(title),
      content: TextField(
        key: const Key('speech-text-editor-field'),
        controller: _controller,
        autofocus: true,
        minLines: 4,
        maxLines: 12,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(save)),
      ],
    );
  }
}
