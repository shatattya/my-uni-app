import 'package:flutter/material.dart';
// Adjusted path to find the profile router
import '../../profile/profile_router.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Simply returns the router you already built
    return const ProfileRouter();
  }
}