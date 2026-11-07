import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/inquiry_model.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_cards.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/inquiries_provider.dart';

class InquiryDetailScreen extends ConsumerWidget {
  final String inquiryId;

  const InquiryDetailScreen({super.key, required this.inquiryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inquiriesAsync = ref.watch(inquiriesProvider);
    final followupsAsync = ref.watch(inquiryFollowupsProvider(inquiryId));

    return inquiriesAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (inquiries) {
        final inquiry = inquiries.firstWhere(
          (i) => i.id == inquiryId,
          orElse: () => inquiries.first,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(inquiry.name),
            actions: [
              StatusChip(status: inquiry.status),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (val) {
                  if (val == 'close') {
                    _showCloseDialog(context, ref, inquiry.id);
                  } else if (val == 'reopen') {
                    _reopenInquiry(context, ref, inquiry.id);
                  }
                },
                itemBuilder: (ctx) => [
                  if (inquiry.isOpen)
                    const PopupMenuItem(
                      value: 'close',
                      child: Row(
                        children: [
                          Icon(Icons.close, color: AppColors.error, size: 18),
                          SizedBox(width: 8),
                          Text('Close Inquiry', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    )
                  else
                    const PopupMenuItem(
                      value: 'reopen',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, color: AppColors.brandOrange, size: 18),
                          SizedBox(width: 8),
                          Text('Reopen Inquiry'),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                IconButton.outlined(
                  icon: const Icon(Icons.call, size: 20),
                  tooltip: 'Call Phone',
                  onPressed: () => launchUrl(Uri.parse('tel:${inquiry.phone}')),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.success),
                  icon: const Icon(Icons.chat, size: 20, color: AppColors.success),
                  tooltip: 'WhatsApp',
                  onPressed: () => launchUrl(Uri.parse('https://wa.me/${inquiry.phone.replaceAll(RegExp(r"[^0-9]"), "")}')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.brandOrange),
                    icon: const Icon(Icons.note_add, size: 18),
                    label: const Text('Log Follow-up'),
                    onPressed: () => _showLogFollowupDialog(context, ref, inquiry.id),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandOrange),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Convert'),
                  onPressed: () {
                    final query = Uri(queryParameters: {
                      'sourceInquiryId': inquiry.id,
                      'name': inquiry.name,
                      'phone': inquiry.phone,
                      if (inquiry.interestedIn != null) 'program': inquiry.interestedIn,
                    }).query;
                    context.go('/admin/clients/add?$query');
                  },
                ),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(inquiry.name, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text('Mobile: ${inquiry.phone}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandOrange)),
                      const SizedBox(height: 6),
                      Text('Source: ${inquiry.sourceId} • Inquired on ${DateFormat("dd MMM yyyy").format(inquiry.inquiryDate)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      if (inquiry.interestedIn != null) ...[
                        const SizedBox(height: 4),
                        Text('Program: ${inquiry.interestedIn!}',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                      ],
                      if (inquiry.preferredTime != null) ...[
                        const SizedBox(height: 4),
                        Text('Preferred Slot: ${inquiry.preferredTime!}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                      if (inquiry.lostReason != null) ...[
                        const SizedBox(height: 6),
                        Text('Close Reason: ${inquiry.lostReason!}',
                            style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const SectionHeader(title: 'Follow-up Timeline'),

              followupsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading history: $e'),
                data: (followups) {
                  if (followups.isEmpty) {
                    return const EmptyState(message: 'No follow-up activity logged yet', icon: Icons.history);
                  }
                  return Column(
                    children: followups.map((f) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.check_circle_outline, color: AppColors.brandOrange),
                            title: Text(f.outcome, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${f.remarks ?? ""}\n${DateFormat("dd MMM yyyy, hh:mm a").format(f.followupAt)}',
                                style: const TextStyle(fontSize: 12)),
                          ),
                        )).toList(),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  void _showLogFollowupDialog(BuildContext context, WidgetRef ref, String inqId) {
    String outcome = 'Call Answered';
    final remarksCtrl = TextEditingController();
    DateTime nextDate = DateTime.now().add(const Duration(days: 2));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.surfaceRaised,
          title: const Text('Log Follow-up Activity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: outcome,
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(labelText: 'Call Outcome'),
                items: const [
                  DropdownMenuItem(value: 'Call Answered', child: Text('Call Answered')),
                  DropdownMenuItem(value: 'Callback Requested', child: Text('Callback Requested')),
                  DropdownMenuItem(value: 'Interested', child: Text('Interested')),
                  DropdownMenuItem(value: 'Visited Gym', child: Text('Visited Gym')),
                  DropdownMenuItem(value: 'No Response / Busy', child: Text('No Response / Busy')),
                ],
                onChanged: (v) => setState(() => outcome = v ?? outcome),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Remarks / Notes'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Next Follow-up Date', style: TextStyle(fontSize: 13)),
                subtitle: Text(DateFormat('dd MMM yyyy').format(nextDate)),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: nextDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) setState(() => nextDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: outcome == 'Converted' ? AppColors.success : AppColors.brandOrange,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final user = ref.read(currentUserProvider);
                  await ref.read(inquiryRepositoryProvider).logFollowup(
                        inquiryId: inqId,
                        outcome: outcome,
                        remarks: remarksCtrl.text.trim(),
                        loggedBy: user?.id ?? 'admin-01',
                        nextFollowupDate: (outcome == 'Converted' || outcome == 'Not interested') ? null : nextDate,
                      );
                  ref.invalidate(inquiriesProvider);
                  ref.invalidate(todayInquiriesProvider);
                  ref.invalidate(overdueInquiriesProvider);
                  ref.invalidate(upcomingInquiriesProvider);
                  ref.invalidate(inquiryFollowupsProvider(inqId));

                  if (context.mounted) {
                    if (outcome == 'Converted') {
                      final inq = (ref.read(inquiriesProvider).valueOrNull ?? [])
                          .where((i) => i.id == inqId)
                          .firstOrNull;
                      final query = Uri(queryParameters: {
                        'sourceInquiryId': inqId,
                        if (inq != null) 'name': inq.name,
                        if (inq != null) 'phone': inq.phone,
                        if (inq?.interestedIn != null) 'program': inq!.interestedIn,
                      }).query;
                      context.go('/admin/clients/add?$query');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Follow-up logged successfully!')),
                      );
                    }
                  }
                },
                child: Text(outcome == 'Converted' ? 'Convert & Enroll' : 'Save Follow-up'),
              ),
          ],
        ),
      ),
    );
  }

  void _showCloseDialog(BuildContext context, WidgetRef ref, String inqId) {
    String reason = 'Joined competitor';
    String status = 'lost';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.surfaceRaised,
          title: const Text('Close Inquiry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: status,
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(labelText: 'Close Status'),
                items: const [
                  DropdownMenuItem(value: 'lost', child: Text('Lost')),
                  DropdownMenuItem(value: 'not_interested', child: Text('Not Interested')),
                ],
                onChanged: (v) => setState(() => status = v ?? status),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: reason,
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: const [
                  DropdownMenuItem(value: 'Too expensive', child: Text('Too expensive')),
                  DropdownMenuItem(value: 'Location/distance', child: Text('Location / distance')),
                  DropdownMenuItem(value: 'Timing conflict', child: Text('Timing conflict')),
                  DropdownMenuItem(value: 'Joined competitor', child: Text('Joined competitor')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => reason = v ?? reason),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                Navigator.pop(ctx);
                final user = ref.read(currentUserProvider);
                await ref.read(inquiryRepositoryProvider).closeInquiry(
                      inquiryId: inqId,
                      reason: reason,
                      status: status,
                      actorId: user?.id ?? 'admin-01',
                    );
                ref.invalidate(inquiriesProvider);
              },
              child: const Text('Close Inquiry'),
            ),
          ],
        ),
      ),
    );
  }

  void _reopenInquiry(BuildContext context, WidgetRef ref, String inqId) async {
    final user = ref.read(currentUserProvider);
    await ref.read(inquiryRepositoryProvider).reopenInquiry(
          inquiryId: inqId,
          actorId: user?.id ?? 'admin-01',
        );
    ref.invalidate(inquiriesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inquiry reopened to follow-up status.')),
      );
    }
  }
}

