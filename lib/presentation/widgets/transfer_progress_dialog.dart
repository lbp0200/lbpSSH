import 'package:flutter/material.dart';
import 'package:lbp_ssh/domain/services/kitty_file_transfer_service.dart';

/// 传输进度对话框
class TransferProgressDialog extends StatefulWidget {
  final String fileName;
  final int totalBytes;
  final Stream<TransferProgress> progressStream;
  final VoidCallback onCancel;

  const TransferProgressDialog({
    super.key,
    required this.fileName,
    required this.totalBytes,
    required this.progressStream,
    required this.onCancel,
  });

  @override
  State<TransferProgressDialog> createState() => _TransferProgressDialogState();
}

class _TransferProgressDialogState extends State<TransferProgressDialog> {
  double _percent = 0;
  int _transferred = 0;
  int _bytesPerSecond = 0;

  @override
  void initState() {
    super.initState();
    widget.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _percent = progress.percent;
          _transferred = progress.transferredBytes;
          _bytesPerSecond = progress.bytesPerSecond;
        });
      }
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('上传文件'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('文件: ${widget.fileName}'),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _percent / 100),
          const SizedBox(height: 8),
          Text('${_percent.toStringAsFixed(1)}%'),
          const SizedBox(height: 8),
          Text('${_formatSize(_transferred)} / ${_formatSize(widget.totalBytes)}'),
          if (_bytesPerSecond > 0)
            Text('速度: ${_formatSize(_bytesPerSecond)}/s'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('取消'),
        ),
      ],
    );
  }
}
