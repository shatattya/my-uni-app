import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart'
as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../data/repositories/user_repository.dart';
import '../../../data/local/app_database.dart';
import '../../widgets/developer_panel_sheet.dart';
import '../../../services/auth_service.dart';
import '../../routes/app_router.dart';

class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() =>
      _StudentProfileScreenState();
}

class _StudentProfileScreenState
    extends ConsumerState<StudentProfileScreen> {
  late Stream<User?> _userStream;

  @override
  void initState() {
    super.initState();

    final firebaseUser =
        firebase_auth.FirebaseAuth.instance.currentUser;

    if (firebaseUser != null) {
      _userStream = ref
          .read(userRepositoryProvider)
          .watchUser(firebaseUser.uid);
    } else {
      _userStream = const Stream<User?>.empty();
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
        const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Icon(
              Icons.logout_rounded,
              color: Colors.white,
              size: 28.sp,
            ),
            SizedBox(width: 10.w),
            Text(
              'Log Out',
              style: TextStyle(
                color: Colors.white,
                fontWeight:
                FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 15.sp,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white54,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx);

              try {
                await ref
                    .read(authServiceProvider)
                    .signOut();
              } catch (error, stackTrace) {
                debugPrint(
                  'Sign out failed: $error',
                );
                debugPrintStack(
                  stackTrace: stackTrace,
                );

                if (!context.mounted) {
                  return;
                }

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not log out. Please try again.',
                    ),
                    backgroundColor:
                    Colors.redAccent,
                  ),
                );

                return;
              }

              if (!context.mounted) {
                return;
              }

              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(
                AppRoutes.auth,
                    (route) => false,
              );
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
            child: const Text(
              'Log Out',
              style: TextStyle(
                color: Colors.white,
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser =
        firebase_auth.FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return Center(
        child: Text(
          'Not logged in',
          style: TextStyle(
            fontSize: 16.sp,
            color: Colors.white,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: StreamBuilder<User?>(
          stream: _userStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color:
                  Color(0xFF1877F2),
                ),
              );
            }

            if (!snapshot.hasData ||
                snapshot.data == null) {
              return const SizedBox();
            }

            final user = snapshot.data!;
            final formattedAvatarId =
            user.avatarId
                .toString()
                .padLeft(2, '0');

            return LayoutBuilder(
              builder:
                  (context, constraints) {
                return SingleChildScrollView(
                  physics:
                  const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                    BoxConstraints(
                      minHeight:
                      constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 24.h,
                        ),

                        CircleAvatar(
                          radius: 54.r,
                          backgroundColor:
                          Colors.transparent,
                          backgroundImage:
                          AssetImage(
                            'assets/avatars/$formattedAvatarId.png',
                          ),
                        ),
                        SizedBox(
                          height: 16.h,
                        ),

                        Padding(
                          padding:
                          EdgeInsets.symmetric(
                            horizontal: 20.w,
                          ),
                          child: Text(
                            user.name,
                            maxLines: 2,
                            overflow:
                            TextOverflow.ellipsis,
                            textAlign:
                            TextAlign.center,
                            style: TextStyle(
                              fontSize: 24.sp,
                              color:
                              Colors.white,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 12.h,
                        ),

                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            _badge(
                              'Student',
                              Colors
                                  .blueGrey.shade700,
                            ),
                            if (user.isCR) ...[
                              SizedBox(
                                width: 8.w,
                              ),
                              _badge(
                                'CR',
                                const Color(
                                  0xFF1877F2,
                                ),
                              ),
                            ],
                            if (user.isDev) ...[
                              SizedBox(
                                width: 8.w,
                              ),
                              _badge(
                                'Dev',
                                Colors
                                    .amber.shade800,
                              ),
                            ],
                          ],
                        ),
                        SizedBox(
                          height: 26.h,
                        ),

                        Padding(
                          padding:
                          EdgeInsets.symmetric(
                            horizontal: 20.w,
                          ),
                          child:
                          _buildGroupedCard([
                            _buildInfoRow(
                              Icons.badge_rounded,
                              'Internal ID',
                              user.internalId,
                              showDivider: true,
                            ),
                            _buildInfoRow(
                              Icons.school_rounded,
                              'Semester',
                              '${user.semester}th',
                              showDivider: true,
                            ),
                            _buildInfoRow(
                              Icons.groups_rounded,
                              'Section',
                              user.section,
                              showDivider: false,
                            ),
                          ]),
                        ),
                        SizedBox(
                          height: 18.h,
                        ),

                        Padding(
                          padding:
                          EdgeInsets.symmetric(
                            horizontal: 20.w,
                          ),
                          child:
                          _buildGroupedCard([
                            _buildActionRow(
                              icon:
                              Icons.edit_outlined,
                              title:
                              'Profile Settings',
                              showDivider:
                              user.isDev,
                              onTap: () {
                                HapticFeedback
                                    .lightImpact();

                                Navigator.pushNamed(
                                  context,
                                  AppRoutes
                                      .editStudentProfile,
                                );
                              },
                            ),
                            if (user.isDev)
                              _buildActionRow(
                                icon: Icons
                                    .developer_mode_rounded,
                                title:
                                'Developer Panel',
                                iconColor:
                                Colors.amber,
                                showDivider:
                                false,
                                onTap: () {
                                  HapticFeedback
                                      .mediumImpact();

                                  DeveloperPanelSheet
                                      .show(context);
                                },
                              ),
                          ]),
                        ),
                        SizedBox(
                          height: 18.h,
                        ),

                        Padding(
                          padding:
                          EdgeInsets.symmetric(
                            horizontal: 20.w,
                          ),
                          child:
                          _buildGroupedCard([
                            _buildActionRow(
                              icon:
                              Icons.logout_rounded,
                              title: 'Log Out',
                              textColor:
                              Colors.redAccent,
                              iconColor:
                              Colors.redAccent,
                              showDivider:
                              false,
                              hideChevron: true,
                              onTap: () {
                                HapticFeedback
                                    .mediumImpact();

                                _showLogoutDialog(
                                  context,
                                );
                              },
                            ),
                          ]),
                        ),

                        SizedBox(
                          height: 24.h,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _badge(
      String text,
      Color color,
      ) {
    return Container(
      padding:
      EdgeInsets.symmetric(
        horizontal: 12.w,
        vertical: 4.h,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius:
        BorderRadius.circular(12.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGroupedCard(
      List<Widget> children,
      ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius:
        BorderRadius.circular(16.r),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon,
      String title,
      String value, {
        required bool showDivider,
      }) {
    return Column(
      children: [
        Padding(
          padding:
          EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 14.h,
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white54,
                size: 22.sp,
              ),
              SizedBox(
                width: 16.w,
              ),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                ),
              ),
              SizedBox(
                width: 12.w,
              ),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  textAlign:
                  TextAlign.right,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16.sp,
                  ),
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
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String title,
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
                  color: iconColor,
                  size: 22.sp,
                ),
                SizedBox(
                  width: 16.w,
                ),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16.sp,
                    ),
                  ),
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