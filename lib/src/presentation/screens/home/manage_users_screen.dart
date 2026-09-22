import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../data/repositories/user_repository.dart';

class ManageUsersScreen
    extends ConsumerStatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  ConsumerState<ManageUsersScreen> createState() =>
      _ManageUsersScreenState();
}

class _ManageUsersScreenState
    extends ConsumerState<ManageUsersScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  String _searchQuery = '';

  Future<void> _updatePrivileges({
    required String docId,
    required String uid,
    required bool isDev,
    required bool isCR,
  }) async {
    try {
      await ref
          .read(userRepositoryProvider)
          .updateStudentPrivileges(
        studentDocId: docId,
        uid: uid,
        isDev: isDev,
        isCR: isCR,
      );

      if (!mounted) {
        return;
      }

      HapticFeedback.lightImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Privileges updated.',
          ),
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
            'Update failed: $e',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _updateAcademicRoute({
    required String docId,
    required int semester,
    required String section,
  }) async {
    try {
      await ref
          .read(userRepositoryProvider)
          .updateStudentAcademicRoute(
        studentDocId: docId,
        semester: semester,
        section: section,
      );

      if (!mounted) {
        return;
      }

      HapticFeedback.lightImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Academic route updated.',
          ),
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
            'Update failed: $e',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showEditRoutingDialog(
      Map<String, dynamic> user,
      String docId,
      ) {
    int tempSemester =
        int.tryParse(
          user['semester']?.toString() ?? '',
        ) ??
            1;

    String tempSection =
    (user['section']?.toString() ?? 'A')
        .trim()
        .toUpperCase();

    if (!const {'A', 'B', 'C'}
        .contains(tempSection)) {
      tempSection = 'A';
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor:
              const Color(0xFF1E1E1E),
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(16.r),
              ),
              title: Text(
                'Edit Academic Route',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize:
                MainAxisSize.min,
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    'Semester',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  DropdownButtonFormField<int>(
                    value: tempSemester,
                    dropdownColor:
                    const Color(0xFF2C2C2E),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                    ),
                    items:
                    List.generate(
                      8,
                          (index) => index + 1,
                    )
                        .map(
                          (value) =>
                          DropdownMenuItem(
                            value: value,
                            child: Text(
                              'Semester $value',
                            ),
                          ),
                    )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setDialogState(() {
                        tempSemester = value;
                      });
                    },
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Section',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  DropdownButtonFormField<String>(
                    value: tempSection,
                    dropdownColor:
                    const Color(0xFF2C2C2E),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                    ),
                    items: const [
                      'A',
                      'B',
                      'C',
                    ]
                        .map(
                          (value) =>
                          DropdownMenuItem(
                            value: value,
                            child:
                            Text(
                              'Section $value',
                            ),
                          ),
                    )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setDialogState(() {
                        tempSection = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(
                        dialogContext,
                      ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white54,
                    ),
                  ),
                ),
                ElevatedButton(
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    const Color(0xFF1877F2),
                  ),
                  onPressed: () async {
                    Navigator.pop(
                      dialogContext,
                    );

                    await _updateAcademicRoute(
                      docId: docId,
                      semester: tempSemester,
                      section: tempSection,
                    );
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query =
    FirebaseFirestore.instance
        .collection('students');

    if (_searchQuery.isNotEmpty) {
      query = query
          .where(
        'internalId',
        isGreaterThanOrEqualTo:
        _searchQuery,
      )
          .where(
        'internalId',
        isLessThanOrEqualTo:
        '$_searchQuery\uf8ff',
      )
          .limit(20);
    } else {
      query = query
          .orderBy(
        'createdAt',
        descending: true,
      )
          .limit(20);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Manage Students',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme:
        const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(20.w),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery =
                      value.trim();
                });
              },
              decoration: InputDecoration(
                hintText:
                'Search by Internal ID...',
                hintStyle: TextStyle(
                  color: Colors.white54,
                  fontSize: 16.sp,
                ),
                prefixIcon:
                const Icon(
                  Icons.search,
                  color: Colors.white54,
                ),
                filled: true,
                fillColor:
                const Color(0xFF1E1E1E),
                border:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(
                    12.r,
                  ),
                  borderSide:
                  BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child:
            StreamBuilder<
                QuerySnapshot<
                    Map<String, dynamic>>>(
              stream: query.snapshots(),
              builder:
                  (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child:
                    CircularProgressIndicator(
                      color:
                      Color(0xFF1877F2),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding:
                      EdgeInsets.all(
                        20.w,
                      ),
                      child: Text(
                        'Error fetching users.\n'
                            '${snapshot.error}',
                        textAlign:
                        TextAlign.center,
                        style:
                        TextStyle(
                          color:
                          Colors.redAccent,
                          fontSize:
                          14.sp,
                        ),
                      ),
                    ),
                  );
                }

                final docs =
                    snapshot.data?.docs ??
                        [];

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No students found.',
                      style:
                      TextStyle(
                        color:
                        Colors.white54,
                        fontSize:
                        16.sp,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                  EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 8.h,
                  ),
                  physics:
                  const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder:
                      (context, index) {
                    final data =
                    docs[index].data();

                    final docId =
                        docs[index].id;

                    final targetUid =
                        data['uid']
                            ?.toString()
                            .trim() ??
                            '';

                    final bool isDev =
                        data['isDev'] == true;

                    final bool isCR =
                        data['isCR'] == true;

                    return Container(
                      margin:
                      EdgeInsets.only(
                        bottom: 16.h,
                      ),
                      child: Material(
                        color:
                        const Color(
                          0xFF1E1E1E,
                        ),
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            16.r,
                          ),
                          side:
                          const BorderSide(
                            color:
                            Colors.white12,
                          ),
                        ),
                        clipBehavior:
                        Clip.antiAlias,
                        child:
                        ExpansionTile(
                          iconColor:
                          Colors.white,
                          collapsedIconColor:
                          Colors.white54,
                          title: Text(
                            data['name']
                                ?.toString() ??
                                'Unknown',
                            style:
                            TextStyle(
                              color:
                              Colors.white,
                              fontSize:
                              16.sp,
                              fontWeight:
                              FontWeight
                                  .bold,
                            ),
                          ),
                          subtitle: Text(
                            '${data['internalId'] ?? '-'}'
                                '  •  '
                                'Sem ${data['semester'] ?? '-'}'
                                ' \'${data['section'] ?? '-'}\'',
                            style:
                            TextStyle(
                              color:
                              Colors.white70,
                              fontSize:
                              13.sp,
                            ),
                          ),
                          children: [
                            Divider(
                              color:
                              Colors.white12,
                              height:
                              1.h,
                            ),
                            SwitchListTile(
                              activeColor:
                              Colors.amber,
                              title: Text(
                                'Developer Privileges',
                                style:
                                TextStyle(
                                  color:
                                  Colors.white,
                                  fontSize:
                                  14.sp,
                                ),
                              ),
                              subtitle: Text(
                                'Can manage app database & users',
                                style:
                                TextStyle(
                                  color:
                                  Colors.white54,
                                  fontSize:
                                  12.sp,
                                ),
                              ),
                              value:
                              isDev,
                              onChanged:
                              targetUid
                                  .isEmpty
                                  ? null
                                  : (value) =>
                                  _updatePrivileges(
                                    docId:
                                    docId,
                                    uid:
                                    targetUid,
                                    isDev:
                                    value,
                                    isCR:
                                    isCR,
                                  ),
                            ),
                            SwitchListTile(
                              activeColor:
                              const Color(
                                0xFF1877F2,
                              ),
                              title: Text(
                                'Class Representative (CR)',
                                style:
                                TextStyle(
                                  color:
                                  Colors.white,
                                  fontSize:
                                  14.sp,
                                ),
                              ),
                              subtitle: Text(
                                'Can post global & section announcements',
                                style:
                                TextStyle(
                                  color:
                                  Colors.white54,
                                  fontSize:
                                  12.sp,
                                ),
                              ),
                              value:
                              isCR,
                              onChanged:
                              targetUid
                                  .isEmpty
                                  ? null
                                  : (value) =>
                                  _updatePrivileges(
                                    docId:
                                    docId,
                                    uid:
                                    targetUid,
                                    isDev:
                                    isDev,
                                    isCR:
                                    value,
                                  ),
                            ),
                            ListTile(
                              title:
                              Text(
                                'Edit Academic Route',
                                style:
                                TextStyle(
                                  color:
                                  Colors.white,
                                  fontSize:
                                  14.sp,
                                ),
                              ),
                              subtitle:
                              Text(
                                'Change Semester and Section',
                                style:
                                TextStyle(
                                  color:
                                  Colors.white54,
                                  fontSize:
                                  12.sp,
                                ),
                              ),
                              trailing:
                              Icon(
                                Icons
                                    .edit_outlined,
                                color:
                                Colors.white,
                                size:
                                20.sp,
                              ),
                              onTap: () {
                                HapticFeedback
                                    .lightImpact();

                                _showEditRoutingDialog(
                                  data,
                                  docId,
                                );
                              },
                            ),
                            SizedBox(
                              height: 8.h,
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
        ],
      ),
    );
  }
}