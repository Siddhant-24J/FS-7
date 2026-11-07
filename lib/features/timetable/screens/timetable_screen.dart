import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/formulas/slot_engine.dart';
import '../../../data/models/plan_model.dart';
import '../../../data/models/user_model.dart';
import '../../../widgets/common/app_cards.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/timetable_provider.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedTrainerId;
  DateTime _selectedDate = DateTime.now();
  bool _isWeekView = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final trainersAsync = ref.watch(activeTrainersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.role == 'trainer' ? 'My Timetable' : 'Timetable'),
        actions: [
          // Week/Day toggle
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, icon: Icon(Icons.grid_view, size: 16), label: Text('Week')),
              ButtonSegment(value: false, icon: Icon(Icons.today, size: 16), label: Text('Day')),
            ],
            selected: {_isWeekView},
            onSelectionChanged: (s) => setState(() => _isWeekView = s.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.brandOrange.withOpacity(0.15),
              selectedForegroundColor: AppColors.brandOrange,
              backgroundColor: AppColors.surface,
            ),
          ),
          const SizedBox(width: 8),
          if (user?.isAdmin == true)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Find free slot',
              onPressed: () => _showFreeSlotFinder(context),
            ),
        ],
        bottom: trainersAsync.when(
          loading: () => null,
          error: (_, __) => null,
          data: (trainers) {
            if (user?.role == 'trainer') return null; // Trainers view own row only (§ 3.2)
            return _TrainerFilterBar(
              trainers: trainers,
              selectedId: _selectedTrainerId,
              onSelect: (id) => setState(() => _selectedTrainerId = id),
            );
          },
        ),
      ),
      body: trainersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (trainers) {
          final visibleTrainers = user?.role == 'trainer'
              ? trainers.where((t) => t.id == user?.id || t.userId == user?.userId).toList()
              : (_selectedTrainerId != null
                  ? trainers.where((t) => t.id == _selectedTrainerId).toList()
                  : trainers);

          if (visibleTrainers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fitness_center, size: 56, color: AppColors.textSecondary),
                    const SizedBox(height: 16),
                    Text(user?.role == 'trainer' ? 'No Schedule Found' : 'No Trainers in Schedule',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      user?.role == 'trainer'
                          ? 'You do not have any timetable slots scheduled yet.'
                          : 'Add staff members with the "Trainer" role from Team to start scheduling slots.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if (user?.isAdmin == true) ...[
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandOrange),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Trainer'),
                        onPressed: () => context.go('/admin/more/team/add'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          final filtered = visibleTrainers;
          if (_isWeekView) {
            return _WeekGrid(trainers: filtered, weekStart: _weekStart(_selectedDate));
          } else {
            return _DayView(trainers: filtered, date: _selectedDate);
          }
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showOccupancySummary(context, trainersAsync.valueOrNull ?? []),
        backgroundColor: AppColors.brandOrange,
        icon: const Icon(Icons.bar_chart, color: Colors.white),
        label: const Text('Occupancy', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showOccupancySummary(BuildContext context, List<UserModel> trainers) {
    final slots = MockData.slots;
    final totalCapacity = trainers.length * 11 * 2;
    final occupied = slots.length;
    final pct = totalCapacity > 0 ? (occupied / totalCapacity) * 100 : 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Gym Timetable Occupancy',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${pct.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.brandOrange)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalCapacity > 0 ? occupied / totalCapacity : 0.0,
                backgroundColor: AppColors.surfaceRaised,
                valueColor: const AlwaysStoppedAnimation(AppColors.brandOrange),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$occupied of $totalCapacity total seats occupied across ${trainers.length} trainer(s).',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            const Text('Trainer Breakdown:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: trainers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final t = trainers[i];
                  final tSlots = slots.where((s) => s.trainerId == t.id).length;
                  final tPct = (tSlots / 22.0) * 100;
                  return Row(
                    children: [
                      Expanded(flex: 3, child: Text(t.name, style: const TextStyle(fontSize: 13))),
                      Expanded(
                        flex: 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (tSlots / 22.0).clamp(0.0, 1.0),
                            backgroundColor: AppColors.surfaceRaised,
                            valueColor: const AlwaysStoppedAnimation(AppColors.brandOrange),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('$tSlots / 22 (${tPct.toStringAsFixed(0)}%)',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _weekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  void _showFreeSlotFinder(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FreeSlotFinder(),
    );
  }
}

class _TrainerFilterBar extends StatelessWidget implements PreferredSizeWidget {
  final List<UserModel> trainers;
  final String? selectedId;
  final void Function(String?) onSelect;

  const _TrainerFilterBar({
    required this.trainers,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _chip('All', null),
          ...trainers.map((t) => _chip(t.name.split(' ').first, t.id)),
        ],
      ),
    );
  }

  Widget _chip(String label, String? id) {
    final selected = selectedId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onSelect(id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandOrange : AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected ? AppColors.brandOrange : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(44);
}

class _WeekGrid extends ConsumerWidget {
  final List<UserModel> trainers;
  final DateTime weekStart;

  const _WeekGrid({required this.trainers, required this.weekStart});

  static const List<int> _hours = [6, 7, 8, 9, 10, 11, 17, 18, 19, 20, 21];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(allActiveSlotsProvider);

    return slotsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (slots) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              children: [
                _buildHeader(),
                ...trainers.map((trainer) => _TrainerRow(
                  trainer: trainer,
                  hours: _hours,
                  slots: slots.where((s) => s.trainerId == trainer.id).toList(),
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.surface,
      child: Row(
        children: [
          // Trainer column header
          const SizedBox(width: 100),
          ..._hours.map((h) => _HourHeader(hour: h)),
        ],
      ),
    );
  }
}

class _HourHeader extends StatelessWidget {
  final int hour;

  const _HourHeader({required this.hour});

  @override
  Widget build(BuildContext context) {
    final label = hour > 12
        ? '${hour - 12} PM'
        : hour == 12
            ? '12 PM'
            : '$hour AM';
    return Container(
      width: 90,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Text(label,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
    );
  }
}

class _TrainerRow extends ConsumerWidget {
  final UserModel trainer;
  final List<int> hours;
  final List<SlotModel> slots;

  const _TrainerRow({
    required this.trainer,
    required this.hours,
    required this.slots,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Trainer name
          SizedBox(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(trainer.name.split(' ').first,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  _occupancyIndicator(),
                ],
              ),
            ),
          ),
          // Hour cells
          ...hours.map((h) {
            final slotPatterns = slots
                .where((s) => s.hourStart == h)
                .map((s) => s.pattern)
                .toList();
            return _SlotCell(
              trainer: trainer,
              hour: h,
              patterns: slotPatterns,
              onTap: () => _onCellTap(context, ref, h, slotPatterns),
            );
          }),
        ],
      ),
    );
  }

  Widget _occupancyIndicator() {
    // Count occupied slots across all hours
    final totalSlots = slots.length;
    final maxPossible = 11 * 2; // 11 hours * 2 seats
    final pct = maxPossible == 0 ? 0.0 : totalSlots / maxPossible;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            widthFactor: pct.clamp(0.0, 1.0),
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.brandOrange,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text('${(pct * 100).toStringAsFixed(0)}%',
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }

  void _onCellTap(BuildContext ctx, WidgetRef ref, int hour, List<String> patterns) {
    // Show slot detail / add client option
    showModalBottomSheet(
      context: ctx,
      builder: (_) => _SlotDetailSheet(
        trainer: trainer,
        hour: hour,
        patterns: patterns,
      ),
    );
  }
}

class _SlotCell extends StatelessWidget {
  final UserModel trainer;
  final int hour;
  final List<String> patterns;
  final VoidCallback onTap;

  const _SlotCell({
    required this.trainer,
    required this.hour,
    required this.patterns,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFull = SlotEngine.dailySeatCount(patterns)
        .values
        .any((s) => s >= AppConstants.maxSeatsPerSlot);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 60,
        decoration: BoxDecoration(
          border: const Border(left: BorderSide(color: AppColors.border)),
          color: isFull
              ? AppColors.surfaceRaised
              : AppColors.background,
        ),
        child: patterns.isEmpty
            ? Center(
                child: Icon(Icons.add, size: 14,
                  color: AppColors.textSecondary.withOpacity(0.3)),
              )
            : Padding(
                padding: const EdgeInsets.all(4),
                child: Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  children: patterns.map((p) => SlotPatternChip(pattern: p)).toList(),
                ),
              ),
      ),
    );
  }
}

class _SlotDetailSheet extends StatelessWidget {
  final UserModel trainer;
  final int hour;
  final List<String> patterns;

  const _SlotDetailSheet({
    required this.trainer,
    required this.hour,
    required this.patterns,
  });

  @override
  Widget build(BuildContext context) {
    final availability = SlotEngine.getAvailablePatterns(patterns);
    final description = SlotEngine.describeSlot(patterns);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trainer.name, style: Theme.of(context).textTheme.titleLarge),
                    Text(_hourLabel(hour), style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          if (patterns.isNotEmpty) ...[
            const Text('Booked', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: patterns.map((p) => SlotPatternChip(pattern: p)).toList(),
            ),
            const SizedBox(height: 16),
          ],
          // Available patterns
          const Text('Available to add', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          ...availability.map((a) => ListTile(
            dense: true,
            leading: a.isAvailable
                ? Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.slotColor(a.pattern).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text(a.pattern,
                      style: TextStyle(color: AppColors.slotColor(a.pattern),
                        fontWeight: FontWeight.w700, fontSize: 12))),
                  )
                : Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text(a.pattern,
                      style: const TextStyle(color: AppColors.textSecondary,
                        fontSize: 12))),
                  ),
            title: Text(a.pattern),
            subtitle: a.reason != null ? Text(a.reason!, style: const TextStyle(fontSize: 11)) : null,
            trailing: a.isAvailable
                ? const Icon(Icons.check_circle, color: AppColors.success, size: 18)
                : const Icon(Icons.block, color: AppColors.textSecondary, size: 18),
            enabled: a.isAvailable,
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _hourLabel(int hour) {
    final h1 = hour > 12 ? hour - 12 : hour;
    final ap1 = hour >= 12 ? 'PM' : 'AM';
    final h2 = (hour + 1) > 12 ? (hour + 1) - 12 : (hour + 1);
    final ap2 = (hour + 1) >= 12 ? 'PM' : 'AM';
    return '$h1 $ap1 – $h2 $ap2';
  }
}

class _DayView extends ConsumerWidget {
  final List<UserModel> trainers;
  final DateTime date;

  const _DayView({required this.trainers, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trainers.length,
      itemBuilder: (ctx, i) => _TrainerDayCard(trainer: trainers[i], date: date),
    );
  }
}

class _TrainerDayCard extends ConsumerWidget {
  final UserModel trainer;
  final DateTime date;

  const _TrainerDayCard({required this.trainer, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trainer.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Sessions due today appear here',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _FreeSlotFinder extends ConsumerStatefulWidget {
  const _FreeSlotFinder();

  @override
  ConsumerState<_FreeSlotFinder> createState() => _FreeSlotFinderState();
}

class _FreeSlotFinderState extends ConsumerState<_FreeSlotFinder> {
  String? _selectedPattern;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Find Free Slot', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          const Text('Select pattern:', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: AppConstants.allPatterns.map((p) {
              final selected = _selectedPattern == p;
              return GestureDetector(
                onTap: () => setState(() => _selectedPattern = p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.slotColor(p).withOpacity(0.2)
                        : AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? AppColors.slotColor(p) : AppColors.border,
                    ),
                  ),
                  child: Text(p,
                    style: TextStyle(
                      color: selected ? AppColors.slotColor(p) : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _selectedPattern == null ? null : () {
              // TODO: Search and display free slots
              Navigator.pop(context);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
}

