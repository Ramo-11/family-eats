import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/household.dart';
import '../../../services/user_service.dart';
import '../paywall_screen.dart';

class HouseholdCard extends ConsumerWidget {
  final Household household;
  final String? currentUserId;
  final List<Map<String, dynamic>> members;
  final bool isHouseholdPro;
  final Color primaryColor;

  const HouseholdCard({
    super.key,
    required this.household,
    required this.currentUserId,
    required this.members,
    required this.isHouseholdPro,
    required this.primaryColor,
  });

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return "?";
    final parts = name.trim().split(" ");
    if (parts.isEmpty) return "?";
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = household.ownerId == currentUserId;
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
              _buildHeader(isOwner),
              const SizedBox(height: 16),

              if (!isHouseholdPro) _buildLimitBanner(isOwner),
              if (!isHouseholdPro) const SizedBox(height: 16),

              Text(
                isLimitReached
                    ? "Household limit reached (2 members)"
                    : "Share this code to invite others",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 12),

              _buildInviteSection(context, isLimitReached, isOwner),
              const SizedBox(height: 24),

              // Members List
              _buildMembersHeader(),
              const SizedBox(height: 12),
              ...members.map((m) => _buildMemberItem(m)),

              const SizedBox(height: 24),
              _buildActionButtons(context, ref, isOwner),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isOwner) {
    return Row(
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
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLimitBanner(bool isOwner) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.blue.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isOwner
                  ? "Free plan: 2 members, 5 recipes. Upgrade to unlock unlimited!"
                  : "Free plan: 2 members, 5 recipes. Ask owner to upgrade.",
              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteSection(
    BuildContext context,
    bool isLimitReached,
    bool isOwner,
  ) {
    if (isLimitReached) {
      return InkWell(
        onTap: isOwner
            ? () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
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
              Icon(Icons.lock_outline, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                isOwner ? "Upgrade to invite more" : "Ask owner to upgrade",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: household.inviteCode));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Invite code copied: ${household.inviteCode}"),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      );
    }
  }

  Widget _buildMembersHeader() {
    return Row(
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
    );
  }

  Widget _buildMemberItem(Map<String, dynamic> member) {
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
        color: isMe ? primaryColor.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? primaryColor.withOpacity(0.2) : Colors.grey.shade200,
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
              if (memberIsPro)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.star, size: 8, color: Colors.white),
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
                          fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
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
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
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
                if (isMemberOwner)
                  Text(
                    "Owner",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    bool isOwner,
  ) {
    if (!isOwner) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showLeaveDialog(context, ref),
          icon: const Icon(Icons.exit_to_app, size: 18, color: Colors.red),
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
      );
    }
    // Owner Actions are handled in the main settings screen via the "Household Settings" section
    // but we can add quick actions here if desired.
    return const SizedBox.shrink();
  }

  void _showLeaveDialog(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Leave Household?"),
        content: const Text(
          "You'll need to create a new household or join another one to continue.",
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
}
