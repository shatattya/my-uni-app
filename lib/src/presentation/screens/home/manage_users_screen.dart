import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  Future<void> _updateUserField(String docId, String field, dynamic value) async {
    try {
      await FirebaseFirestore.instance.collection('students').doc(docId).update({
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update failed: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  void _showEditRoutingDialog(Map<String, dynamic> user, String docId) {
    int tempSemester = user['semester'] ?? 1;
    String tempSection = user['section'] ?? 'A';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
            title: Text("Edit Academic Route", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Semester", style: TextStyle(color: Colors.white70, fontSize: 14.sp)),
                SizedBox(height: 8.h),
                DropdownButtonFormField<int>(
                  value: tempSemester,
                  dropdownColor: const Color(0xFF2C2C2E),
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  items: [1, 2, 3, 4, 5, 6, 7, 8].map((e) => DropdownMenuItem(value: e, child: Text("Semester $e"))).toList(),
                  onChanged: (val) => setDialogState(() => tempSemester = val!),
                ),
                SizedBox(height: 16.h),
                Text("Section", style: TextStyle(color: Colors.white70, fontSize: 14.sp)),
                SizedBox(height: 8.h),
                DropdownButtonFormField<String>(
                  value: tempSection,
                  dropdownColor: const Color(0xFF2C2C2E),
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  items: ['A', 'B', 'C'].map((e) => DropdownMenuItem(value: e, child: Text("Section $e"))).toList(),
                  onChanged: (val) => setDialogState(() => tempSection = val!),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1877F2)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _updateUserField(docId, 'semester', tempSemester);
                  await _updateUserField(docId, 'section', tempSection);
                },
                child: const Text("Save", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('students');
    if (_searchQuery.isNotEmpty) {
      query = query
          .where('internalId', isGreaterThanOrEqualTo: _searchQuery)
          .where('internalId', isLessThanOrEqualTo: '$_searchQuery\uf8ff')
          .limit(20);
    } else {
      query = query.orderBy('createdAt', descending: true).limit(20);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text("Manage Students", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(20.w),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: Colors.white, fontSize: 16.sp),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: "Search by Internal ID...",
                hintStyle: TextStyle(color: Colors.white54, fontSize: 16.sp),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1877F2)));
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error fetching users.\n${snapshot.error}", textAlign: TextAlign.center, style: TextStyle(color: Colors.redAccent, fontSize: 14.sp)));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(child: Text("No students found.", style: TextStyle(color: Colors.white54, fontSize: 16.sp)));
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final docId = docs[index].id;
                    final bool isDev = data['isDev'] ?? false;
                    final bool isCR = data['isCR'] ?? false;

                    return Container(
                      margin: EdgeInsets.only(bottom: 16.h),
                      child: Material(
                        color: const Color(0xFF1E1E1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          side: const BorderSide(color: Colors.white12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          iconColor: Colors.white,
                          collapsedIconColor: Colors.white54,
                          title: Text(data['name'] ?? 'Unknown', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
                          subtitle: Text("${data['internalId']}  •  Sem ${data['semester'] ?? '-'} '${data['section'] ?? '-'}'", style: TextStyle(color: Colors.white70, fontSize: 13.sp)),
                          children: [
                            Divider(color: Colors.white12, height: 1.h),
                            SwitchListTile(
                              activeColor: Colors.amber,
                              title: Text("Developer Privileges", style: TextStyle(color: Colors.white, fontSize: 14.sp)),
                              subtitle: Text("Can manage app database & users", style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
                              value: isDev,
                              onChanged: (val) => _updateUserField(docId, 'isDev', val),
                            ),
                            SwitchListTile(
                              activeColor: const Color(0xFF1877F2),
                              title: Text("Class Representative (CR)", style: TextStyle(color: Colors.white, fontSize: 14.sp)),
                              subtitle: Text("Can post global & section announcements", style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
                              value: isCR,
                              onChanged: (val) => _updateUserField(docId, 'isCR', val),
                            ),
                            ListTile(
                              title: Text("Edit Academic Route", style: TextStyle(color: Colors.white, fontSize: 14.sp)),
                              subtitle: Text("Change Semester and Section", style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
                              trailing: Icon(Icons.edit_outlined, color: Colors.white, size: 20.sp),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _showEditRoutingDialog(data, docId);
                              },
                            ),
                            SizedBox(height: 8.h),
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