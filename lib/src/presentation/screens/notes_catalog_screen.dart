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
      // Trigger a safe UI redraw if returning from Google Drive
      setState(() {});
    }
  }

  Future<void> _openDriveLink(String url) async {
    final uri = Uri.parse(url);
    try {
      // MODIFICATION: Removed canLaunchUrl() check to bypass Android 11+ package visibility constraints
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
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
            title: const Text('Notes Library', style: TextStyle(color: Colors.white)),
            pinned: true,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              // MODIFICATION: Replaced icon-only button with clear TextButton
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
                  // MODIFICATION: Replaced CupertinoSearchTextField with sleek Material TextField
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search notes by title or subject...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16.w),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => ref.read(noteSearchQueryProvider.notifier).state = val,
                  ),
                  SizedBox(height: 20.h),
                  SizedBox(
                    height: 40.h,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: 8,
                      itemBuilder: (context, index) {
                        final semester = index + 1;
                        final isSelected = currentSemester == semester;
                        return GestureDetector(
                          onTap: () => ref.read(noteSemesterProvider.notifier).state = semester,
                          child: Container(
                            margin: EdgeInsets.only(right: 10.w),
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blueAccent : const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(20.r),
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
                  // MODIFICATION: Replaced CupertinoActivityIndicator
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
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
                return const SliverFillRemaining(
                  child: Center(child: Text('No notes found.', style: TextStyle(color: Colors.grey))),
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
                        onTap: () => _openDriveLink(note.fileUrl),
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
// Note Tile UI Component
// -----------------------------------------------------------------
class _NoteTile extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;

  const _NoteTile({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10.r),
              ),
              // MODIFICATION: Replaced CupertinoIcons
              child: const Icon(Icons.description, color: Colors.orangeAccent),
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
                    style: TextStyle(color: Colors.grey, fontSize: 13.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // MODIFICATION: Replaced CupertinoIcons
            Icon(Icons.chevron_right, color: Colors.grey, size: 24.sp),
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
          const SnackBar(content: Text('Note request submitted successfully!')),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit request.')),
        );
      }
    }
  }

  // MODIFICATION: Helper method to generate unified iOS-style Material TextFields
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
        counterText: '', // Hide default character counter to save space
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide.none,
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
            // MODIFICATION: Replaced CupertinoIcons
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
                backgroundColor: Colors.blueAccent,
                disabledBackgroundColor: Colors.grey.shade800,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              onPressed: _isFormValid() && !_isSubmitting ? _submitRequest : null,
              child: _isSubmitting
                  ? SizedBox(height: 20.h, width: 20.h, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Request', style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }
}