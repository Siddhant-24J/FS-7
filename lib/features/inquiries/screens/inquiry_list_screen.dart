import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/inquiry_model.dart';
import '../../../widgets/common/app_cards.dart';
import '../providers/inquiries_provider.dart';
import '../../auth/providers/auth_provider.dart';

class InquiryListScreen extends ConsumerStatefulWidget {
  const InquiryListScreen({super.key});

  @override
  ConsumerState<InquiryListScreen> createState() => _InquiryListScreenState();
}

class _InquiryListScreenState extends ConsumerState<InquiryListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inquiries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Source Analytics',
            onPressed: () => context.go('/admin/inquiries/analytics'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.brandOrange,
          labelColor: AppColors.brandOrange,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: "Today's Calls"),
            Tab(text: 'Overdue'),
            Tab(text: 'Upcoming'),
            Tab(text: 'All Leads'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/admin/inquiries/add'),
        backgroundColor: AppColors.brandOrange,
        icon: const Icon(Icons.add_call, color: Colors.white),
        label: const Text('Add Inquiry', style: TextStyle(color: Colors.white)),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayList(),
          _buildOverdueList(),
          _buildUpcomingList(),
          _buildAllList(),
        ],
      ),
    );
  }

  Widget _buildTodayList() {
    final todayAsync = ref.watch(todayInquiriesProvider);
    return todayAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (inquiries) {
        if (inquiries.isEmpty) {
          return const EmptyState(message: 'No follow-up calls due today!', icon: Icons.phone_callback);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: inquiries.length,
          itemBuilder: (ctx, i) => _InquiryCard(
            inquiry: inquiries[i],
            onLogFollowup: () => _showLogFollowupSheet(inquiries[i]),
          ),
        );
      },
    );
  }

  Widget _buildOverdueList() {
    final overdueAsync = ref.watch(overdueInquiriesProvider);
    return overdueAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (inquiries) {
        if (inquiries.isEmpty) {
          return const EmptyState(message: 'No overdue follow-ups!', icon: Icons.done_all);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: inquiries.length,
          itemBuilder: (ctx, i) => _InquiryCard(
            inquiry: inquiries[i],
            isOverdue: true,
            onLogFollowup: () => _showLogFollowupSheet(inquiries[i]),
          ),
        );
      },
    );
  }

  Widget _buildUpcomingList() {
    final upcomingAsync = ref.watch(upcomingInquiriesProvider);
    return upcomingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (upcoming) {
        if (upcoming.isEmpty) {
          return const EmptyState(message: 'No upcoming follow-ups scheduled', icon: Icons.event_note);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: upcoming.length,
          itemBuilder: (ctx, i) => _InquiryCard(
            inquiry: upcoming[i],
            onLogFollowup: () => _showLogFollowupSheet(upcoming[i]),
          ),
        );
      },
    );
  }

  Widget _buildAllList() {
    final allAsync = ref.watch(inquiriesProvider);
    return allAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (inquiries) {
        if (inquiries.isEmpty) {
          return const EmptyState(message: 'No inquiries found', icon: Icons.contact_page_outlined);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: inquiries.length,
          itemBuilder: (ctx, i) => _InquiryCard(
            inquiry: inquiries[i],
            onLogFollowup: () => _showLogFollowupSheet(inquiries[i]),
          ),
        );
      },
    );
  }

  void _showLogFollowupSheet(InquiryModel inquiry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _LogFollowupSheet(inquiry: inquiry),
    );
  }
}

class _InquiryCard extends StatelessWidget {
  final InquiryModel inquiry;
  final bool isOverdue;
  final VoidCallback onLogFollowup;

