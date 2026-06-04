import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../data/local/app_database.dart';
import '../../data/repositories/note_repository.dart';

// Preserved State Providers
final noteSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final noteSemesterProvider = StateProvider.autoDispose<int>((ref) => 1);

class NotesCatalogScreen extends ConsumerStatefulWidget {
  const NotesCatalogScreen({super.key});

  @override
  ConsumerState<NotesCatalogScreen> createState() => _NotesCatalogScreenState();
}

class _NotesCatalogScreenState extends ConsumerState<NotesCatalogScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  Future<void> _openDriveLink(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  // MODIFICATION: Added Download Confirmation Popup for Ad Integration
  void _showDownloadDialog(Note note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Row(
          children: [
            const Icon(Icons.cloud_download_outlined, color: Colors.orangeAccent),
            SizedBox(width: 10.w),
            const Text('Download Note', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Do you want to download "${note.title}"?',
                style: const TextStyle(color: Colors.white70)
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
              ),
              child: const Text(
                'Note: In future updates, supporting our app by viewing a short sponsor message may be required before downloading.',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _openDriveLink(note.fileUrl);
            },
            child: const Text('Continue to Download', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRequestBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => const _NoteRequestForm(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentSemester = ref.watch(noteSemesterProvider);
    final searchQuery = ref.watch(noteSearchQueryProvider).toLowerCase();

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black,
            title: const Text('Notes Library', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            pinned: true,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: TextButton.icon(
                  onPressed: _showRequestBottomSheet,
                  icon: const Icon(Icons.add_circle_outline, color: Colors.orangeAccent),
                  label: const Text('Request Note', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search notes by title or subject...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16.w),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => ref.read(noteSearchQueryProvider.notifier).state = val,
                  ),
                  SizedBox(height: 20.h),
                  SizedBox(
                    height: 42.h,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: 8,
                      itemBuilder: (context, index) {
                        final semester = index + 1;
                        final isSelected = currentSemester == semester;
                        return GestureDetector(
                          onTap: () => ref.read(noteSemesterProvider.notifier).state = semester,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: EdgeInsets.only(right: 12.w),
                            padding: EdgeInsets.symmetric(horizontal: 24.w),
                            decoration: BoxDecoration(
                              // MODIFICATION: Added vibrant gradient for selected state
                              gradient: isSelected
                                  ? const LinearGradient(colors: [Color(0xFF4B7BFF), Color(0xFF00C9A7)])
                                  : null,
                              color: isSelected ? null : const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: isSelected ? Colors.transparent : Colors.grey.shade800,
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Sem $semester',
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          StreamBuilder<List<Note>>(
            stream: ref.read(noteRepositoryProvider).watchNotesForSemester(currentSemester),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: Colors.orangeAccent)),
                );
              }
              if (snapshot.hasError) {
                return const SliverFillRemaining(
                  child: Center(child: Text('Error loading notes.', style: TextStyle(color: Colors.red))),
                );
              }

              final notes = snapshot.data ?? [];
              final filteredNotes = notes.where((n) {
                return n.title.toLowerCase().contains(searchQuery) ||
                    n.subjectName.toLowerCase().contains(searchQuery);
              }).toList();

              if (filteredNotes.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.description, color: Colors.grey.shade800, size: 64.sp),
                          SizedBox(height: 16.h),
                          const Text('No notes found.', style: TextStyle(color: Colors.grey)),
                        ],
                      )
                  ),
                );
              }

              return SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final note = filteredNotes[index];
                      return _NoteTile(
                        note: note,
                        // MODIFICATION: Intercepted link open to trigger popup
                        onTap: () => _showDownloadDialog(note),
                      );
                    },
                    childCount: filteredNotes.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------
// Vibrant Note Tile UI Component
// -----------------------------------------------------------------
class _NoteTile extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;

  const _NoteTile({required this.note, required this.onTap});

  // Helper to generate a vibrant color based on the note's subject name
  Color _getVibrantColor(String text) {
    final colors = [
      const Color(0xFFFF4B4B), // Red
      const Color(0xFF4B7BFF), // Blue
      const Color(0xFF00C9A7), // Teal
      const Color(0xFFFF8F00), // Orange
      const Color(0xFFB54BFF), // Purple
      const Color(0xFFFF4B91), // Pink
    ];
    return colors[text.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _getVibrantColor(note.subjectName);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(16.r),
          // MODIFICATION: Added subtle colorful glow matching the accent color
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                // MODIFICATION: Vibrant gradient background for the icon
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withOpacity(0.8),
                    accentColor.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: const Icon(Icons.description, color: Colors.white),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${note.subjectName} • ${note.authorName}',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.download, color: accentColor, size: 20.sp),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------
// Internal Request Form Widget (Bottom Sheet)
// -----------------------------------------------------------------
class _NoteRequestForm extends ConsumerStatefulWidget {
  const _NoteRequestForm();

  @override
  ConsumerState<_NoteRequestForm> createState() => _NoteRequestFormState();
}

class _NoteRequestFormState extends ConsumerState<_NoteRequestForm> {
  final _subjectNameController = TextEditingController();
  final _semesterController = TextEditingController();

  bool _isSubmitting = false;
  String _cooldownMessage = '';

  @override
  void initState() {
    super.initState();
    _checkCooldown();
  }

  @override
  void dispose() {
    _subjectNameController.dispose();
    _semesterController.dispose();
    super.dispose();
  }

  Future<void> _checkCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRequest = prefs.getString('last_note_request_date');
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (lastRequest == today) {
      setState(() {
        _cooldownMessage = 'You can only request one note per day. Please try again tomorrow.';
      });
    }
  }

  bool _isFormValid() {
    final subject = _subjectNameController.text.trim();
    final semText = _semesterController.text.trim();

    if (subject.isEmpty || subject.length > 60) return false;

    final sem = int.tryParse(semText);
    if (sem == null || sem < 1 || sem > 8) return false;

    return true;
  }

  Future<void> _submitRequest() async {
    if (!_isFormValid()) return;

    setState(() => _isSubmitting = true);

    try {
      await ref.read(noteRepositoryProvider).submitNoteRequest(
        subjectName: _subjectNameController.text.trim(),
        semester: int.parse(_semesterController.text.trim()),
      );

      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await prefs.setString('last_note_request_date', today);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note request submitted successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit request.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildFormTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        counterText: '',
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: Colors.orangeAccent),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    if (_cooldownMessage.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule, color: Colors.orange, size: 48),
            SizedBox(height: 16.h),
            Text(
              _cooldownMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            SizedBox(height: bottomPadding),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 24.w,
        right: 24.w,
        top: 24.h,
        bottom: bottomPadding + 24.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Request a Note',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20.h),

          _buildFormTextField(
            controller: _subjectNameController,
            hint: 'Subject Name (Required)',
            maxLength: 60,
          ),
          SizedBox(height: 12.h),

          _buildFormTextField(
            controller: _semesterController,
            hint: 'Semester (1-8)',
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 24.h),

          SizedBox(
            width: double.infinity,
            height: 50.h,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                disabledBackgroundColor: Colors.grey.shade800,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              onPressed: _isFormValid() && !_isSubmitting ? _submitRequest : null,
              child: _isSubmitting
                  ? SizedBox(height: 20.h, width: 20.h, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}