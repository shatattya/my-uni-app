import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/routine_uploader.dart';
import '../../data/repositories/routine_repository.dart';

class RoutineUploadSheet extends ConsumerStatefulWidget {
  const RoutineUploadSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RoutineUploadSheet(),
    );
  }

  @override
  ConsumerState<RoutineUploadSheet> createState() => _RoutineUploadSheetState();
}

class _RoutineUploadSheetState extends ConsumerState<RoutineUploadSheet> {
  bool _isUploading = false;
  bool _isFinished = false;
  String _statusText = "Ready to upload";
  double _progress = 0.0;
  String? _error;

  void _startUpload() async {
    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      // 1. Run the safe uploader
      await RoutineUploader.uploadRoutineJson((status, progress) {
        if (mounted) {
          setState(() {
            _statusText = status;
            _progress = progress;
          });
        }
      });

      // 2. Force local Drift sync immediately after upload
      if (mounted) {
        setState(() => _statusText = "Syncing to local device...");
      }
      await ref.read(routineRepositoryProvider).syncRoutines();

      // 3. Complete
      if (mounted) {
        setState(() {
          _progress = 1.0;
          _statusText = "Upload & Sync Complete!";
          _isFinished = true;
          _isUploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Routine Database Management",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "This action will completely wipe the existing global routine and replace it with the new assets/data/routine.json file.",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 30),

            // Animated State Display
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _error != null
                  ? _buildErrorState()
                  : _isFinished
                  ? _buildSuccessState()
                  : _buildUploadState(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadState() {
    return Column(
      key: const ValueKey("upload_state"),
      children: [
        if (_isUploading) ...[
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5667FD)),
            borderRadius: BorderRadius.circular(8),
            minHeight: 8,
          ),
          const SizedBox(height: 12),
          Text(_statusText, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 24),
        ],

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isUploading ? null : _startUpload,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isUploading ? Colors.white12 : Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isUploading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2))
                : const Text("Confirm & Upload Data", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      key: const ValueKey("success_state"),
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 60),
        const SizedBox(height: 16),
        Text(_statusText, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5667FD),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Done", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      key: const ValueKey("error_state"),
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
        const SizedBox(height: 16),
        Text("Upload Failed", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(_error ?? "Unknown error", textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => setState(() => _error = null),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Try Again", style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ),
      ],
    );
  }
}