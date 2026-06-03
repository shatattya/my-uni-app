import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DeveloperTriageScreen extends StatelessWidget {
  const DeveloperTriageScreen({super.key});

  Future<void> _updateRequestStatus(String docId, String newStatus, BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('requests').doc(docId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request marked as $newStatus'),
            backgroundColor: newStatus == 'uploaded' ? Colors.green : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update request.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Pending Requests', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requests')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // MODIFICATION: Replaced CupertinoActivityIndicator
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading requests. Ensure Firestore index is built.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // MODIFICATION: Replaced CupertinoIcons
                  Icon(Icons.verified, color: Colors.green, size: 64),
                  SizedBox(height: 16),
                  Text('Inbox Zero!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('No pending book or note requests.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.all(16.w),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              final isBook = data['type'] == 'book';

              return Container(
                margin: EdgeInsets.only(bottom: 16.h),
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: isBook ? Colors.blueAccent.withOpacity(0.2) : Colors.orangeAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          // MODIFICATION: Replaced CupertinoIcons
                          child: Icon(
                            isBook ? Icons.menu_book : Icons.description,
                            color: isBook ? Colors.blueAccent : Colors.orangeAccent,
                            size: 20.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          isBook ? 'Book Request' : 'Note Request',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.sp),
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(
                            'Sem ${data['semester'] ?? '-'}',
                            style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16.h),

                    if (isBook) ...[
                      _buildInfoRow('Name:', data['bookName'] ?? 'Unknown'),
                      SizedBox(height: 4.h),
                      _buildInfoRow('Author:', data['authorName'] ?? 'Unknown'),
                      if (data['isbn'] != null && data['isbn'].toString().isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        _buildInfoRow('ISBN:', data['isbn']),
                      ]
                    ] else ...[
                      _buildInfoRow('Subject:', data['subjectName'] ?? 'Unknown'),
                    ],

                    SizedBox(height: 20.h),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _updateRequestStatus(docId, 'rejected', context),
                          // MODIFICATION: Replaced CupertinoIcons
                          icon: const Icon(Icons.cancel, color: Colors.redAccent),
                          label: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
                        ),
                        SizedBox(width: 12.w),
                        ElevatedButton.icon(
                          onPressed: () => _updateRequestStatus(docId, 'uploaded', context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                          ),
                          // MODIFICATION: Replaced CupertinoIcons
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Uploaded'),
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60.w,
          child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}