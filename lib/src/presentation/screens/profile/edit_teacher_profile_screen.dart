import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../data/repositories/user_repository.dart';
import '../../../providers/profile_controller.dart';
import '../../../providers/sync_controller.dart';
import '../../../services/auth_service.dart';
import '../../routes/app_router.dart';
import '../../widgets/avatar_picker_sheet.dart';

class EditTeacherProfileScreen extends ConsumerStatefulWidget {
  const EditTeacherProfileScreen({super.key});

  @override
  ConsumerState<EditTeacherProfileScreen> createState() =>
      _EditTeacherProfileScreenState();
}

class _EditTeacherProfileScreenState
    extends ConsumerState<EditTeacherProfileScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  final TextEditingController currentPasswordController =
  TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
  TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  int currentAvatarId = 10;
  String userRole = 'teacher';
  String _internalId = '';

  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return;
    }

    emailController.text = firebaseUser.email ?? '';

    try {
      final user = await ref
          .read(userRepositoryProvider)
          .getUserLocally(firebaseUser.uid);

      if (!mounted || user == null) {
        return;
      }

      setState(() {
        nameController.text = user.name;
        currentAvatarId = user.avatarId;
        userRole = user.role;
        _internalId = user.internalId;
      });
    } catch (e, stackTrace) {
      debugPrint('Failed to load teacher profile: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load profile: ${e.toString().replaceAll("Exception: ", "")}',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    currentPasswordController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    final name = nameController.text.trim();
    final currentPassword = currentPasswordController.text.trim();
    final newPassword = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (newPassword.isNotEmpty && currentPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Current password is required to set a new password.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();

    setState(() {
      _isUpdating = true;
    });

    await ref.read(profileControllerProvider.notifier).updateTeacherProfile(
      name: name,
      avatarId: currentAvatarId,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> _syncData() async {
    final syncState = ref.read(syncControllerProvider);

    if (syncState.isLoading) {
      return;
    }

    HapticFeedback.lightImpact();

    try {
      await ref.read(syncControllerProvider.notifier).syncAllData();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data synced successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showDeleteAccountDialog() {
    if (_internalId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teacher profile data is unavailable. Please sync first.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final passwordController = TextEditingController();

    bool isDeleting = false;
    bool obscureText = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 28.sp,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Delete Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This action is permanent and cannot be undone. '
                        'Your cloud profile and local app data will be erased.\n\n'
                        'Enter your password to confirm.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14.sp,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: passwordController,
                    obscureText: obscureText,
                    enabled: !isDeleting,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: const TextStyle(
                        color: Colors.white54,
                      ),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureText
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white54,
                          size: 20.sp,
                        ),
                        onPressed: isDeleting
                            ? null
                            : () {
                          setDialogState(() {
                            obscureText = !obscureText;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                  isDeleting ? null : () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                    final password = passwordController.text.trim();

                    if (password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password is required'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    HapticFeedback.heavyImpact();

                    setDialogState(() {
                      isDeleting = true;
                    });

                    try {
                      await ref.read(authServiceProvider).deleteAccount(
                        password: password,
                        role: 'teacher',
                        docId: _internalId,
                      );

                      if (!dialogContext.mounted) {
                        return;
                      }

                      Navigator.of(
                        dialogContext,
                        rootNavigator: true,
                      ).pushNamedAndRemoveUntil(
                        AppRoutes.auth,
                            (route) => false,
                      );
                    } catch (e) {
                      if (!dialogContext.mounted) {
                        return;
                      }

                      setDialogState(() {
                        isDeleting = false;
                      });

                      HapticFeedback.heavyImpact();

                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            e
                                .toString()
                                .replaceAll('Exception: ', ''),
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    } finally {
                      passwordController.clear();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    disabledBackgroundColor: Colors.redAccent.withOpacity(0.45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: isDeleting
                      ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(passwordController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final formattedAvatarId = currentAvatarId.toString().padLeft(2, '0');

    ref.listen<AsyncValue<void>>(
      profileControllerProvider,
          (previous, next) {
        if (!_isUpdating || next.isLoading) {
          return;
        }

        if (mounted) {
          setState(() {
            _isUpdating = false;
          });
        }

        if (next.hasError) {
          if (!mounted) {
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                next.error
                    ?.toString()
                    .replaceAll('Exception: ', '') ??
                    'Failed to update profile.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }

        if (next.hasValue && mounted) {
          HapticFeedback.mediumImpact();

          final messenger = ScaffoldMessenger.of(context);
          Navigator.of(context).pop();

          messenger.showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(
            color: Colors.white,
          ),
          title: Text(
            'Profile Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: 24.w,
            vertical: 16.h,
          ),
          child: Column(
            children: [
              Center(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();

                    AvatarPickerSheet.show(
                      context,
                      userRole,
                          (id) {
                        if (!mounted) {
                          return;
                        }

                        setState(() {
                          currentAvatarId = id;
                        });
                      },
                    );
                  },
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 45.r,
                        backgroundColor: Colors.white12,
                        backgroundImage: AssetImage(
                          'assets/avatars/$formattedAvatarId.png',
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1877F2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.black,
                            width: 2.w,
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32.h),

              // Basic information.
              _buildSectionCard(
                children: [
                  _buildCompactField(
                    'Full Name',
                    nameController,
                    maxLength: 100,
                  ),
                  Divider(
                    color: Colors.white12,
                    height: 1.h,
                    indent: 16.w,
                    endIndent: 16.w,
                  ),
                  _buildCompactField(
                    'E-mail',
                    emailController,
                    enabled: false,
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              // Password settings.
              _buildSectionCard(
                children: [
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 4.h,
                      ),
                      iconColor: const Color(0xFF1877F2),
                      collapsedIconColor: Colors.white54,
                      title: Text(
                        'Change Password',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      children: [
                        Divider(
                          color: Colors.white12,
                          height: 1.h,
                        ),
                        _buildCompactField(
                          'Current Password',
                          currentPasswordController,
                          isPassword: true,
                          obscureText: _obscureCurrent,
                          onToggleVisibility: () {
                            setState(() {
                              _obscureCurrent = !_obscureCurrent;
                            });
                          },
                        ),
                        Divider(
                          color: Colors.white12,
                          height: 1.h,
                          indent: 16.w,
                          endIndent: 16.w,
                        ),
                        _buildCompactField(
                          'New Password',
                          passwordController,
                          isPassword: true,
                          obscureText: _obscureNew,
                          onToggleVisibility: () {
                            setState(() {
                              _obscureNew = !_obscureNew;
                            });
                          },
                        ),
                        Divider(
                          color: Colors.white12,
                          height: 1.h,
                          indent: 16.w,
                          endIndent: 16.w,
                        ),
                        _buildCompactField(
                          'Confirm New Password',
                          confirmPasswordController,
                          isPassword: true,
                          obscureText: _obscureConfirm,
                          onToggleVisibility: () {
                            setState(() {
                              _obscureConfirm = !_obscureConfirm;
                            });
                          },
                        ),
                        SizedBox(height: 8.h),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 32.h),

              // Save changes.
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: _isUpdating ? null : _handleUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1877F2),
                    disabledBackgroundColor:
                    const Color(0xFF1877F2).withOpacity(0.45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: _isUpdating
                      ? SizedBox(
                    height: 20.h,
                    width: 20.h,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 32.h),

              // Account settings.
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 4.w,
                    bottom: 10.h,
                  ),
                  child: Text(
                    'Account',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              Consumer(
                builder: (context, ref, child) {
                  final syncState = ref.watch(syncControllerProvider);

                  return _buildSectionCard(
                    children: [
                      _buildSettingsActionRow(
                        icon: Icons.sync_rounded,
                        title: 'Sync Data',
                        trailingText:
                        syncState.isLoading ? 'Syncing...' : null,
                        trailingWidget: syncState.isLoading
                            ? SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: const CircularProgressIndicator(
                            color: Colors.white54,
                            strokeWidth: 2,
                          ),
                        )
                            : null,
                        showDivider: true,
                        onTap: syncState.isLoading ? null : _syncData,
                      ),
                      _buildSettingsActionRow(
                        icon: Icons.person_remove_rounded,
                        title: 'Delete Account',
                        textColor: Colors.redAccent,
                        iconColor: Colors.redAccent,
                        showDivider: false,
                        hideChevron: true,
                        onTap: () {
                          HapticFeedback.heavyImpact();
                          _showDeleteAccountDialog();
                        },
                      ),
                    ],
                  );
                },
              ),

              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Colors.white12,
          width: 1,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildCompactField(
      String label,
      TextEditingController controller, {
        bool isPassword = false,
        bool enabled = true,
        bool obscureText = false,
        VoidCallback? onToggleVisibility,
        int? maxLength,
      }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      maxLength: maxLength,
      keyboardType: isPassword
          ? TextInputType.visiblePassword
          : TextInputType.text,
      style: TextStyle(
        color: enabled ? Colors.white : Colors.white54,
        fontSize: 16.sp,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: enabled ? Colors.white54 : Colors.white30,
          fontSize: 14.sp,
        ),
        counterText: '',
        filled: true,
        fillColor: Colors.transparent,
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 12.h,
        ),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.white54,
            size: 20.sp,
          ),
          onPressed: onToggleVisibility,
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
      borderRadius: BorderRadius.circular(16.r),
      highlightColor: Colors.white10,
      splashColor: Colors.transparent,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: iconColor,
                  size: 22.sp,
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                if (trailingText != null)
                  Text(
                    trailingText,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14.sp,
                    ),
                  ),
                if (trailingWidget != null)
                  Padding(
                    padding: EdgeInsets.only(left: 8.w),
                    child: trailingWidget,
                  ),
                if (!hideChevron)
                  Padding(
                    padding: EdgeInsets.only(left: 8.w),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white30,
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