  const _InquiryCard({
    required this.inquiry,
    this.isOverdue = false,
    required this.onLogFollowup,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/admin/inquiries/${inquiry.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.surfaceRaised,
                    child: Text(
                      inquiry.name.isNotEmpty ? inquiry.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandOrange),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inquiry.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(inquiry.phone,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceRaised,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(inquiry.sourceId,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  StatusChip(status: inquiry.status),
                ],
              ),
              const SizedBox(height: 12),

              // Program & Timing
              if (inquiry.interestedIn != null || inquiry.preferredTime != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      if (inquiry.interestedIn != null) ...[
                        const Icon(Icons.fitness_center, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(inquiry.interestedIn!,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(width: 12),
                      ],
                      if (inquiry.preferredTime != null) ...[
                        const Icon(Icons.access_time, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(inquiry.preferredTime!,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                ),

              // Next follow-up info
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 13,
                    color: isOverdue ? AppColors.error : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    inquiry.isOpen
                        ? 'Next: ${DateFormat("dd MMM yyyy").format(inquiry.nextFollowupDate)}'
                        : 'Closed: ${DateFormat("dd MMM yyyy").format(inquiry.updatedAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                      color: isOverdue ? AppColors.error : AppColors.textSecondary,
                    ),
                  ),
                  if (inquiry.nextFollowupTime != null && inquiry.isOpen) ...[
                    const SizedBox(width: 8),
                    Text('at ${inquiry.nextFollowupTime}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ],
              ),

              const Divider(height: 20),

              // Action buttons
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.call, color: AppColors.brandOrange, size: 20),
                    tooltip: 'Call Phone',
                    onPressed: () => launchUrl(Uri.parse('tel:${inquiry.phone}')),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat, color: AppColors.success, size: 20),
                    tooltip: 'WhatsApp',
                    onPressed: () => launchUrl(Uri.parse('https://wa.me/${inquiry.phone.replaceAll(RegExp(r"[^0-9]"), "")}')),
                  ),
                  const Spacer(),
                  if (inquiry.isOpen) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 36),
                      ),
                      icon: const Icon(Icons.edit_note, size: 16),
                      label: const Text('Log Follow-up', style: TextStyle(fontSize: 12)),
                      onPressed: onLogFollowup,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 36),
                      ),
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Convert', style: TextStyle(fontSize: 12)),
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
                  ] else if (inquiry.isConverted || inquiry.status == 'converted') ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success.withOpacity(0.15),
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: AppColors.success),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 36),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Converted · Details', style: TextStyle(fontSize: 12)),
                      onPressed: () => context.go('/admin/inquiries/${inquiry.id}'),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 36),
                      ),
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text('View Inquiry', style: TextStyle(fontSize: 12)),
                      onPressed: () => context.go('/admin/inquiries/${inquiry.id}'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogFollowupSheet extends ConsumerStatefulWidget {
  final InquiryModel inquiry;

  const _LogFollowupSheet({required this.inquiry});

  @override
  ConsumerState<_LogFollowupSheet> createState() => _LogFollowupSheetState();
}

class _LogFollowupSheetState extends ConsumerState<_LogFollowupSheet> {
  String _outcome = AppConstants.followupOutcomes.first;
  final _remarksCtrl = TextEditingController();
  DateTime _nextDate = DateTime.now().add(const Duration(days: 2));
  bool _isSaving = false;

  bool get _isConverted => _outcome == 'Converted';
  bool get _isNotInterested => _outcome == 'Not interested';

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Log Follow-up: ${widget.inquiry.name}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _outcome,
            dropdownColor: AppColors.surface,
            items: AppConstants.followupOutcomes
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: (v) => setState(() => _outcome = v ?? _outcome),
            decoration: const InputDecoration(labelText: 'Outcome of Discussion'),
          ),

          const SizedBox(height: 12),

          if (_isConverted) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.celebration, color: AppColors.success, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Awesome! Saving will mark this inquiry as Converted and open the enrollment wizard.',
                      style: TextStyle(color: AppColors.success, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (_isNotInterested) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cancel_outlined, color: AppColors.error, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This lead will be marked as Not Interested / Closed.',
                      style: TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          TextFormField(
            controller: _remarksCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: _isNotInterested ? 'Reason / Remarks (Required)' : 'Discussion Notes / Remarks',
              hintText: _isNotInterested ? 'e.g. Too far, budget issue, joined elsewhere' : 'Client feedback, questions asked...',
            ),
          ),

          if (!_isConverted && !_isNotInterested) ...[
            const SizedBox(height: 12),
            ListTile(
              tileColor: AppColors.surfaceRaised,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              title: const Text('Next Follow-up Date', style: TextStyle(fontSize: 12)),
              subtitle: Text(DateFormat('dd MMM yyyy').format(_nextDate)),
              trailing: const Icon(Icons.calendar_today, size: 18),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _nextDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) setState(() => _nextDate = picked);
              },
            ),
          ],

          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isConverted ? AppColors.success : AppColors.brandOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: _isSaving ? null : _saveFollowup,
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(_isConverted ? 'Convert & Enroll Client Now' : 'Save & Update Lead'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveFollowup() async {
    if (_isNotInterested && _remarksCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter remarks/reason why client is not interested.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final user = ref.read(currentUserProvider);

    try {
      await ref.read(inquiryRepositoryProvider).logFollowup(
            inquiryId: widget.inquiry.id,
            outcome: _outcome,
            remarks: _remarksCtrl.text.trim(),
            nextFollowupDate: (_isConverted || _isNotInterested) ? null : _nextDate,
            loggedBy: user?.id ?? 'admin-01',
          );

      ref.invalidate(todayInquiriesProvider);
      ref.invalidate(overdueInquiriesProvider);
      ref.invalidate(upcomingInquiriesProvider);
      ref.invalidate(inquiriesProvider);
      ref.invalidate(inquiryFollowupsProvider(widget.inquiry.id));

      if (mounted) {
        Navigator.pop(context);
        if (_isConverted) {
          final query = Uri(queryParameters: {
            'sourceInquiryId': widget.inquiry.id,
            'name': widget.inquiry.name,
            'phone': widget.inquiry.phone,
            if (widget.inquiry.interestedIn != null) 'program': widget.inquiry.interestedIn,
          }).query;
          context.go('/admin/clients/add?$query');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isNotInterested ? 'Inquiry marked as closed' : 'Follow-up logged successfully!'),
              backgroundColor: _isNotInterested ? AppColors.warning : AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

