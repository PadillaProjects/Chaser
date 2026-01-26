import 'package:chaser/models/session.dart';
import 'package:chaser/services/firebase/firestore_service.dart'; // Existing import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EditSessionSheet extends StatefulWidget {
  final SessionModel session;

  const EditSessionSheet({super.key, required this.session});

  @override
  State<EditSessionSheet> createState() => _EditSessionSheetState();
}

class _EditSessionSheetState extends State<EditSessionSheet> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _passwordController;

  // State Variables
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
    
    // Initialize Controllers
    _nameController = TextEditingController(text: widget.session.name);
    _passwordController = TextEditingController(text: widget.session.password ?? '');

    // Initialize State
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
        
        // Settings Map Updates
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
    final theme = Theme.of(context);
    
    return Container(
      // Make sheet nearly full height for tabs
      height: MediaQuery.of(context).size.height * 0.85, 
      padding: EdgeInsets.fromLTRB(0, 16, 0, MediaQuery.of(context).viewInsets.bottom),
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
                  Text('Edit Settings', style: theme.textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'General'),
                Tab(text: 'Rules'),
                Tab(text: 'Advanced'),
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
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Text('Save Changes'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _confirmDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete Session'),
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
        title: const Text('Delete Session?'),
        content: const Text('This cannot be undone. All players will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await FirestoreService().deleteSession(widget.session.id);
        if (mounted) {
           // Pop sheet
          Navigator.pop(context);
          // Pop details screen to go home
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
          decoration: const InputDecoration(labelText: 'Session Name', border: OutlineInputBorder()),
          validator: (v) => v?.isEmpty == true ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        
        DropdownButtonFormField<String>(
          value: _visibility,
          decoration: const InputDecoration(labelText: 'Visibility', border: OutlineInputBorder()),
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
            decoration: const InputDecoration(
              labelText: 'Password', 
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.key),
            ),
          ),
        ],
        
        const SizedBox(height: 24),
        const Divider(),

        SwitchListTile(
          title: const Text('Schedule Start Time'),
          subtitle: Text(_scheduledStartTime == null 
              ? 'Start manually later' 
              : 'Scheduled: ${_scheduledStartTime.toString().split('.')[0]}'),
          value: _scheduledStartTime != null,
          onChanged: (val) {
            if (val) {
              _pickScheduledTime();
            } else {
              setState(() => _scheduledStartTime = null);
            }
          },
        ),
        
        const SizedBox(height: 16),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          leading: const Icon(Icons.lock_outline),
          title: Text('Max Members: ${widget.session.maxMembers}'),
          subtitle: const Text('Cannot be changed after creation'),
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
          decoration: const InputDecoration(labelText: 'Game Mode', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'original', child: Text('Original Tag')),
            DropdownMenuItem(value: 'target', child: Text('Target Mode')),
          ],
          onChanged: (val) => setState(() => _gameMode = val!),
        ),
        const SizedBox(height: 16),
        
        DropdownButtonFormField<int>(
          value: _durationDays,
          decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 3, child: Text('3 Days')),
            DropdownMenuItem(value: 7, child: Text('7 Days')),
            DropdownMenuItem(value: 14, child: Text('14 Days')),
            DropdownMenuItem(value: 30, child: Text('30 Days')),
          ],
          onChanged: (val) => setState(() => _durationDays = val!),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            const Text('Number of Chasers:'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: _numChasers > 1 ? () => setState(() => _numChasers--) : null,
            ),
            Text('$_numChasers', style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _numChasers < 3 ? () => setState(() => _numChasers++) : null,
            ),
          ],
        ),
        const Divider(),
        
        Text('Headstart', style: Theme.of(context).textTheme.titleSmall),
         const SizedBox(height: 8),
        TextFormField(
          initialValue: _headstartDistance.toString(),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Distance (m)', 
            border: OutlineInputBorder(),
            suffixText: 'm',
          ),
          onChanged: (val) => _headstartDistance = double.tryParse(val) ?? 0,
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _headstartDuration.toString(),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Duration (min)', 
            border: OutlineInputBorder(),
            suffixText: 'min',
          ),
          onChanged: (val) => _headstartDuration = int.tryParse(val) ?? 0,
        ),
        
        const Divider(),

        Text('Rest Period', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Theme.of(context).dividerColor)),
          title: Text('From: ${_restStartTime.format(context)}'),
          trailing: const Icon(Icons.access_time),
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: _restStartTime);
            if (t != null) setState(() => _restStartTime = t);
          },
        ),
        const SizedBox(height: 8),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Theme.of(context).dividerColor)),
          title: Text('To: ${_restEndTime.format(context)}'),
          trailing: const Icon(Icons.access_time),
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: _restEndTime);
            if (t != null) setState(() => _restEndTime = t);
          },
        ),
        if (_restStartTime.hour > _restEndTime.hour)
           Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              'Rest period spans overnight (Next Day)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  Widget _buildAdvancedTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Instant Capture'),
          subtitle: const Text('Runners captured immediately upon contact'),
          value: _instantCapture,
          onChanged: (val) => setState(() => _instantCapture = val),
        ),
        
        if (!_instantCapture) ...[
          const SizedBox(height: 16),
          Text('Capture Resistance', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
           TextFormField(
            initialValue: _captureResistanceDuration.toString(),
            keyboardType: TextInputType.number,
             decoration: const InputDecoration(labelText: 'Duration (min)', border: OutlineInputBorder()),
            onChanged: (val) => _captureResistanceDuration = int.tryParse(val) ?? 0,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _captureResistanceDistance.toString(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Distance (m)', border: OutlineInputBorder()),
            onChanged: (val) => _captureResistanceDistance = double.tryParse(val) ?? 0,
          ),
        ],
        
        if (_gameMode == 'target') ...[
          const Divider(),
          TextFormField(
            initialValue: _switchCooldown.toString(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Switch Target Cooldown (min)',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => _switchCooldown = int.tryParse(val) ?? 0,
          ),
        ],
      ],
    );
  }
}
