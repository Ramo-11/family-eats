import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/household_service.dart';
import '../models/household.dart';
import '../providers/subscription_provider.dart';
import 'ingredient_manager_screen.dart';
import 'paywall_screen.dart';
import 'components/profile_header.dart';
import 'components/household_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).value;
    final householdAsync = ref.watch(currentHouseholdProvider);
    final householdMembersAsync = ref.watch(householdMembersProvider);

    final isPro = ref.watch(effectiveProStatusProvider);
    final isProLoading = ref.watch(proStatusLoadingProvider);
    final isGuest = authUser?.isAnonymous ?? false;

    final primaryColor = Theme.of(context).colorScheme.primary;
    final backgroundColor = Theme.of(context).colorScheme.surface;

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
            ProfileHeader(
              displayName: authUser?.displayName,
              email: authUser?.email,
              isPro: isPro,
              isGuest: isGuest,
              primaryColor: primaryColor,
              onEdit: () =>
                  _showEditProfileSheet(context, ref, authUser?.displayName),
            ),
            const SizedBox(height: 16),

            if (isGuest) _buildGuestWarning(context, ref),

            householdAsync.when(
              data: (household) {
                if (household == null) return _buildNoHouseholdCard(context);

                final isHouseholdPro =
                    ref.watch(householdLimitProvider).value ?? false;

                return HouseholdCard(
                  household: household,
                  currentUserId: authUser?.uid,
                  members: householdMembersAsync.value ?? [],
                  isHouseholdPro: isHouseholdPro,
                  primaryColor: primaryColor,
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

            _buildPreferencesList(
              context,
              ref,
              isPro,
              isProLoading,
              isGuest,
              householdAsync.value,
              householdMembersAsync.value ?? [],
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

  Widget _buildGuestWarning(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
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
                    "Your data is only saved on this device. Create an account to keep your recipes!",
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

  Widget _buildPreferencesList(
    BuildContext context,
    WidgetRef ref,
    bool isPro,
    bool isProLoading,
    bool isGuest,
    Household? household,
    List<Map<String, dynamic>> members,
  ) {
    final user = ref.watch(authServiceProvider).currentUser;
    final isOwner = household?.ownerId == user?.uid;

    return Padding(
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
              leading: _buildIcon(
                Icons.kitchen,
                Colors.orange.shade400,
                Colors.orange.shade50,
              ),
              title: const Text("Custom Ingredients"),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => const IngredientManagerScreen(),
                ),
              ),
            ),
            const Divider(height: 1, indent: 64),
            _buildProStatusTile(context, isPro, isProLoading),

            if (household != null && isOwner) ...[
              const Divider(height: 1, indent: 64),
              ListTile(
                leading: _buildIcon(
                  Icons.settings,
                  Colors.blue,
                  Colors.blue.shade50,
                ),
                title: const Text("Household Settings"),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () => _showHouseholdSettings(
                  context,
                  ref,
                  household,
                  members,
                  user?.uid,
                ),
              ),
            ],

            const Divider(height: 1, indent: 64),
            ListTile(
              leading: _buildIcon(
                Icons.logout,
                Colors.red.shade400,
                Colors.red.shade50,
              ),
              title: Text(isGuest ? "Exit Guest Mode" : "Log Out"),
              onTap: () => _handleLogout(context, ref, isGuest),
            ),
            const Divider(height: 1, indent: 64),
            ListTile(
              leading: _buildIcon(
                Icons.delete_forever,
                Colors.red,
                Colors.red.shade50,
              ),
              title: const Text(
                "Delete Account",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () =>
                  _handleDeleteAccount(context, ref, household, members, isPro),
            ),
          ],
        ),
      ),
    );
  }

  void _showHouseholdSettings(
    BuildContext context,
    WidgetRef ref,
    Household household,
    List<Map<String, dynamic>> members,
    String? currentUserId,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Container(
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
            const SizedBox(height: 16),
            const Text(
              "Household Settings",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("Rename Household"),
              onTap: () {
                Navigator.pop(sheetContext);
                _showRenameDialog(context, ref, household);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text("Regenerate Invite Code"),
              onTap: () {
                Navigator.pop(sheetContext);
                _showRegenerateCodeDialog(context, ref, household);
              },
            ),
            if (members.length > 1)
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: Colors.blue),
                title: const Text(
                  "Transfer Ownership",
                  style: TextStyle(color: Colors.blue),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showTransferOwnershipDialog(
                    context,
                    ref,
                    household,
                    members,
                    currentUserId,
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                "Delete Household",
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _showDeleteHouseholdDialog(context, ref, household);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTransferOwnershipDialog(
    BuildContext context,
    WidgetRef ref,
    Household household,
    List<Map<String, dynamic>> members,
    String? currentUserId,
  ) {
    final otherMembers = members
        .where((m) => m['uid'] != currentUserId)
        .toList();

    if (otherMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No other members to transfer ownership to."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Transfer Ownership"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select a member to become the new owner:"),
            const SizedBox(height: 16),
            ...otherMembers.map((member) {
              final memberName =
                  member['name'] as String? ?? member['email'] ?? 'Member';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF4A6C47).withOpacity(0.1),
                  child: Text(
                    memberName.isNotEmpty ? memberName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Color(0xFF4A6C47)),
                  ),
                ),
                title: Text(memberName),
                onTap: () async {
                  Navigator.pop(dialogContext);
                  await _confirmTransferOwnership(
                    context,
                    ref,
                    household,
                    member['uid'] as String,
                    memberName,
                  );
                },
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
  }

  Future<void> _confirmTransferOwnership(
    BuildContext context,
    WidgetRef ref,
    Household household,
    String newOwnerId,
    String newOwnerName,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirm Transfer"),
        content: Text(
          "Transfer ownership to $newOwnerName?\n\nYou will no longer be able to manage household settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
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
      try {
        await ref
            .read(householdServiceProvider)
            .transferOwnership(household.id, newOwnerId);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Ownership transferred to $newOwnerName"),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Transfer failed: $e"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Widget _buildIcon(IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildProStatusTile(BuildContext context, bool isPro, bool isLoading) {
    if (isLoading) {
      return const ListTile(
        leading: SizedBox(
          width: 36,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        title: Text("Checking subscription..."),
      );
    }
    if (!isPro) {
      return ListTile(
        leading: _buildIcon(
          Icons.workspace_premium,
          Colors.amber.shade700,
          Colors.amber.shade100,
        ),
        title: const Text(
          "Upgrade to Pro",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text("Unlimited recipes & members"),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PaywallScreen()),
        ),
      );
    }
    return ListTile(
      leading: _buildIcon(
        Icons.verified,
        Colors.green.shade400,
        Colors.green.shade50,
      ),
      title: const Text("Pro Subscription"),
      subtitle: const Text("Active • Thank you for your support!"),
      trailing: Icon(Icons.check_circle, color: Colors.green.shade400),
      onTap: () => _showProManagementSheet(context),
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
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.of(sheetContext).viewInsets.bottom;

        return GestureDetector(
          onTap: () => FocusScope.of(sheetContext).unfocus(),
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

                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
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

  void _showProManagementSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
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

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    Household household,
  ) async {
    final controller = TextEditingController(text: household.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Household renamed!"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showRegenerateCodeDialog(
    BuildContext context,
    WidgetRef ref,
    Household household,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Regenerate Code?"),
        content: const Text(
          "The old invite code will stop working. Anyone who hasn't joined yet will need the new code.",
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
      try {
        await ref.read(householdServiceProvider).deleteHousehold(household.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Household deleted'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _handleLogout(BuildContext context, WidgetRef ref, bool isGuest) {
    if (isGuest) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
  }

  void _handleDeleteAccount(
    BuildContext context,
    WidgetRef ref,
    Household? household,
    List<Map<String, dynamic>> members,
    bool isPro,
  ) async {
    final user = ref.read(authServiceProvider).currentUser;
    final isGuest = user?.isAnonymous ?? false;
    final isOwner = household?.ownerId == user?.uid;

    if (household != null && isOwner && members.length > 1) {
      final shouldTransfer = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Transfer Ownership Required"),
          content: const Text(
            "You are the owner of a household with other members. Please transfer ownership to another member before deleting your account, or delete the household first.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A6C47),
                foregroundColor: Colors.white,
              ),
              child: const Text("Transfer Ownership"),
            ),
          ],
        ),
      );

      if (shouldTransfer == true && context.mounted) {
        _showTransferOwnershipDialog(
          context,
          ref,
          household,
          members,
          user?.uid,
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Account?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "This action cannot be undone. All your data will be permanently deleted:",
            ),
            const SizedBox(height: 12),
            _buildDeleteItem("Your profile"),
            _buildDeleteItem("Your preferences"),
            if (household != null && isOwner && members.length <= 1)
              _buildDeleteItem("Your household and all its data"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Delete Forever"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    String? password;
    if (!isGuest) {
      password = await _showPasswordConfirmationDialog(context);
      if (password == null) return;
    }

    if (!context.mounted) return;

    await _executeAccountDeletion(
      context,
      ref,
      password: password,
      isGuest: isGuest,
      isOwner: isOwner,
      household: household,
      memberCount: members.length,
    );
  }

  Future<String?> _showPasswordConfirmationDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirm Password"),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            labelText: "Password",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  Future<void> _executeAccountDeletion(
    BuildContext context,
    WidgetRef ref, {
    String? password,
    required bool isGuest,
    required bool isOwner,
    Household? household,
    required int memberCount,
  }) async {
    // 1. Set the deletion flag FIRST to prevent any Firestore writes
    AccountDeletionState.isDeleting = true;
    debugPrint("🚨 Account deletion started - blocking Firestore writes");

    // 2. Capture Services EARLY
    final authService = ref.read(authServiceProvider);
    final userService = ref.read(userServiceProvider);
    final householdService = ref.read(householdServiceProvider);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // 3. Show Loading Dialog (NOT using rootNavigator so it's tied to this screen)
    final dialogContext = context;
    bool dialogShowing = true;

    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      useRootNavigator: false, // Keep dialog in same navigator as Settings
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    "Deleting Account...",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      // 4. Re-authenticate (if needed)
      if (!isGuest && password != null && password.isNotEmpty) {
        await authService.reauthenticate(password);
      }

      // 5. Delete Firestore Data
      if (userService != null) {
        final result = await userService.deleteAccountCompletely(
          householdService: householdService,
          householdId: household?.id,
          isOwner: isOwner,
          memberCount: memberCount,
        );

        if (!result.success) {
          throw Exception(result.error ?? "Unknown Firestore Error");
        }
      }

      // 6. Close loading dialog BEFORE deleting auth user
      // This ensures dialog is dismissed while context is still valid
      if (dialogContext.mounted && dialogShowing) {
        Navigator.of(dialogContext).pop();
        dialogShowing = false;
      }

      // 7. Delete Firebase Auth user
      // This triggers auth state change which navigates to login
      await authService.deleteAccount();

      debugPrint("✅ Account deletion completed successfully");

      // Show success (this might not show if navigation happens fast)
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text("Account deleted successfully"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint("❌ Account deletion error: $e");

      // Close loading dialog on error
      if (dialogContext.mounted && dialogShowing) {
        Navigator.of(dialogContext).pop();
        dialogShowing = false;
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text("Deletion Failed: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      // 8. Reset the deletion flag
      AccountDeletionState.isDeleting = false;
      debugPrint("🔓 Account deletion flag reset");
    }
  }
}
