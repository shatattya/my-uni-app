import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/local/app_database.dart';
import '../../data/repositories/book_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/library/resource_library_widgets.dart';

final bookSearchQueryProvider =
StateProvider.autoDispose<String>((ref) => '');

final bookSemesterProvider =
StateProvider.autoDispose<int>((ref) => 1);

class BooksCatalogScreen extends ConsumerStatefulWidget {
  const BooksCatalogScreen({super.key});

  @override
  ConsumerState<BooksCatalogScreen> createState() =>
      _BooksCatalogScreenState();
}

class _BooksCatalogScreenState
    extends ConsumerState<BooksCatalogScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController =
  TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _changeSemester(int semester) {
    if (semester < 1 || semester > 8) {
      return;
    }

    if (ref.read(bookSemesterProvider) == semester) {
      return;
    }

    HapticFeedback.selectionClick();
    ref.read(bookSemesterProvider.notifier).state = semester;
  }

  Future<void> _openBookLink(String rawUrl) async {
    final value = rawUrl.trim();

    if (value.isEmpty) {
      _showMessage('This book does not have a download link.');
      return;
    }

    final uri = Uri.tryParse(value);

    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      _showMessage('The download link is invalid.');
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _showMessage('Could not open the download link.');
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to open book link: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('Could not open the download link.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _showDownloadDialog(Book book) async {
    HapticFeedback.selectionClick();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return AlertDialog(
          title: Row(
            children: [
              Container(
                width: 40.r,
                height: 40.r,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                  BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.menu_book_outlined,
                  color: theme.colorScheme.primary,
                  size: 21.r,
                ),
              ),
              SizedBox(width: 10.w),
              const Expanded(
                child: Text('Open book'),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.title.trim().isEmpty
                    ? 'Untitled book'
                    : book.title.trim(),
                style:
                theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (book.author.trim().isNotEmpty) ...[
                SizedBox(height: 5.h),
                Text(
                  book.author.trim(),
                  style:
                  theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              SizedBox(height: 14.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius:
                  BorderRadius.circular(12.r),
                ),
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 18.r,
                      color: theme.colorScheme.primary,
                    ),
                    SizedBox(width: 9.w),
                    Expanded(
                      child: Text(
                        'The book will open outside the app using the available download link.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _openBookLink(book.downloadUrl);
              },
              icon: const Icon(
                Icons.open_in_new_rounded,
              ),
              label: const Text('Open'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRequestBottomSheet() async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BookRequestForm(),
    );

    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Book request submitted successfully.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final currentSemester = ref.watch(bookSemesterProvider);
    final searchQuery =
    ref.watch(bookSearchQueryProvider).trim().toLowerCase();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;

          if (velocity < -300 && currentSemester < 8) {
            _changeSemester(currentSemester + 1);
          } else if (velocity > 300 &&
              currentSemester > 1) {
            _changeSemester(currentSemester - 1);
          }
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              titleSpacing: 20.w,
              title: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    'Books Library',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Find your semester resources',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: EdgeInsets.only(
                    right: 12.w,
                  ),
                  child: TextButton.icon(
                    onPressed: _showRequestBottomSheet,
                    icon: Icon(
                      Icons.add_rounded,
                      size: 19.r,
                    ),
                    label: const Text('Request'),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  8.h,
                  16.w,
                  0,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    LibrarySearchField(
                      controller: _searchController,
                      hintText:
                      'Search by book title or author',
                      onChanged: (value) {
                        ref
                            .read(
                          bookSearchQueryProvider
                              .notifier,
                        )
                            .state = value;
                      },
                      onClear: () {
                        _searchController.clear();
                        ref
                            .read(
                          bookSearchQueryProvider
                              .notifier,
                        )
                            .state = '';
                      },
                    ),
                    SizedBox(height: 18.h),
                    LibrarySectionLabel(
                      title: 'Semester',
                      trailing: '1–8',
                    ),
                    SizedBox(height: 9.h),
                    SemesterSelector(
                      selectedSemester:
                      currentSemester,
                      onSelected: _changeSemester,
                    ),
                    SizedBox(height: 18.h),
                  ],
                ),
              ),
            ),
            StreamBuilder<List<Book>>(
              stream: ref
                  .read(bookRepositoryProvider)
                  .watchBooksForSemester(
                currentSemester,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: colorScheme.primary,
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return const LibraryErrorState(
                    message:
                    'Could not load the books catalog.',
                  );
                }

                final books =
                    snapshot.data ?? const <Book>[];

                final filteredBooks = books.where((book) {
                  final title =
                  book.title.toLowerCase();
                  final author =
                  book.author.toLowerCase();

                  return title.contains(searchQuery) ||
                      author.contains(searchQuery);
                }).toList();

                if (filteredBooks.isEmpty) {
                  return LibraryEmptyState(
                    icon: Icons.menu_book_outlined,
                    title: searchQuery.isEmpty
                        ? 'No books available'
                        : 'No books found',
                    subtitle: searchQuery.isEmpty
                        ? 'There are no books cached for this semester yet.'
                        : 'Nothing matches your current search.',
                    query: searchQuery,
                  );
                }

                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16.w,
                    0,
                    16.w,
                    28.h,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                    SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220.w,
                      mainAxisSpacing: 12.h,
                      crossAxisSpacing: 12.w,
                      childAspectRatio: 0.64,
                    ),
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final book =
                        filteredBooks[index];

                        return _BookCard(
                          book: book,
                          onTap: () =>
                              _showDownloadDialog(book),
                        );
                      },
                      childCount:
                      filteredBooks.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const _BookCard({
    required this.book,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final title = book.title.trim().isEmpty
        ? 'Untitled book'
        : book.title.trim();

    final author = book.author.trim().isEmpty
        ? 'Unknown author'
        : book.author.trim();

    return Semantics(
      button: true,
      label: '$title by $author',
      child: Material(
        color: Colors.transparent,
        borderRadius:
        BorderRadius.circular(AppRadii.large.r),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius:
            BorderRadius.circular(AppRadii.large.r),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius:
            BorderRadius.circular(AppRadii.large.r),
            splashColor:
            colorScheme.primary.withValues(alpha: 0.08),
            highlightColor:
            colorScheme.primary.withValues(alpha: 0.04),
            child: Padding(
              padding: EdgeInsets.all(8.w),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius:
                      BorderRadius.circular(13.r),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            color: colorScheme.primary
                                .withValues(alpha: 0.08),
                            child: Center(
                              child: Icon(
                                Icons.menu_book_rounded,
                                size: 45.r,
                                color: colorScheme.primary
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                          if (book.coverUrl.trim().isNotEmpty)
                            CachedNetworkImage(
                              imageUrl:
                              book.coverUrl.trim(),
                              fit: BoxFit.cover,
                              fadeInDuration:
                              const Duration(
                                milliseconds: 180,
                              ),
                              placeholder:
                                  (context, url) {
                                return Center(
                                  child: SizedBox(
                                    width: 22.r,
                                    height: 22.r,
                                    child:
                                    CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color:
                                      colorScheme.primary,
                                    ),
                                  ),
                                );
                              },
                              errorWidget:
                                  (context, url, error) {
                                return Center(
                                  child: Icon(
                                    Icons
                                        .image_not_supported_outlined,
                                    size: 34.r,
                                    color: AppColors
                                        .textTertiary,
                                  ),
                                );
                              },
                            ),
                          Positioned(
                            top: 8.w,
                            right: 8.w,
                            child: Container(
                              width: 32.r,
                              height: 32.r,
                              decoration: BoxDecoration(
                                color: Colors.black
                                    .withValues(alpha: 0.62),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons
                                    .download_rounded,
                                size: 17.r,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 9.h),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 14.r,
                        color: colorScheme.primary,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'Sem ${book.semester}',
                        style:
                        theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookRequestForm extends ConsumerStatefulWidget {
  const _BookRequestForm();

  @override
  ConsumerState<_BookRequestForm> createState() =>
      _BookRequestFormState();
}

class _BookRequestFormState
    extends ConsumerState<_BookRequestForm> {
  final _bookNameController = TextEditingController();
  final _authorController = TextEditingController();
  final _semesterController = TextEditingController();
  final _isbnController = TextEditingController();

  bool _isSubmitting = false;
  bool _cooldownActive = false;

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
    try {
      final prefs =
      await SharedPreferences.getInstance();

      final lastRequest = prefs.getString(
        'last_book_request_date',
      );

      final today =
      DateFormat('yyyy-MM-dd').format(
        DateTime.now(),
      );

      if (lastRequest == today && mounted) {
        setState(() {
          _cooldownActive = true;
        });
      }
    } catch (error) {
      debugPrint(
        'Failed to read book request cooldown: $error',
      );
    }
  }

  int? _parseSemester() {
    final value =
    int.tryParse(
      _semesterController.text.trim(),
    );

    if (value == null || value < 1 || value > 8) {
      return null;
    }

    return value;
  }

  bool _isFormValid() {
    final name =
    _bookNameController.text.trim();
    final author =
    _authorController.text.trim();

    return !_cooldownActive &&
        name.isNotEmpty &&
        name.length <= 60 &&
        author.isNotEmpty &&
        author.length <= 60 &&
        _parseSemester() != null;
  }

  Future<void> _submitRequest() async {
    if (_isSubmitting || !_isFormValid()) {
      return;
    }

    HapticFeedback.lightImpact();

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(bookRepositoryProvider)
          .submitBookRequest(
        name: _bookNameController.text.trim(),
        author: _authorController.text.trim(),
        semester: _parseSemester()!,
        isbn: _isbnController.text.trim(),
      );

      final prefs =
      await SharedPreferences.getInstance();

      final today =
      DateFormat('yyyy-MM-dd').format(
        DateTime.now(),
      );

      await prefs.setString(
        'last_book_request_date',
        today,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Book request failed: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error
                .toString()
                .replaceFirst('Exception: ', '')
                .trim()
                .isEmpty
                ? 'Could not submit the request.'
                : error
                .toString()
                .replaceFirst('Exception: ', '')
                .trim(),
          ),
        ),
      );
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType =
        TextInputType.text,
    int? maxLength,
  }) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      textInputAction: TextInputAction.next,
      onChanged: (_) {
        setState(() {});
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: AppColors.surface,
        labelStyle:
        theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14.w,
          vertical: 14.h,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset =
        MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(
            AppRadii.extraLarge.r,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20.w,
          12.h,
          20.w,
          20.h + bottomInset,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: 0.14,
                    ),
                    borderRadius:
                    BorderRadius.circular(999.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Container(
                    width: 44.r,
                    height: 44.r,
                    decoration: BoxDecoration(
                      color:
                      colorScheme.primary.withValues(
                        alpha: 0.10,
                      ),
                      borderRadius:
                      BorderRadius.circular(13.r),
                    ),
                    child: Icon(
                      Icons.menu_book_outlined,
                      color: colorScheme.primary,
                    ),
                  ),
                  SizedBox(width: 11.w),
                  Text(
                    'Request a book',
                    style:
                    theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              if (_cooldownActive) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color:
                    colorScheme.primary.withValues(
                      alpha: 0.08,
                    ),
                    borderRadius:
                    BorderRadius.circular(14.r),
                    border: Border.all(
                      color:
                      colorScheme.primary.withValues(
                        alpha: 0.18,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        color: colorScheme.primary,
                        size: 21.r,
                      ),
                      SizedBox(width: 9.w),
                      Expanded(
                        child: Text(
                          'You have already submitted a book request today. You can submit another request tomorrow.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(
                            color:
                            AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _buildField(
                  controller:
                  _bookNameController,
                  label: 'Book name',
                  hint: 'Enter the book title',
                  maxLength: 60,
                ),
                SizedBox(height: 11.h),
                _buildField(
                  controller:
                  _authorController,
                  label: 'Author',
                  hint: 'Enter the author name',
                  maxLength: 60,
                ),
                SizedBox(height: 11.h),
                _buildField(
                  controller:
                  _semesterController,
                  label: 'Semester',
                  hint: '1–8',
                  keyboardType:
                  TextInputType.number,
                ),
                SizedBox(height: 11.h),
                _buildField(
                  controller:
                  _isbnController,
                  label: 'ISBN',
                  hint: 'Optional',
                  keyboardType:
                  TextInputType.text,
                  maxLength: 32,
                ),
                SizedBox(height: 18.h),
                SizedBox(
                  width: double.infinity,
                  height: 50.h,
                  child: FilledButton(
                    onPressed: _isSubmitting ||
                        !_isFormValid()
                        ? null
                        : _submitRequest,
                    child: _isSubmitting
                        ? SizedBox(
                      width: 20.r,
                      height: 20.r,
                      child:
                      const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Submit request',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}