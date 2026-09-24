import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/local/app_database.dart';
import '../../data/repositories/note_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/library/resource_library_widgets.dart';

final noteSearchQueryProvider =
StateProvider.autoDispose<String>((ref) => '');

final noteSemesterProvider =
StateProvider.autoDispose<int>((ref) => 1);

class NotesCatalogScreen extends ConsumerStatefulWidget {
  const NotesCatalogScreen({super.key});

  @override
  ConsumerState<NotesCatalogScreen> createState() =>
      _NotesCatalogScreenState();
}

class _NotesCatalogScreenState
    extends ConsumerState<NotesCatalogScreen>
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

    if (ref.read(noteSemesterProvider) == semester) {
      return;
    }

    HapticFeedback.selectionClick();
    ref.read(noteSemesterProvider.notifier).state =
        semester;
  }

  Future<void> _openNoteLink(String rawUrl) async {
    final value = rawUrl.trim();

    if (value.isEmpty) {
      _showMessage('This note does not have a download link.');
      return;
    }

    final uri = Uri.tryParse(value);

    if (uri == null ||
        (uri.scheme != 'https' &&
            uri.scheme != 'http')) {
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
      debugPrint('Failed to open note link: $error');
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

  Future<void> _showDownloadDialog(Note note) async {
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
                  color: colorSchemeFrom(
                    dialogContext,
                  ).primary.withValues(alpha: 0.10),
                  borderRadius:
                  BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.description_outlined,
                  color:
                  colorSchemeFrom(dialogContext)
                      .primary,
                  size: 21.r,
                ),
              ),
              SizedBox(width: 10.w),
              const Expanded(
                child: Text('Open note'),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                note.title.trim().isEmpty
                    ? 'Untitled note'
                    : note.title.trim(),
                style:
                theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 5.h),
              Text(
                note.subjectName.trim().isEmpty
                    ? 'Unknown subject'
                    : note.subjectName.trim(),
                style:
                theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (note.authorName.trim().isNotEmpty) ...[
                SizedBox(height: 3.h),
                Text(
                  'By ${note.authorName.trim()}',
                  style:
                  theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
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
                      color:
                      colorSchemeFrom(dialogContext)
                          .primary,
                    ),
                    SizedBox(width: 9.w),
                    Expanded(
                      child: Text(
                        'The note will open outside the app using the available file link.',
                        style: theme.textTheme.bodySmall
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
                _openNoteLink(note.fileUrl);
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
      builder: (_) => const _NoteRequestForm(),
    );

    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Note request submitted successfully.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final currentSemester = ref.watch(
      noteSemesterProvider,
    );

    final searchQuery = ref
        .watch(noteSearchQueryProvider)
        .trim()
        .toLowerCase();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;

          if (velocity < -300 &&
              currentSemester < 8) {
            _changeSemester(
              currentSemester + 1,
            );
          } else if (velocity > 300 &&
              currentSemester > 1) {
            _changeSemester(
              currentSemester - 1,
            );
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
                    'Notes Library',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Study material for your semester',
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
                      'Search by title or subject',
                      onChanged: (value) {
                        ref
                            .read(
                          noteSearchQueryProvider
                              .notifier,
                        )
                            .state = value;
                      },
                      onClear: () {
                        _searchController.clear();
                        ref
                            .read(
                          noteSearchQueryProvider
                              .notifier,
                        )
                            .state = '';
                      },
                    ),
                    SizedBox(height: 18.h),
                    const LibrarySectionLabel(
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
            StreamBuilder<List<Note>>(
              stream: ref
                  .read(noteRepositoryProvider)
                  .watchNotesForSemester(
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
                    'Could not load the notes catalog.',
                  );
                }

                final notes =
                    snapshot.data ?? const <Note>[];

                final filteredNotes = notes.where((note) {
                  final title =
                  note.title.toLowerCase();
                  final subject =
                  note.subjectName.toLowerCase();

                  return title.contains(searchQuery) ||
                      subject.contains(searchQuery);
                }).toList();

                if (filteredNotes.isEmpty) {
                  return LibraryEmptyState(
                    icon: Icons.description_outlined,
                    title: searchQuery.isEmpty
                        ? 'No notes available'
                        : 'No notes found',
                    subtitle: searchQuery.isEmpty
                        ? 'There are no notes cached for this semester yet.'
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
                  sliver: SliverList.separated(
                    itemCount: filteredNotes.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: 10.h),
                    itemBuilder: (context, index) {
                      final note =
                      filteredNotes[index];

                      return _NoteTile(
                        note: note,
                        onTap: () =>
                            _showDownloadDialog(note),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  ColorScheme colorSchemeFrom(BuildContext context) {
    return Theme.of(context).colorScheme;
  }
}

class _NoteTile extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;

  const _NoteTile({
    required this.note,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final title = note.title.trim().isEmpty
        ? 'Untitled note'
        : note.title.trim();

    final subject = note.subjectName.trim().isEmpty
        ? 'Unknown subject'
        : note.subjectName.trim();

    final author = note.authorName.trim();

    return Semantics(
      button: true,
      label: '$title, $subject',
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
              padding: EdgeInsets.all(14.w),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52.r,
                    height: 52.r,
                    decoration: BoxDecoration(
                      color:
                      colorScheme.primary.withValues(
                        alpha: 0.09,
                      ),
                      borderRadius:
                      BorderRadius.circular(15.r),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      color: colorScheme.primary,
                      size: 25.r,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow:
                          TextOverflow.ellipsis,
                          style: theme
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                            color:
                            AppColors.textPrimary,
                            fontWeight:
                            FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color:
                            colorScheme.primary
                                .withValues(
                              alpha: 0.08,
                            ),
                            borderRadius:
                            BorderRadius.circular(
                              999.r,
                            ),
                          ),
                          child: Text(
                            subject,
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: theme
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                              color:
                              colorScheme.primary,
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            if (author.isNotEmpty) ...[
                              Icon(
                                Icons.person_outline_rounded,
                                size: 14.r,
                                color:
                                AppColors.textTertiary,
                              ),
                              SizedBox(width: 4.w),
                              Flexible(
                                child: Text(
                                  author,
                                  maxLines: 1,
                                  overflow:
                                  TextOverflow.ellipsis,
                                  style: theme
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                    color: AppColors
                                        .textTertiary,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                            ],
                            Text(
                              DateFormat('d MMM yyyy')
                                  .format(
                                note.createdAt,
                              ),
                              style: theme
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                color:
                                AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    width: 36.r,
                    height: 36.r,
                    decoration: BoxDecoration(
                      color:
                      colorScheme.primary.withValues(
                        alpha: 0.08,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons
                          .arrow_forward_rounded,
                      color: colorScheme.primary,
                      size: 18.r,
                    ),
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

class _NoteRequestForm extends ConsumerStatefulWidget {
  const _NoteRequestForm();

  @override
  ConsumerState<_NoteRequestForm> createState() =>
      _NoteRequestFormState();
}

class _NoteRequestFormState
    extends ConsumerState<_NoteRequestForm> {
  final _subjectNameController =
  TextEditingController();
  final _semesterController =
  TextEditingController();

  bool _isSubmitting = false;
  bool _cooldownActive = false;

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
    try {
      final prefs =
      await SharedPreferences.getInstance();

      final lastRequest = prefs.getString(
        'last_note_request_date',
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
        'Failed to read note request cooldown: $error',
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
    final subject =
    _subjectNameController.text.trim();

    return !_cooldownActive &&
        subject.isNotEmpty &&
        subject.length <= 60 &&
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
          .read(noteRepositoryProvider)
          .submitNoteRequest(
        subjectName:
        _subjectNameController.text.trim(),
        semester: _parseSemester()!,
      );

      final prefs =
      await SharedPreferences.getInstance();

      final today =
      DateFormat('yyyy-MM-dd').format(
        DateTime.now(),
      );

      await prefs.setString(
        'last_note_request_date',
        today,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Note request failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

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
                      Icons.description_outlined,
                      color: colorScheme.primary,
                    ),
                  ),
                  SizedBox(width: 11.w),
                  Text(
                    'Request a note',
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
                          'You have already submitted a note request today. You can submit another request tomorrow.',
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
                TextField(
                  controller:
                  _subjectNameController,
                  maxLength: 60,
                  textInputAction:
                  TextInputAction.next,
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText:
                    'Enter the subject name',
                    counterText: '',
                  ),
                ),
                SizedBox(height: 11.h),
                TextField(
                  controller: _semesterController,
                  keyboardType:
                  TextInputType.number,
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    labelText: 'Semester',
                    hintText: '1–8',
                  ),
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