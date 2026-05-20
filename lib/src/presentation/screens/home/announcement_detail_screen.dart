import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // ADDED: For tap recognition on links
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart'; // ADDED: For launching URLs

class AnnouncementDetailScreen extends StatelessWidget {
  final dynamic notice;

  const AnnouncementDetailScreen({super.key, required this.notice});

  // HELPER: Parses text for URLs and makes them clickable
  List<InlineSpan> _buildTextSpans(String text, TextStyle baseStyle) {
    final RegExp urlRegExp = RegExp(r'(https?:\/\/[^\s]+)');
    final Iterable<RegExpMatch> matches = urlRegExp.allMatches(text);

    if (matches.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final List<InlineSpan> spans = [];
    int currentPosition = 0;

    for (final match in matches) {
      if (match.start > currentPosition) {
        spans.add(TextSpan(text: text.substring(currentPosition, match.start), style: baseStyle));
      }

      final String link = match.group(0)!;
      spans.add(
        TextSpan(
          text: link,
          style: baseStyle.copyWith(
            color: const Color(0xFF1877F2), // Premium Blue
            decoration: TextDecoration.none, // MODIFICATION: Removed the underline
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final Uri uri = Uri.parse(link);
              // MODIFICATION: Bypassed canLaunchUrl check which fails silently on newer OS versions
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (e) {
                debugPrint("Could not launch $link: $e");
              }
            },
        ),
      );
      currentPosition = match.end;
    }

    if (currentPosition < text.length) {
      spans.add(TextSpan(text: text.substring(currentPosition), style: baseStyle));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    // Extracted body style to share with the TextSpan builder
    final TextStyle bodyStyle = TextStyle(
      color: Colors.white70,
      fontSize: 17.sp, // Scaled and refined for readability
      height: 1.6,
      letterSpacing: 0.3,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text("Announcement", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 20.sp)), // Scaled
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w), // Scaled
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// TITLE (Now Selectable)
            SelectableText(
              notice.title,
              style: TextStyle(color: Colors.white, fontSize: 26.sp, fontWeight: FontWeight.bold, height: 1.3), // Scaled
            ),

            SizedBox(height: 24.h), // Scaled

            /// AUTHOR & DATE ROW
            Row(
              children: [
                CircleAvatar(
                  radius: 20.r, // Scaled
                  backgroundColor: const Color(0xFF1877F2).withValues(alpha: 0.2), // Premium subtle blue
                  child: Icon(Icons.person_outline, color: const Color(0xFF1877F2), size: 24.sp), // Premium outlined icon & scaled
                ),
                SizedBox(width: 16.w), // Scaled
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notice.authorName, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w500)), // Scaled
                    SizedBox(height: 4.h), // Scaled
                    Text(
                      DateFormat('dd MMMM yyyy • hh:mm a').format(notice.createdAt),
                      style: TextStyle(color: Colors.white54, fontSize: 13.sp), // Scaled
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 32.h), // Scaled
            const Divider(color: Colors.white12, thickness: 1),
            SizedBox(height: 24.h), // Scaled

            /// BODY TEXT (Now Selectable and Links are Clickable)
            SelectableText.rich(
              TextSpan(
                children: _buildTextSpans(notice.body, bodyStyle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}