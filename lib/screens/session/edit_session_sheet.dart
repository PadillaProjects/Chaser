import 'package:chaser/config/colors.dart';
import 'package:chaser/models/session.dart';
import 'package:chaser/services/firebase/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class EditSessionSheet extends StatefulWidget {
  final SessionModel session;

  const EditSessionSheet({super.key, required this.session});

  @override
  State<EditSessionSheet> createState() => _EditSessionSheetState();
}

class _EditSessionSheetState extends State<EditSessionSheet> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  late TextEditingController _nameController;
  late TextEditingController _passwordController;

  late String _visibility;
  late int _numChasers;
  late int _durationDays;
  late String _gameMode;
  late double _headstartDistance;
  late int _headstartDuration;
  TimeOfDay _restStartTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _restEndTime = const TimeOfDay(hour: 0, minute: 0);
  late bool _instantCapture;
  late int _captureResistanceDuration;
  late double _captureResistanceDistance;
  late int _switchCooldown;
  DateTime? _scheduledStartTime;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _nameController = TextEditingController(text: widget.session.name);
    _passwordController = TextEditingController(text: widget.session.password ?? '');

    _visibility = widget.session.visibility;
    _numChasers = widget.session.numChasers;
    _durationDays = widget.session.durationDays;
    _gameMode = widget.session.gameMode;
    _headstartDistance = widget.session.headstartDistance;
    _headstartDuration = widget.session.headstartDuration;
    _restStartTime = TimeOfDay(hour: widget.session.restStartHour, minute: 0);
    _restEndTime = TimeOfDay(hour: widget.session.restEndHour, minute: 0);
    _instantCapture = widget.session.instantCapture;
    _captureResistanceDuration = widget.session.captureResistanceDuration;
    _captureResistanceDistance = widget.session.captureResistanceDistance;
    _switchCooldown = widget.session.switchCooldown;
    _scheduledStartTime = widget.session.scheduledStartTime?.toDate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickScheduledTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledStartTime ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_scheduledStartTime ?? now),
      );

      if (time != null) {
        setState(() {
          _scheduledStartTime = DateTime(
            date.year, date.month, date.day, time.hour, time.minute
          );
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updates = {
        'session_name': _nameController.text.trim(),
        'visibility': _visibility,
        'password': _visibility == 'private' ? _passwordController.text.trim() : null,
        'game_mode': _gameMode,
        'scheduled_start_time': _scheduledStartTime != null ? Timestamp.fromDate(_scheduledStartTime!) : null,

        'settings.num_chasers': _numChasers,
        'settings.duration_days': _durationDays,
        'settings.rest_start_hour': _restStartTime.hour,
        'settings.rest_end_hour': _restEndTime.hour,
        'settings.headstart_distance': _headstartDistance,
        'settings.headstart_duration': _headstartDuration,
        'settings.switch_cooldown': _switchCooldown,
        'settings.instant_capture': _instantCapture,
        'settings.capture_resistance_duration': _captureResistanceDuration,
        'settings.capture_resistance_distance': _captureResistanceDistance,
      };

      await FirestoreService().updateSession(widget.session.id, updates);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating session: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.fromLTRB(0, 16, 0, MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.fogGrey,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'HUNT SETTINGS',
                    style: GoogleFonts.creepster(
                      fontSize: 24,
                      color: AppColors.ghostWhite,
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            TabBar(
              controller: _tabController,
              labelColor: AppColors.bloodRed,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.bloodRed,
              labelStyle: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, letterSpacing: 1),
              unselectedLabelStyle: GoogleFonts.jetBrainsMono(letterSpacing: 1),
              tabs: const [
                Tab(text: 'GENERAL'),
                Tab(text: 'RULES'),
                Tab(text: 'ADVANCED'),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGeneralTab(),
                  _buildRulesTab(),
                  _buildAdvancedTab(),
                ],
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.bloodRed.withOpacity(0.4),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: FilledButton(
                      onPressed: _isLoading ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.bloodRed,
                        foregroundColor: AppColors.ghostWhite,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.ghostWhite, strokeWidth: 2))
                          : Text(
                              'SAVE CHANGES',
                              style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, letterSpacing: 2),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _confirmDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.bloodRed,
                      side: const BorderSide(color: AppColors.bloodRed),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                    icon: const Icon(Icons.delete_forever),
                    label: Text(
                      'DELETE HUNT',
                      style: GoogleFonts.jetBrainsMono(letterSpacing: 2),
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

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.fogGrey,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(
          'DELETE HUNT?',
          style: GoogleFonts.creepster(fontSize: 24, color: AppColors.ghostWhite),
        ),
        content: Text(
          'This cannot be undone. All players will be removed.',
          style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.bloodRed,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('DELETE', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await FirestoreService().deleteSession(widget.session.id);
        if (mounted) {
          Navigator.pop(context);
          context.go('/');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e')),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextFormField(
          controller: _nameController,
          style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite),
          decoration: InputDecoration(
            labelText: 'HUNT NAME',
            labelStyle: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary, letterSpacing: 2),
            filled: true,
            fillColor: AppColors.voidBlack,
            border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppColors.textMuted.withOpacity(0.3)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppColors.bloodRed, width: 2),
            ),
          ),
          validator: (v) => v?.isEmpty == true ? 'Required' : null,
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          value: _visibility,
          dropdownColor: AppColors.fogGrey,
          style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite),
          decoration: InputDecoration(
            labelText: 'VISIBILITY',
            labelStyle: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary, letterSpacing: 2),
            filled: true,
            fillColor: AppColors.voidBlack,
            border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
          ),
          items: const [
            DropdownMenuItem(value: 'public', child: Text('Public')),
            DropdownMenuItem(value: 'private', child: Text('Private')),
          ],
          onChanged: (v) => setState(() => _visibility = v!),
        ),

        if (_visibility == 'private') ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite),
            decoration: InputDecoration(
              labelText: 'PASSWORD',
              labelStyle: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary, letterSpacing: 2),
              filled: true,
              fillColor: AppColors.voidBlack,
              border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
              prefixIcon: const Icon(Icons.key, color: AppColors.bloodRed),
            ),
          ),
        ],

        const SizedBox(height: 24),
        const Divider(color: AppColors.textMuted),

        Container(
          color: AppColors.voidBlack,
          child: SwitchListTile(
            title: Text(
              'SCHEDULE HUNT',
              style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite, letterSpacing: 1),
            ),
            subtitle: Text(
              _scheduledStartTime == null
                  ? 'Start manually later'
                  : 'Scheduled: ${_scheduledStartTime.toString().split('.')[0]}',
              style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.textSecondary),
            ),
            value: _scheduledStartTime != null,
            activeColor: AppColors.bloodRed,
            onChanged: (val) {
              if (val) {
                _pickScheduledTime();
              } else {
                setState(() => _scheduledStartTime = null);
              }
            },
          ),
        ),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.voidBlack,
          child: Row(
            children: [
              const Icon(Icons.lock_outline, color: AppColors.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MAX PREY: ${widget.session.maxMembers}',
                      style: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary),
                    ),
                    Text(
                      'Cannot be changed',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRulesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          value: _gameMode,
          dropdownColor: AppColors.fogGrey,
          style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite),
          decoration: InputDecoration(
            labelText: 'GAME MODE',
            labelStyle: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary, letterSpacing: 2),
            filled: true,
            fillColor: AppColors.voidBlack,
            border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
            prefixIcon: const Icon(Icons.sports_kabaddi, color: AppColors.bloodRed),
          ),
          items: const [
            DropdownMenuItem(value: 'original', child: Text('Original Tag')),
            DropdownMenuItem(value: 'target', child: Text('Target Mode')),
          ],
          onChanged: (val) => setState(() => _gameMode = val!),
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<int>(
          value: _durationDays,
          dropdownColor: AppColors.fogGrey,
          style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite),
          decoration: InputDecoration(
            labelText: 'DURATION',
            labelStyle: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary, letterSpacing: 2),
            filled: true,
            fillColor: AppColors.voidBlack,
            border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
            prefixIcon: const Icon(Icons.timer, color: AppColors.bloodRed),
          ),
          items: const [
            DropdownMenuItem(value: 3, child: Text('3 Days')),
            DropdownMenuItem(value: 7, child: Text('7 Days')),
            DropdownMenuItem(value: 14, child: Text('14 Days')),
            DropdownMenuItem(value: 30, child: Text('30 Days')),
          ],
          onChanged: (val) => setState(() => _durationDays = val!),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.voidBlack,
          child: Row(
            children: [
              const Icon(Icons.gps_fixed, color: AppColors.bloodRed),
              const SizedBox(width: 12),
              Text(
                'CHASERS',
                style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite, letterSpacing: 2),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove, color: AppColors.ghostWhite),
                onPressed: _numChasers > 1 ? () => setState(() => _numChasers--) : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.fogGrey,
                child: Text(
                  '$_numChasers',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.bloodRed,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.ghostWhite),
                onPressed: _numChasers < 3 ? () => setState(() => _numChasers++) : null,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('HEADSTART'),
        const SizedBox(height: 8),

        _buildNumberField(
          label: 'DISTANCE (M)',
          initialValue: _headstartDistance.toString(),
          suffix: 'm',
          onChanged: (val) => _headstartDistance = double.tryParse(val) ?? 0,
        ),
        const SizedBox(height: 12),
        _buildNumberField(
          label: 'DURATION (MIN)',
          initialValue: _headstartDuration.toString(),
          suffix: 'min',
          onChanged: (val) => _headstartDuration = int.tryParse(val) ?? 0,
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('REST PERIOD'),
        const SizedBox(height: 8),

        _buildTimeTile(
          label: 'FROM',
          time: _restStartTime,
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: _restStartTime);
            if (t != null) setState(() => _restStartTime = t);
          },
        ),
        const SizedBox(height: 8),
        _buildTimeTile(
          label: 'TO',
          time: _restEndTime,
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: _restEndTime);
            if (t != null) setState(() => _restEndTime = t);
          },
        ),
        if (_restStartTime.hour > _restEndTime.hour)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Rest period spans overnight',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                color: AppColors.warningYellow,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAdvancedTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          color: AppColors.voidBlack,
          child: SwitchListTile(
            title: Text(
              'INSTANT CAPTURE',
              style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite, letterSpacing: 1),
            ),
            subtitle: Text(
              'Runners captured immediately upon contact',
              style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.textSecondary),
            ),
            value: _instantCapture,
            activeColor: AppColors.bloodRed,
            onChanged: (val) => setState(() => _instantCapture = val),
          ),
        ),

        if (!_instantCapture) ...[
          const SizedBox(height: 24),
          _buildSectionHeader('CAPTURE RESISTANCE'),
          const SizedBox(height: 8),
          _buildNumberField(
            label: 'DURATION (MIN)',
            initialValue: _captureResistanceDuration.toString(),
            suffix: 'min',
            onChanged: (val) => _captureResistanceDuration = int.tryParse(val) ?? 0,
          ),
          const SizedBox(height: 12),
          _buildNumberField(
            label: 'DISTANCE (M)',
            initialValue: _captureResistanceDistance.toString(),
            suffix: 'm',
            onChanged: (val) => _captureResistanceDistance = double.tryParse(val) ?? 0,
          ),
        ],

        if (_gameMode == 'target') ...[
          const SizedBox(height: 24),
          _buildSectionHeader('TARGET MODE'),
          const SizedBox(height: 8),
          _buildNumberField(
            label: 'SWITCH COOLDOWN',
            initialValue: _switchCooldown.toString(),
            suffix: 'min',
            onChanged: (val) => _switchCooldown = int.tryParse(val) ?? 0,
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 16, color: AppColors.bloodRed),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.jetBrainsMono(
            color: AppColors.ghostWhite,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildNumberField({
    required String label,
    required String initialValue,
    required String suffix,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: TextInputType.number,
      style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary, letterSpacing: 1, fontSize: 12),
        suffixText: suffix,
        suffixStyle: GoogleFonts.jetBrainsMono(color: AppColors.bloodRed),
        filled: true,
        fillColor: AppColors.voidBlack,
        border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.textMuted.withOpacity(0.3)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.bloodRed, width: 2),
        ),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildTimeTile({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.voidBlack,
          border: Border.all(color: AppColors.textMuted.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary, letterSpacing: 2),
            ),
            const Spacer(),
            Text(
              time.format(context),
              style: GoogleFonts.jetBrainsMono(
                color: AppColors.ghostWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.access_time, color: AppColors.bloodRed),
          ],
        ),
      ),
    );
  }
}
