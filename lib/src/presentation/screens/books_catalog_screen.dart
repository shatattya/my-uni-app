import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../data/local/app_database.dart';
import '../../data/repositories/book_repository.dart';

// Preserved State Providers
final bookSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final bookSemesterProvider = StateProvider.autoDispose<int>((ref) => 1);

class BooksCatalogScreen extends ConsumerStatefulWidget {
  const BooksCatalogScreen({super.key});

  @override
  ConsumerState<BooksCatalogScreen> createState() => _BooksCatalogScreenState();
}

class _BooksCatalogScreenState extends ConsumerState<BooksCatalogScreen>
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
      builder: (context) => const _BookRequestForm(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentSemester = ref.watch(bookSemesterProvider);
    final searchQuery = ref.watch(bookSearchQueryProvider).toLowerCase();

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black,
            title: const Text('Books Library', style: TextStyle(color: Colors.white)),
            pinned: true,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              // MODIFICATION: Replaced icon-only button with clear TextButton
              Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: TextButton.icon(
                  onPressed: _showRequestBottomSheet,
                  icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                  label: const Text('Request Book', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
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
                      hintText: 'Search books by name or author...',
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
                    onChanged: (val) => ref.read(bookSearchQueryProvider.notifier).state = val,
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
                          onTap: () => ref.read(bookSemesterProvider.notifier).state = semester,
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

          StreamBuilder<List<Book>>(
            stream: ref.read(bookRepositoryProvider).watchBooksForSemester(currentSemester),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  // MODIFICATION: Replaced CupertinoActivityIndicator
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                );
              }
              if (snapshot.hasError) {
                return const SliverFillRemaining(
                  child: Center(child: Text('Error loading books.', style: TextStyle(color: Colors.red))),
                );
              }

              final books = snapshot.data ?? [];
              final filteredBooks = books.where((b) {
                return b.title.toLowerCase().contains(searchQuery) ||
                    b.author.toLowerCase().contains(searchQuery);
              }).toList();

              if (filteredBooks.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text('No books found.', style: TextStyle(color: Colors.grey))),
                );
              }

              return SliverPadding(
                padding: EdgeInsets.all(16.w),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16.h,
                    crossAxisSpacing: 16.w,
                    childAspectRatio: 0.65,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final book = filteredBooks[index];
                      return _BookCard(
                        book: book,
                        onTap: () => _openDriveLink(book.downloadUrl),
                      );
                    },
                    childCount: filteredBooks.length,
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
// Book Card UI Component
// -----------------------------------------------------------------
class _BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const _BookCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12.r),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: book.coverUrl.isNotEmpty
                  ? Image.network(
                book.coverUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                // MODIFICATION: Replaced CupertinoIcons
                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.book, color: Colors.grey, size: 40)),
              )
                  : const Center(child: Icon(Icons.book, color: Colors.grey, size: 40)),
            ),
            Padding(
              padding: EdgeInsets.all(10.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp)
                  ),
                  SizedBox(height: 4.h),
                  Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey, fontSize: 12.sp)
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}


// -----------------------------------------------------------------
// Internal Request Form Widget (Bottom Sheet)
// -----------------------------------------------------------------
class _BookRequestForm extends ConsumerStatefulWidget {
  const _BookRequestForm();

  @override
  ConsumerState<_BookRequestForm> createState() => _BookRequestFormState();
}

class _BookRequestFormState extends ConsumerState<_BookRequestForm> {
  final _bookNameController = TextEditingController();
  final _authorController = TextEditingController();
  final _semesterController = TextEditingController();
  final _isbnController = TextEditingController();

  bool _isSubmitting = false;
  String _cooldownMessage = '';

  @override
  void initState() {
    super.initState();
    _checkCooldown();
  }

  @override
  void dispose() {
    _bookNameController.dispose();
    _authorController.dispose();
    _semesterController.dispose();
    _isbnController.dispose();
    super.dispose();
  }

  Future<void> _checkCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRequest = prefs.getString('last_book_request_date');
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (lastRequest == today) {
      setState(() {
        _cooldownMessage = 'You can only request one book per day. Please try again tomorrow.';
      });
    }
  }

  bool _isFormValid() {
    final name = _bookNameController.text.trim();
    final author = _authorController.text.trim();
    final semText = _semesterController.text.trim();

    if (name.isEmpty || name.length > 60) return false;
    if (author.isEmpty || author.length > 60) return false;

    final sem = int.tryParse(semText);
    if (sem == null || sem < 1 || sem > 8) return false;

    return true;
  }

  Future<void> _submitRequest() async {
    if (!_isFormValid()) return;

    setState(() => _isSubmitting = true);

    try {
      await ref.read(bookRepositoryProvider).submitBookRequest(
        name: _bookNameController.text.trim(),
        author: _authorController.text.trim(),
        semester: int.parse(_semesterController.text.trim()),
        isbn: _isbnController.text.trim(),
      );

      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await prefs.setString('last_book_request_date', today);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book request submitted successfully!')),
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
            'Request a Book',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20.h),

          _buildFormTextField(
            controller: _bookNameController,
            hint: 'Book Name (Required)',
            maxLength: 60,
          ),
          SizedBox(height: 12.h),

          _buildFormTextField(
            controller: _authorController,
            hint: 'Author Name (Required)',
            maxLength: 60,
          ),
          SizedBox(height: 12.h),

          _buildFormTextField(
            controller: _semesterController,
            hint: 'Semester (1-8)',
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 12.h),

          _buildFormTextField(
            controller: _isbnController,
            hint: 'ISBN (Optional)',
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