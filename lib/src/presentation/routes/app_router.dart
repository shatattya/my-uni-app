import 'package:flutter/material.dart';

import '../../data/local/app_database.dart';
import '../screens/attendance/attendance_export_screen.dart';
import '../screens/attendance/attendance_marking_screen.dart';
import '../screens/attendance/attendance_setup_screen.dart';
import '../screens/auth/auth_wrapper.dart';
import '../screens/books_catalog_screen.dart';
import '../screens/home/announcement_detail_screen.dart';
import '../screens/home/contact_us_screen.dart';
import '../screens/home/create_announcement_screen.dart';
import '../screens/home/developer_triage_screen.dart';
import '../screens/home/edit_announcement_screen.dart';
import '../screens/home/exam_routine_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/live_events_screen.dart';
import '../screens/home/manage_users_screen.dart';
import '../screens/home/system_insights_screen.dart';
import '../screens/login/login_sceen.dart';
import '../screens/notes_catalog_screen.dart';
import '../screens/profile/edit_student_profile_screen.dart';
import '../screens/profile/edit_teacher_profile_screen.dart';
import '../screens/signup/privacy_policy_screen.dart';
import '../screens/signup/signup_screen.dart';
import '../screens/signup/teacher_signup_screen.dart';
import '../screens/welcome/welcome_screen.dart';

class AppRoutes {
  static const String auth = '/';
  static const String welcome = '/welcome';
  static const String home = '/home';
  static const String login = '/login';
  static const String studentSignup = '/signup/student';
  static const String teacherSignup = '/signup/teacher';
  static const String privacyPolicy = '/signup/privacy';
  static const String examRoutine = '/routine/exam';
  static const String notes = '/notes';
  static const String books = '/books';
  static const String liveEvents = '/events/live';
  static const String attendanceSetup = '/attendance/setup';
  static const String attendanceExport = '/attendance/export';
  static const String attendanceMarking = '/attendance/marking';
  static const String devTriage = '/dev/triage';
  static const String contact = '/contact';
  static const String editStudentProfile = '/profile/student/edit';
  static const String editTeacherProfile = '/profile/teacher/edit';
  static const String createAnnouncement = '/announcement/create';
  static const String detailAnnouncement = '/announcement/detail';
  static const String editAnnouncement = '/announcement/edit';

  static const String systemInsights = '/dev/insights';
  static const String manageUsers = '/dev/users';
}

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.auth:
        return _buildFadeRoute(
          const AuthWrapper(),
          settings,
        );

      case AppRoutes.welcome:
        return _buildFadeRoute(
          const WelcomeScreen(),
          settings,
        );

      case AppRoutes.home:
        return _buildFadeRoute(
          const HomeScreen(),
          settings,
        );

      case AppRoutes.login:
        return _buildSlideRoute(
          const LoginScreen(),
          settings,
        );

      case AppRoutes.studentSignup:
        return _buildSlideRoute(
          const SignupScreen(),
          settings,
        );

      case AppRoutes.teacherSignup:
        return _buildSlideRoute(
          const TeacherSignupScreen(),
          settings,
        );

      case AppRoutes.privacyPolicy:
        return _buildSlideRoute(
          const PrivacyPolicyScreen(),
          settings,
        );

      case AppRoutes.examRoutine:
        return _buildSlideRoute(
          const ExamRoutineScreen(),
          settings,
        );

      case AppRoutes.notes:
        return _buildSlideRoute(
          const NotesCatalogScreen(),
          settings,
        );

      case AppRoutes.books:
        return _buildSlideRoute(
          const BooksCatalogScreen(),
          settings,
        );

      case AppRoutes.liveEvents:
        return _buildSlideRoute(
          const LiveEventsScreen(),
          settings,
        );

      case AppRoutes.attendanceSetup:
        return _buildSlideRoute(
          const AttendanceSetupScreen(),
          settings,
        );

      case AppRoutes.attendanceExport:
        return _buildSlideRoute(
          const AttendanceExportScreen(),
          settings,
        );

      case AppRoutes.attendanceMarking:
        final args = settings.arguments;

        if (args is Map<String, dynamic>) {
          return _buildSlideRoute(
            AttendanceMarkingScreen(
              subjectName: args['subjectName'],
              semester: args['semester'],
              section: args['section'],
              date: args['date'],
            ),
            settings,
          );
        }

        return _errorRoute(settings);

      case AppRoutes.devTriage:
        return _buildSlideRoute(
          const DeveloperTriageScreen(),
          settings,
        );

      case AppRoutes.contact:
        return _buildSlideRoute(
          const ContactUsScreen(),
          settings,
        );

      case AppRoutes.editStudentProfile:
        return _buildSlideRoute(
          const EditStudentProfileScreen(),
          settings,
        );

      case AppRoutes.editTeacherProfile:
        return _buildSlideRoute(
          const EditTeacherProfileScreen(),
          settings,
        );

      case AppRoutes.createAnnouncement:
        return _buildSlideRoute(
          const CreateAnnouncementScreen(),
          settings,
        );

      case AppRoutes.detailAnnouncement:
        final notice = settings.arguments;

        if (notice != null) {
          return _buildSlideRoute(
            AnnouncementDetailScreen(
              notice: notice,
            ),
            settings,
          );
        }

        return _errorRoute(settings);

      case AppRoutes.editAnnouncement:
        final args = settings.arguments;

        if (args is Announcement) {
          return _buildSlideRoute(
            EditAnnouncementScreen(
              notice: args,
            ),
            settings,
          );
        }

        return _errorRoute(settings);

      case AppRoutes.systemInsights:
        return _buildSlideRoute(
          const SystemInsightsScreen(),
          settings,
        );

      case AppRoutes.manageUsers:
        return _buildSlideRoute(
          const ManageUsersScreen(),
          settings,
        );

      default:
        return _errorRoute(settings);
    }
  }

  static PageRouteBuilder<dynamic> _buildSlideRoute(
      Widget page,
      RouteSettings settings,
      ) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      pageBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          ) {
        return page;
      },
      transitionsBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
          ) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        final tween = Tween<Offset>(
          begin: begin,
          end: end,
        ).chain(
          CurveTween(curve: curve),
        );

        final offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }

  static PageRouteBuilder<dynamic> _buildFadeRoute(
      Widget page,
      RouteSettings settings,
      ) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      pageBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          ) {
        return page;
      },
      transitionsBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
          ) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  static Route<dynamic> _errorRoute(
      RouteSettings settings,
      ) {
    return MaterialPageRoute<dynamic>(
      builder: (BuildContext context) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text('Routing Error'),
            backgroundColor: Colors.black,
          ),
          body: Center(
            child: Text(
              'No route defined for ${settings.name}\n'
                  'or missing arguments.',
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}