import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/household_service.dart';
import '../models/household.dart';
import '../providers/subscription_provider.dart';
import 'ingredient_manager_screen.dart';
import 'paywall_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).value;
    final householdAsync = ref.watch(currentHouseholdProvider);
    final householdMembersAsync = ref.watch(householdMembersProvider);

    // Use the COMBINED Pro status (RevenueCat + Firestore)
    final isPro = ref.watch(effectiveProStatusProvider);
    final isProLoading = ref.watch(proStatusLoadingProvider);

    // Check Guest Status (For Apple Compliance)
    final isGuest = authUser?.isAnonymous ?? false;

    final primaryColor = Theme.of(context).colorScheme.primary;
    final backgroundColor = Theme.of(context).colorScheme.background;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- 1. PROFILE HEADER ---
            InkWell(
              onTap: () =>
                  _showEditProfileSheet(context, ref, authUser?.displayName),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 24,
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: isPro
                              ? Colors.amber.shade100
                              : primaryColor.withOpacity(0.1),
                          child: Text(
                            _getInitials(authUser?.displayName),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isPro
                                  ? Colors.amber.shade700
                                  : primaryColor,
                            ),
                          ),
                        ),
                        // Pro Badge on Avatar
                        if (isPro)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.star,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  authUser?.displayName ?? "User",
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isPro) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.amber.shade400,
                                        Colors.amber.shade600,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.amber.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.workspace_premium,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "PRO",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isGuest ? "Guest Account" : (authUser?.email ?? ""),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.edit_outlined,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- GUEST WARNING BANNER (For Apple Compliance) ---
            if (isGuest)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Guest Mode Active",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            Text(
                              "Your data is only saved on this device. Log out to create a real account.",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // --- 2. HOUSEHOLD CARD ---
            householdAsync.when(
              data: (household) {
                if (household == null) {
                  return _buildNoHouseholdCard(context);
                }
                return _buildHouseholdCard(
                  context,
                  ref,
                  household,
                  authUser?.uid,
                  householdMembersAsync,
                  primaryColor,
                  isPro,
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text("Error loading household: $e"),
              ),
            ),

            const SizedBox(height: 24),

            // --- 3. PREFERENCES ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.kitchen,
                          color: Colors.orange.shade400,
                          size: 20,
                        ),
                      ),
                      title: const Text("Custom Ingredients"),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.grey,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) => const IngredientManagerScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 64),

                    // Pro Status Section - handles loading state
                    if (isProLoading)
                      const ListTile(
                        leading: SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        title: Text("Checking subscription..."),
                      )
                    else if (!isPro)
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.amber.shade100,
                                Colors.amber.shade200,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.workspace_premium,
                            color: Colors.amber.shade700,
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          "Upgrade to Pro",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text("Unlimited recipes & members"),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "Upgrade",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PaywallScreen(),
                            ),
                          );
                        },
                      )
                    else
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.verified,
                            color: Colors.green.shade400,
                            size: 20,
                          ),
                        ),
                        title: const Text("Pro Subscription"),
                        subtitle: const Text(
                          "Active • Thank you for your support!",
                        ),
                        trailing: Icon(
                          Icons.check_circle,
                          color: Colors.green.shade400,
                        ),
                        onTap: () {
                          // Show subscription management info
                          _showProManagementSheet(context);
                        },
                      ),

                    const Divider(height: 1, indent: 64),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.logout,
                          color: Colors.red.shade400,
                          size: 20,
                        ),
                      ),
                      title: Text(isGuest ? "Exit Guest Mode" : "Log Out"),
                      onTap: () {
                        if (isGuest) {
                          // Warning for Guest Logout
                          showDialog(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text("Exit Guest Mode?"),
                              content: const Text(
                                "You will lose all data unless you sign up properly.",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(c);
                                    ref.read(authServiceProvider).signOut();
                                  },
                                  child: const Text(
                                    "Exit & Delete",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          ref.read(authServiceProvider).signOut();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                "FamilyEats v1.0.0",
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showProManagementSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.workspace_premium,
                size: 48,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "You're a Pro Member!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Thank you for supporting FamilyEats",
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildProFeatureRow(Icons.menu_book, "Unlimited Recipes"),
                  const SizedBox(height: 12),
                  _buildProFeatureRow(Icons.groups, "Unlimited Members"),
                  const SizedBox(height: 12),
                  _buildProFeatureRow(
                    Icons.calendar_month,
                    "Unlimited Meal Plans",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "To manage your subscription, go to your device's Settings > Subscriptions",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.green.shade600),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Icon(Icons.check, size: 18, color: Colors.green.shade600),
      ],
    );
  }

  Widget _buildNoHouseholdCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.home_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                "No Household",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "You're not part of a household yet.",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHouseholdCard(
    BuildContext context,
    WidgetRef ref,
    Household household,
    String? currentUserId,
    AsyncValue<List<Map<String, dynamic>>> membersAsync,
    Color primaryColor,
    bool currentUserIsPro,
  ) {
    final isOwner = household.ownerId == currentUserId;
    final members = membersAsync.value ?? [];

    // Check the Household Owner's Pro Status
    final isHouseholdPro = ref.watch(householdLimitProvider).value ?? false;

    // Limit Logic: If Owner is NOT Pro, max members = 2
    final isLimitReached = !isHouseholdPro && members.length >= 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isHouseholdPro
                          ? Colors.amber.shade50
                          : primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.home_filled,
                      color: isHouseholdPro ? Colors.amber : primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                household.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isHouseholdPro) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.workspace_premium,
                                      size: 12,
                                      color: Colors.amber.shade700,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      "PRO",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (isOwner)
                          Text(
                            "You're the owner",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Limits Info Banner (if not pro)
              if (!isHouseholdPro)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isOwner
                              ? "Free plan: 2 members, 5 recipes. Upgrade to unlock unlimited!"
                              : "Free plan: 2 members, 5 recipes. Ask owner to upgrade.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!isHouseholdPro) const SizedBox(height: 16),

              // Invite Code Section
              Text(
                isLimitReached
                    ? "Household limit reached (2 members)"
                    : "Share this code to invite others",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 12),

              // --- INVITE CODE OR UPGRADE BUTTON ---
              if (isLimitReached)
                InkWell(
                  onTap: isOwner
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PaywallScreen(),
                          ),
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 20,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOwner
                              ? "Upgrade to invite more"
                              : "Ask owner to upgrade",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                InkWell(
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: household.inviteCode),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Invite code copied: ${household.inviteCode}",
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            household.inviteCode,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        Icon(Icons.copy, size: 20, color: primaryColor),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // --- MEMBERS LIST ---
              Row(
                children: [
                  Text(
                    "MEMBERS",
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "${members.length}${!isHouseholdPro ? '/2' : ''}",
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              membersAsync.when(
                data: (members) {
                  if (members.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("No members found."),
                    );
                  }
                  return Column(
                    children: members.map((member) {
                      final isMe = member['uid'] == currentUserId;
                      final isMemberOwner = member['uid'] == household.ownerId;
                      final memberIsPro = member['isPro'] == true;

                      String memberName = member['name'] as String? ?? '';
                      if (memberName.isEmpty) {
                        final email = member['email'] as String? ?? '';
                        if (email.isNotEmpty) {
                          memberName = email.split('@').first;
                        } else {
                          memberName = isMe ? 'Me' : 'Member';
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe
                              ? primaryColor.withOpacity(0.05)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isMe
                                ? primaryColor.withOpacity(0.2)
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isMemberOwner && memberIsPro
                                      ? Colors.amber.shade100
                                      : isMe
                                      ? primaryColor.withOpacity(0.2)
                                      : Colors.grey.shade200,
                                  child: Text(
                                    _getInitials(memberName),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isMemberOwner && memberIsPro
                                          ? Colors.amber.shade700
                                          : isMe
                                          ? primaryColor
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                // Pro indicator on avatar
                                if (memberIsPro)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.star,
                                        size: 8,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          memberName,
                                          style: TextStyle(
                                            fontWeight: isMe
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            fontSize: 15,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: primaryColor.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            "You",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (isMemberOwner)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            "Owner",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ),
                                      if (isMemberOwner && memberIsPro)
                                        const SizedBox(width: 6),
                                      if (memberIsPro)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade50,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.workspace_premium,
                                                size: 10,
                                                color: Colors.amber.shade700,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                "Pro",
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.amber.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(
                  "Could not load members",
                  style: TextStyle(color: Colors.red.shade300),
                ),
              ),

              const SizedBox(height: 24),

              // --- LEAVE / SETTINGS BUTTONS ---
              if (!isOwner)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showLeaveDialog(context, ref),
                    icon: const Icon(
                      Icons.exit_to_app,
                      size: 18,
                      color: Colors.red,
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade200),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: Colors.red,
                    ),
                    label: const Text("Leave Household"),
                  ),
                ),

              if (isOwner) ...[
                const Divider(height: 32),
                Text(
                  "HOUSEHOLD SETTINGS",
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined, color: primaryColor),
                  title: const Text("Rename Household"),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () => _showRenameDialog(context, ref, household),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.refresh, color: primaryColor),
                  title: const Text("Regenerate Invite Code"),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () =>
                      _showRegenerateCodeDialog(context, ref, household),
                ),
                membersAsync.when(
                  data: (members) {
                    final otherMembers = members
                        .where((m) => m['uid'] != currentUserId)
                        .toList();
                    if (otherMembers.isNotEmpty) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.swap_horiz, color: primaryColor),
                        title: const Text("Transfer Ownership"),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                        ),
                        onTap: () => _showTransferOwnershipDialog(
                          context,
                          ref,
                          household,
                          otherMembers,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const Divider(height: 24),
                Text(
                  "DANGER ZONE",
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                membersAsync.when(
                  data: (members) {
                    final otherMembers = members
                        .where((m) => m['uid'] != currentUserId)
                        .toList();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.exit_to_app, color: Colors.red),
                      title: const Text(
                        "Leave Household",
                        style: TextStyle(color: Colors.red),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.grey,
                      ),
                      onTap: () => _showOwnerLeaveDialog(
                        context,
                        ref,
                        household,
                        otherMembers,
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text(
                    "Delete Household",
                    style: TextStyle(color: Colors.red),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () =>
                      _showDeleteHouseholdDialog(context, ref, household),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER METHODS ---

  void _showLeaveDialog(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Leave Household?"),
        content: const Text(
          "You'll need to create a new household or join another one to continue using the app.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Leave", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(userServiceProvider)?.leaveHousehold();
    }
  }

  void _showEditProfileSheet(
    BuildContext context,
    WidgetRef ref,
    String? currentName,
  ) {
    final controller = TextEditingController(text: currentName ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: EdgeInsets.only(bottom: bottomPadding),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3A2D),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Display Name',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        final newName = controller.text.trim();
                        if (newName.isEmpty) return;

                        await ref
                            .read(userServiceProvider)
                            ?.updateName(newName);

                        await ref
                            .read(authServiceProvider)
                            .currentUser
                            ?.updateDisplayName(newName);

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile updated!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A6C47),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showOwnerLeaveDialog(
    BuildContext context,
    WidgetRef ref,
    Household household,
    List<Map<String, dynamic>> otherMembers,
  ) async {
    if (otherMembers.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Can't Leave"),
          content: const Text(
            "You're the only member of this household. You can delete the household instead, or invite someone and transfer ownership to them first.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    final selectedMember = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Transfer Ownership to Leave"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "As the owner, you must transfer ownership before leaving. Select the new owner:",
            ),
            const SizedBox(height: 16),
            ...otherMembers.map((member) {
              final memberName = member['name'] ?? 'Member';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade100,
                  child: Text(
                    _getInitials(memberName),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                title: Text(memberName),
                onTap: () => Navigator.pop(dialogContext, member),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );

    if (selectedMember != null && context.mounted) {
      final memberName = selectedMember['name'] ?? 'this member';
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Confirm Transfer & Leave"),
          content: Text(
            'Transfer ownership to $memberName and leave the household?\n\nThis action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text("Transfer & Leave"),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await ref
            .read(householdServiceProvider)
            .transferOwnership(household.id, selectedMember['uid']);
        await ref.read(userServiceProvider)?.leaveHousehold();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ownership transferred to $memberName'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showTransferOwnershipDialog(
    BuildContext context,
    WidgetRef ref,
    Household household,
    List<Map<String, dynamic>> otherMembers,
  ) async {
    final selectedMember = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Transfer Ownership"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select the new owner of this household:"),
            const SizedBox(height: 16),
            ...otherMembers.map((member) {
              final memberName = member['name'] ?? 'Member';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade100,
                  child: Text(
                    _getInitials(memberName),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                title: Text(memberName),
                onTap: () => Navigator.pop(dialogContext, member),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );

    if (selectedMember != null && context.mounted) {
      final memberName = selectedMember['name'] ?? 'this member';
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Confirm Transfer"),
          content: Text(
            'Transfer ownership to $memberName?\n\nThey will become the new owner and you will become a regular member.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A6C47),
                foregroundColor: Colors.white,
              ),
              child: const Text("Transfer"),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await ref
            .read(householdServiceProvider)
            .transferOwnership(household.id, selectedMember['uid']);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ownership transferred to $memberName'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showDeleteHouseholdDialog(
    BuildContext context,
    WidgetRef ref,
    Household household,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Household?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "This will permanently delete:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildDeleteItem("All recipes"),
            _buildDeleteItem("All meal plans"),
            _buildDeleteItem("All custom ingredients"),
            _buildDeleteItem("Remove all members"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "This action cannot be undone!",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
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
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Delete Forever"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(householdServiceProvider).deleteHousehold(household.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Household deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.remove_circle, size: 16, color: Colors.red.shade300),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    Household household,
  ) async {
    final controller = TextEditingController(text: household.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Rename Household"),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: "Household Name",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A6C47),
              foregroundColor: Colors.white,
            ),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty) {
      await ref
          .read(householdServiceProvider)
          .updateHouseholdName(household.id, newName);
    }
  }

  void _showRegenerateCodeDialog(
    BuildContext context,
    WidgetRef ref,
    Household household,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Regenerate Code?"),
        content: const Text(
          "The old invite code will stop working. Anyone who hasn't joined yet will need the new code.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A6C47),
              foregroundColor: Colors.white,
            ),
            child: const Text("Regenerate"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final newCode = await ref
          .read(householdServiceProvider)
          .regenerateInviteCode(household.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("New invite code: $newCode"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return "?";
    final parts = name.trim().split(" ");
    if (parts.isEmpty) return "?";
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
