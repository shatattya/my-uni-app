import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart'
as firebase_auth;

import '../../../data/local/app_database.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../providers/profile_controller.dart';
import '../../../providers/sync_controller.dart';
import '../../../services/auth_service.dart';
import '../../routes/app_router.dart';
import '../../widgets/avatar_picker_sheet.dart';

class EditStudentProfileScreen
    extends ConsumerStatefulWidget {
  const EditStudentProfileScreen({super.key});

  @override
  ConsumerState<EditStudentProfileScreen>
  createState() =>
      _EditStudentProfileScreenState();
}

class _EditStudentProfileScreenState
    extends ConsumerState<
        EditStudentProfileScreen> {
  final nameController =
  TextEditingController();
  final semesterController =
  TextEditingController();
  final sectionController =
  TextEditingController();

  final currentPasswordController =
  TextEditingController();
  final passwordController =
  TextEditingController();
  final confirmPasswordController =
  TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  int currentAvatarId = 1;
  String userRole = 'student';
  bool _isUpdating = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    final uid =
        firebase_auth.FirebaseAuth
            .instance.currentUser?.uid;

    if (uid == null) {
      return;
    }

    try {
      final user = await ref
          .read(userRepositoryProvider)
          .watchUser(uid)
          .first;

      if (user != null && mounted) {
        setState(() {
          nameController.text = user.name;
          semesterController.text =
              user.semester.toString();
          sectionController.text =
              user.section;
          currentAvatarId =
              user.avatarId;
          userRole = user.role;
        });
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to load current student profile: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Could not load your profile. Please try again.',
          ),
          backgroundColor:
          Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    semesterController.dispose();
    sectionController.dispose();
    currentPasswordController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void handleUpdate() {
    final newPassword =
    passwordController.text.trim();

    if (newPassword.isNotEmpty &&
        newPassword !=
            confirmPasswordController.text) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
          Text('Passwords do not match'),
          backgroundColor:
          Colors.redAccent,
        ),
      );
      return;
    }

    final semester = int.tryParse(
      semesterController.text.trim(),
    );

    if (semester == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
          Text('Please enter a valid semester.'),
          backgroundColor:
          Colors.redAccent,
        ),
      );
      return;
    }

    if (_isUpdating) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    ref
        .read(
      profileControllerProvider.notifier,
    )
        .updateStudentProfile(
      name:
      nameController.text.trim(),
      semester: semester,
      section:
      sectionController.text.trim(),
      avatarId: currentAvatarId,
      currentPassword:
      currentPasswordController.text
          .trim(),
      newPassword: newPassword,
    );
  }

  Future<void> _syncData() async {
    final syncState =
    ref.read(syncControllerProvider);

    if (syncState.isLoading) {
      return;
    }

    HapticFeedback.lightImpact();

    try {
      await ref
          .read(
        syncControllerProvider
            .notifier,
      )
          .syncAllData();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
          Text('Data synced successfully!'),
          backgroundColor:
          Colors.green,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Student data sync failed: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            _cleanErrorMessage(error),
          ),
          backgroundColor:
          Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _openDeleteConfirmation() async {
    final uid =
        firebase_auth.FirebaseAuth
            .instance.currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
          Text('Authentication session is unavailable.'),
          backgroundColor:
          Colors.redAccent,
        ),
      );
      return;
    }

    final user = await ref
        .read(userRepositoryProvider)
        .getUserLocally(uid);

    if (!mounted) {
      return;
    }

    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Your profile data is unavailable. Please sync your data first.',
          ),
          backgroundColor:
          Colors.redAccent,
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    _showDeleteAccountDialog(
      context,
      user,
    );
  }

  void _showDeleteAccountDialog(
      BuildContext context,
      User user,
      ) {
    final passwordController =
    TextEditingController();

    bool isDeleting = false;
    bool obscureText = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (
            dialogContext,
            setDialogState,
            ) {
          return AlertDialog(
            backgroundColor:
            const Color(0xFF1E1E1E),
            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(
                16.r,
              ),
            ),
            title: Row(
              children: [
                Icon(
                  Icons
                      .warning_amber_rounded,
                  color:
                  Colors.redAccent,
                  size: 28.sp,
                ),
                SizedBox(
                  width: 10.w,
                ),
                Text(
                  'Delete Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight:
                    FontWeight.bold,
                    fontSize: 18.sp,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize:
              MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'This action is permanent and cannot be undone. All your offline and cloud data will be erased.\n\nPlease enter your password to confirm.',
                  style: TextStyle(
                    color:
                    Colors.white70,
                    fontSize: 14.sp,
                    height: 1.4,
                  ),
                ),
                SizedBox(
                  height: 16.h,
                ),
                TextField(
                  controller:
                  passwordController,
                  obscureText:
                  obscureText,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                  ),
                  decoration:
                  InputDecoration(
                    hintText:
                    'Password',
                    hintStyle:
                    const TextStyle(
                      color:
                      Colors.white54,
                    ),
                    filled: true,
                    fillColor:
                    Colors.black26,
                    border:
                    OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(
                        12.r,
                      ),
                      borderSide:
                      BorderSide.none,
                    ),
                    suffixIcon:
                    IconButton(
                      icon: Icon(
                        obscureText
                            ? Icons
                            .visibility_off_outlined
                            : Icons
                            .visibility_outlined,
                        color:
                        Colors.white54,
                        size: 20.sp,
                      ),
                      onPressed: isDeleting
                          ? null
                          : () {
                        setDialogState(
                              () {
                            obscureText =
                            !obscureText;
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDeleting
                    ? null
                    : () {
                  passwordController
                      .dispose();
                  Navigator.pop(
                    ctx,
                  );
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color:
                    Colors.white54,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed:
                isDeleting
                    ? null
                    : () async {
                  final password =
                  passwordController
                      .text
                      .trim();

                  if (password
                      .isEmpty) {
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Password is required',
                        ),
                        backgroundColor:
                        Colors.redAccent,
                      ),
                    );
                    return;
                  }

                  setDialogState(
                        () {
                      isDeleting =
                      true;
                    },
                  );

                  if (mounted) {
                    setState(() {
                      _isDeleting =
                      true;
                    });
                  }

                  try {
                    await ref
                        .read(
                      authServiceProvider,
                    )
                        .deleteAccount(
                      password:
                      password,
                      role:
                      'student',
                      docId:
                      user.internalId,
                    );

                    passwordController
                        .dispose();

                    if (!ctx.mounted) {
                      return;
                    }

                    Navigator.of(
                      ctx,
                      rootNavigator:
                      true,
                    ).pushNamedAndRemoveUntil(
                      AppRoutes.auth,
                          (route) =>
                      false,
                    );
                  } catch (
                  error,
                  stackTrace
                  ) {
                    debugPrint(
                      'Student account deletion failed: $error',
                    );
                    debugPrintStack(
                      stackTrace:
                      stackTrace,
                    );

                    setDialogState(
                          () {
                        isDeleting =
                        false;
                      },
                    );

                    if (mounted) {
                      setState(() {
                        _isDeleting =
                        false;
                      });
                    }

                    if (ctx.mounted) {
                      HapticFeedback
                          .heavyImpact();

                      ScaffoldMessenger
                          .of(ctx)
                          .showSnackBar(
                        SnackBar(
                          content:
                          Text(
                            _cleanErrorMessage(
                              error,
                            ),
                          ),
                          backgroundColor:
                          Colors
                              .redAccent,
                        ),
                      );
                    }
                  }
                },
                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  Colors.redAccent,
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      8.r,
                    ),
                  ),
                ),
                child: isDeleting
                    ? SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child:
                  const CircularProgressIndicator(
                    color:
                    Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'Delete',
                  style: TextStyle(
                    color:
                    Colors.white,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _cleanErrorMessage(
      Object error,
      ) {
    final message = error
        .toString()
        .replaceFirst(
      'Exception: ',
      '',
    )
        .trim();

    return message.isEmpty
        ? 'Something went wrong. Please try again.'
        : message;
  }

  @override
  Widget build(BuildContext context) {
    final formattedAvatarId =
    currentAvatarId
        .toString()
        .padLeft(2, '0');

    ref.listen<AsyncValue<void>>(
      profileControllerProvider,
          (previous, next) {
        if (!_isUpdating) {
          return;
        }

        if (next.isLoading) {
          return;
        }

        if (!mounted) {
          return;
        }

        setState(() {
          _isUpdating = false;
        });

        if (next.hasError) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            SnackBar(
              content: Text(
                _cleanErrorMessage(
                  next.error ??
                      Exception(
                        'Profile update failed.',
                      ),
                ),
              ),
              backgroundColor:
              Colors.redAccent,
            ),
          );
          return;
        }

        if (next.hasValue) {
          Navigator.pop(context);

          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Profile updated successfully!',
              ),
              backgroundColor:
              Colors.green,
            ),
          );
        }
      },
    );

    return GestureDetector(
      onTap: () =>
          FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: Text(
            'Profile Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight:
              FontWeight.bold,
            ),
          ),
          centerTitle: true,
          iconTheme:
          const IconThemeData(
            color: Colors.white,
          ),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics:
            const BouncingScrollPhysics(),
            padding:
            EdgeInsets.symmetric(
              horizontal: 24.w,
              vertical: 16.h,
            ),
            child: Column(
              children: [
                Center(
                  child: Semantics(
                    button: true,
                    label:
                    'Choose profile avatar',
                    child: GestureDetector(
                      onTap: () {
                        AvatarPickerSheet.show(
                          context,
                          userRole,
                              (id) {
                            if (!mounted) {
                              return;
                            }

                            setState(() {
                              currentAvatarId =
                                  id;
                            });
                          },
                        );
                      },
                      child: Stack(
                        alignment:
                        Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 45.r,
                            backgroundColor:
                            Colors.white12,
                            backgroundImage:
                            AssetImage(
                              'assets/avatars/$formattedAvatarId.png',
                            ),
                          ),
                          Container(
                            padding:
                            EdgeInsets.all(
                              6.r,
                            ),
                            decoration:
                            BoxDecoration(
                              color:
                              const Color(
                                0xFF1877F2,
                              ),
                              shape:
                              BoxShape.circle,
                              border:
                              Border.all(
                                color:
                                Colors.black,
                                width: 2.w,
                              ),
                            ),
                            child: Icon(
                              Icons
                                  .camera_alt,
                              color:
                              Colors.white,
                              size: 16.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 32.h,
                ),

                Container(
                  decoration:
                  BoxDecoration(
                    color:
                    const Color(
                      0xFF161616,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      16.r,
                    ),
                    border:
                    Border.all(
                      color:
                      Colors.white12,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildCompactField(
                        'Full Name',
                        nameController,
                        maxLength: 35,
                        inputFormatters: [
                          FilteringTextInputFormatter
                              .allow(
                            RegExp(
                              r'[a-zA-Z ]',
                            ),
                          ),
                        ],
                      ),
                      Divider(
                        color:
                        Colors.white12,
                        height: 1.h,
                        indent: 16.w,
                        endIndent: 16.w,
                      ),
                      _buildCompactField(
                        'Semester',
                        semesterController,
                        isNumber: true,
                      ),
                      Divider(
                        color:
                        Colors.white12,
                        height: 1.h,
                        indent: 16.w,
                        endIndent: 16.w,
                      ),
                      _buildCompactField(
                        'Section',
                        sectionController,
                        maxLength: 1,
                        inputFormatters: [
                          FilteringTextInputFormatter
                              .allow(
                            RegExp(
                              r'[a-cA-C]',
                            ),
                          ),
                          TextInputFormatter
                              .withFunction(
                                (
                                oldValue,
                                newValue,
                                ) {
                              return TextEditingValue(
                                text: newValue
                                    .text
                                    .toUpperCase(),
                                selection:
                                newValue
                                    .selection,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height: 24.h,
                ),

                Container(
                  decoration:
                  BoxDecoration(
                    color:
                    const Color(
                      0xFF161616,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      16.r,
                    ),
                    border:
                    Border.all(
                      color:
                      Colors.white12,
                      width: 1,
                    ),
                  ),
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(
                      dividerColor:
                      Colors.transparent,
                    ),
                    child:
                    ExpansionTile(
                      tilePadding:
                      EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 4.h,
                      ),
                      iconColor:
                      const Color(
                        0xFF1877F2,
                      ),
                      collapsedIconColor:
                      Colors.white54,
                      title: Text(
                        'Change Password',
                        style:
                        TextStyle(
                          color:
                          Colors.white,
                          fontSize: 16.sp,
                          fontWeight:
                          FontWeight.w500,
                        ),
                      ),
                      children: [
                        Divider(
                          color:
                          Colors.white12,
                          height: 1.h,
                        ),
                        _buildCompactField(
                          'Current Password',
                          currentPasswordController,
                          isPassword: true,
                          obscureText:
                          _obscureCurrent,
                          onToggleVisibility:
                              () {
                            setState(() {
                              _obscureCurrent =
                              !_obscureCurrent;
                            });
                          },
                        ),
                        Divider(
                          color:
                          Colors.white12,
                          height: 1.h,
                          indent: 16.w,
                          endIndent: 16.w,
                        ),
                        _buildCompactField(
                          'New Password',
                          passwordController,
                          isPassword: true,
                          obscureText:
                          _obscureNew,
                          onToggleVisibility:
                              () {
                            setState(() {
                              _obscureNew =
                              !_obscureNew;
                            });
                          },
                        ),
                        Divider(
                          color:
                          Colors.white12,
                          height: 1.h,
                          indent: 16.w,
                          endIndent: 16.w,
                        ),
                        _buildCompactField(
                          'Confirm New Password',
                          confirmPasswordController,
                          isPassword: true,
                          obscureText:
                          _obscureConfirm,
                          onToggleVisibility:
                              () {
                            setState(() {
                              _obscureConfirm =
                              !_obscureConfirm;
                            });
                          },
                        ),
                        SizedBox(
                          height: 8.h,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(
                  height: 24.h,
                ),

                Consumer(
                  builder:
                      (context, ref, child) {
                    final syncState = ref.watch(
                      syncControllerProvider,
                    );

                    return Container(
                      decoration:
                      BoxDecoration(
                        color:
                        const Color(
                          0xFF161616,
                        ),
                        borderRadius:
                        BorderRadius.circular(
                          16.r,
                        ),
                        border:
                        Border.all(
                          color:
                          Colors.white12,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildSettingsActionRow(
                            icon:
                            Icons.sync_rounded,
                            title:
                            'Sync Data',
                            trailingText:
                            syncState.isLoading
                                ? 'Syncing...'
                                : null,
                            trailingWidget:
                            syncState.isLoading
                                ? SizedBox(
                              width:
                              16.w,
                              height:
                              16.w,
                              child:
                              const CircularProgressIndicator(
                                color:
                                Colors.white54,
                                strokeWidth:
                                2,
                              ),
                            )
                                : null,
                            showDivider:
                            true,
                            onTap:
                            syncState.isLoading
                                ? null
                                : _syncData,
                          ),
                          _buildSettingsActionRow(
                            icon: Icons
                                .person_remove_rounded,
                            title:
                            'Delete Account',
                            iconColor:
                            Colors.redAccent,
                            textColor:
                            Colors.redAccent,
                            showDivider:
                            false,
                            hideChevron:
                            true,
                            onTap: _isDeleting
                                ? null
                                : _openDeleteConfirmation,
                          ),
                        ],
                      ),
                    );
                  },
                ),

                SizedBox(
                  height: 32.h,
                ),

                SizedBox(
                  width:
                  double.infinity,
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed:
                    _isUpdating
                        ? null
                        : handleUpdate,
                    style:
                    ElevatedButton.styleFrom(
                      backgroundColor:
                      const Color(
                        0xFF1877F2,
                      ),
                      disabledBackgroundColor:
                      Colors.white12,
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          16.r,
                        ),
                      ),
                    ),
                    child: _isUpdating
                        ? SizedBox(
                      height: 20.h,
                      width: 20.h,
                      child:
                      const CircularProgressIndicator(
                        color:
                        Colors.white,
                        strokeWidth:
                        2,
                      ),
                    )
                        : Text(
                      'Save Changes',
                      style:
                      TextStyle(
                        color:
                        Colors.white,
                        fontSize: 18.sp,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  height: 24.h,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactField(
      String label,
      TextEditingController controller, {
        bool isNumber = false,
        bool isPassword = false,
        bool obscureText = false,
        VoidCallback? onToggleVisibility,
        List<TextInputFormatter>?
        inputFormatters,
        int? maxLength,
      }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: isNumber
          ? TextInputType.number
          : TextInputType.text,
      style: TextStyle(
        color: Colors.white,
        fontSize: 16.sp,
      ),
      inputFormatters:
      inputFormatters,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
        TextStyle(
          color: Colors.white54,
          fontSize: 14.sp,
        ),
        counterText: '',
        filled: true,
        fillColor:
        Colors.transparent,
        border:
        InputBorder.none,
        contentPadding:
        EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 12.h,
        ),
        suffixIcon:
        isPassword
            ? IconButton(
          icon: Icon(
            obscureText
                ? Icons
                .visibility_off_outlined
                : Icons
                .visibility_outlined,
            color:
            Colors.white54,
            size: 20.sp,
          ),
          onPressed:
          onToggleVisibility,
        )
            : null,
      ),
    );
  }

  Widget _buildSettingsActionRow({
    required IconData icon,
    required String title,
    String? trailingText,
    Widget? trailingWidget,
    Color textColor = Colors.white,
    Color iconColor = Colors.white,
    required bool showDivider,
    bool hideChevron = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
      BorderRadius.circular(16.r),
      highlightColor:
      Colors.white10,
      splashColor:
      Colors.transparent,
      child: Column(
        children: [
          Padding(
            padding:
            EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: onTap == null
                      ? iconColor.withValues(
                    alpha: 0.45,
                  )
                      : iconColor,
                  size: 22.sp,
                ),
                SizedBox(
                  width: 16.w,
                ),
                Expanded(
                  child: Text(
                    title,
                    style:
                    TextStyle(
                      color: onTap == null
                          ? textColor
                          .withValues(
                        alpha: 0.45,
                      )
                          : textColor,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                if (trailingText !=
                    null)
                  Text(
                    trailingText,
                    style:
                    TextStyle(
                      color:
                      Colors.white54,
                      fontSize: 14.sp,
                    ),
                  ),
                if (trailingWidget !=
                    null)
                  Padding(
                    padding:
                    EdgeInsets.only(
                      left: 8.w,
                    ),
                    child:
                    trailingWidget,
                  ),
                if (!hideChevron)
                  Padding(
                    padding:
                    EdgeInsets.only(
                      left: 8.w,
                    ),
                    child: Icon(
                      Icons
                          .chevron_right_rounded,
                      color:
                      Colors.white30,
                      size: 20.sp,
                    ),
                  ),
              ],
            ),
          ),
          if (showDivider)
            Divider(
              color: Colors.white12,
              height: 1.h,
              indent: 54.w,
            ),
        ],
      ),
    );
  }
}