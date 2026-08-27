import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'linear_styled_text_field.dart';

/// 手动输入私钥文件路径的对话框
/// 从 connection_form.dart 抽离，降低长文件复杂度并提升可测试性
class ManualPathDialog extends StatefulWidget {
  final String initialPath;

  const ManualPathDialog({super.key, this.initialPath = ''});

  @override
  State<ManualPathDialog> createState() => ManualPathDialogState();
}

class ManualPathDialogState extends State<ManualPathDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialPath);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('输入私钥文件路径'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearStyledTextField(
            controller: controller,
            labelText: '文件路径',
            hintText: '例如: /Users/lbp/.ssh/id_rsa',
            prefixIcon: const Icon(Icons.edit),
            autofocus: true,
          ),
          const SizedBox(height: LinearSpacing.spacing12),
          const Text(
            '提示：由于 macOS 沙箱限制，无法直接选择 ~/.ssh 目录中的文件，请手动输入完整路径。',
            style: TextStyle(fontSize: 12, color: LinearColors.textTertiary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final path = controller.text.trim();
            if (path.isNotEmpty) {
              Navigator.of(context).pop(path);
            }
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
