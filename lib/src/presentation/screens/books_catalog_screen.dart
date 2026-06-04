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

  final Set<String> _precachedUrls = {};

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

  void _showDownloadDialog(Book book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Row(
          children: [
            const Icon(Icons.cloud_download_outlined, color: Colors.blueAccent),
            SizedBox(width: 10.w),
            const Text('Download Book', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Do you want to download "${book.title}"?',
                style: const TextStyle(color: Colors.white70)
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: const Text(
                'Note: In future updates, supporting our app by viewing a short sponsor message may be required before downloading.',
                style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontStyle: FontStyle.italic),
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
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _openDriveLink(book.downloadUrl);
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
            title: const Text('Books Library', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            pinned: true,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
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
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search books by name or author...',
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
                    onChanged: (val) => ref.read(bookSearchQueryProvider.notifier).state = val,
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
                          onTap: () => ref.read(bookSemesterProvider.notifier).state = semester,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: EdgeInsets.only(right: 12.w),
                            padding: EdgeInsets.symmetric(horizontal: 24.w),
                            decoration: BoxDecoration(
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

          StreamBuilder<List<Book>>(
            stream: ref.read(bookRepositoryProvider).watchBooksForSemester(currentSemester),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
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

              final unprecachedBooks = filteredBooks.where((b) => b.coverUrl.isNotEmpty && !_precachedUrls.contains(b.coverUrl)).toList();
              if (unprecachedBooks.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  for (var book in unprecachedBooks) {
                    _precachedUrls.add(book.coverUrl);
                    // MODIFICATION: Handled the ImageResourceService socket exception natively
                    // via the explicit onError callback parameter.
                    precacheImage(
                      NetworkImage(book.coverUrl),
                      context,
                      onError: (exception, stackTrace) {
                        // Silently swallow SocketExceptions/timeouts to keep the console clean.
                        // The UI will gracefully fallback to the colored background anyway.
                      },
                    );
                  }
                });
              }

              if (filteredBooks.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book, color: Colors.grey.shade800, size: 64.sp),
                          SizedBox(height: 16.h),
                          const Text('No books found.', style: TextStyle(color: Colors.grey)),
                        ],
                      )
                  ),
                );
              }

              return SliverPadding(
                padding: EdgeInsets.all(16.w),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16.h,
                    crossAxisSpacing: 16.w,
                    childAspectRatio: 0.6,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final book = filteredBooks[index];
                      return _BookCard(
                        book: book,
                        onTap: () => _showDownloadDialog(book),
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
// Vibrant Book Card UI Component
// -----------------------------------------------------------------
class _BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const _BookCard({required this.book, required this.onTap});

  Color _getVibrantColor(String title) {
    final colors = [
      const Color(0xFFFF4B4B), // Red
      const Color(0xFF4B7BFF), // Blue
      const Color(0xFF00C9A7), // Teal
      const Color(0xFFFF8F00), // Orange
      const Color(0xFFB54BFF), // Purple
      const Color(0xFFFF4B91), // Pink
    ];
    return colors[title.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _getVibrantColor(book.title);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accentColor.withOpacity(0.8),
                          accentColor.withOpacity(0.3),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(Icons.book, color: Colors.white.withOpacity(0.5), size: 48.sp),
                    ),
                  ),
                  if (book.coverUrl.isNotEmpty)
                    Image.network(
                      book.coverUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      gaplessPlayback: true,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                            child: SizedBox(
                              width: 24.w,
                              height: 24.w,
                              child: CircularProgressIndicator(
                                color: accentColor,
                                strokeWidth: 3,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            )
                        );
                      },
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.download, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: accentColor, width: 2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp, height: 1.2)
                    ),
                    SizedBox(height: 6.h),
                    Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12.sp)
                    ),
                  ],
                ),
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
          const SnackBar(content: Text('Book request submitted successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
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
          borderSide: const BorderSide(color: Colors.blueAccent),
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
                  : const Text('Submit Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}