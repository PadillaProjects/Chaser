import 'dart:math';
import 'package:chaser/models/session.dart';
import 'package:chaser/services/firebase/auth_service.dart';
import 'package:chaser/services/firebase/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class CreateSessionScreen extends ConsumerStatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  ConsumerState<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends ConsumerState<CreateSessionScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _firestoreService = FirestoreService();
  
  late TabController _tabController;

  // --- State Variables ---

  // General
  double _maxMembers = 8;
  
  // Game Rules
  String _gameMode = 'original';
  int _durationDays = 7;
  int _numChasers = 1;
  double _headstartDistance = 0; // meters
  int _headstartDuration = 0; // minutes
  TimeOfDay _restStartTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _restEndTime = const TimeOfDay(hour: 0, minute: 0);

  // Advanced / Capture
  bool _instantCapture = false;
  int _captureResistanceDuration = 0; // minutes
  double _captureResistanceDistance = 0; // meters
  int _switchCooldown = 0; // minutes (Target mode only)

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _generateJoinCode() {
    final random = Random();
    // Generate 4 digit code between 1000 and 9999
    return (1000 + random.nextInt(9000)).toString();
  }

  Future<void> _createSession() async {
    if (!_formKey.currentState!.validate()) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Please check your inputs')),
       );
       return;
    }
    
    final authService = AuthService();
    final userUid = authService.currentUser?.uid;
    
    if (userUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Not authenticated')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final session = SessionModel(
        id: '', 
        name: _nameController.text.trim(),
        ownerId: userUid,
        createdBy: userUid,
        gameMode: _gameMode,
        durationDays: _durationDays,
        numChasers: _numChasers,
        maxMembers: _maxMembers.round(),
        visibility: 'private', 
        joinCode: _generateJoinCode(),
        password: null,
        
        // New Settings
        headstartDistance: _headstartDistance,
        headstartDuration: _headstartDuration,
        restStartHour: _restStartTime.hour,
        restEndHour: _restEndTime.hour,
        switchCooldown: _switchCooldown,
        instantCapture: _instantCapture,
        captureResistanceDuration: _captureResistanceDuration,
        captureResistanceDistance: _captureResistanceDistance,
      );

      final sessionId = await _firestoreService.createSession(session);
      
      if (mounted) {
        context.replace('/session/$sessionId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create session: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Game'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Rules'),
            Tab(text: 'Advanced'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildGeneralTab(),
            _buildRulesTab(),
            _buildAdvancedTab(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FilledButton(
             onPressed: _isLoading ? null : _createSession,
             child: _isLoading 
                 ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                 : const Text('Create Game'),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Session Name',
            hintText: 'e.g. Office Challenge',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.edit),
          ),
          validator: (v) => v?.isEmpty == true ? 'Required' : null,
        ),
        const SizedBox(height: 24),
        
        const Text('Max Members'),
        Slider(
          value: _maxMembers,
          min: 2,
          max: 8,
          divisions: 6,
          label: _maxMembers.round().toString(),
          onChanged: (val) => setState(() => _maxMembers = val),
        ),
        
        const SizedBox(height: 24),
        const Divider(),
      ],
    );
  }

  Widget _buildRulesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          value: _gameMode,
          decoration: const InputDecoration(
            labelText: 'Game Mode',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.games),
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
          decoration: const InputDecoration(
            labelText: 'Duration',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.timer),
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
        
        // Num Chasers
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
        
        // Headstart
        Text('Headstart', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _headstartDistance.toString(),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Distance (meters)',
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
            labelText: 'Duration (minutes)',
            border: OutlineInputBorder(),
            suffixText: 'min',
          ),
          onChanged: (val) => _headstartDuration = int.tryParse(val) ?? 0,
        ),
        
        const Divider(),

        // Rest Hours
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
            decoration: const InputDecoration(
              labelText: 'Resistance Duration (min)',
              border: OutlineInputBorder(),
              suffixText: 'min',
            ),
            onChanged: (val) => _captureResistanceDuration = int.tryParse(val) ?? 0,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _captureResistanceDistance.toString(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Resistance Distance (m)',
              border: OutlineInputBorder(),
              suffixText: 'm',
            ),
            onChanged: (val) => _captureResistanceDistance = double.tryParse(val) ?? 0,
          ),
        ],
        
        if (_gameMode == 'target') ...[
          const Divider(),
          Text('Target Mode Specifics', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _switchCooldown.toString(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Switch Target Cooldown',
              helperText: 'Time before a chaser can switch targets again',
              border: OutlineInputBorder(),
              suffixText: 'min',
            ),
            onChanged: (val) => _switchCooldown = int.tryParse(val) ?? 0,
          ),
        ],
      ],
    );
  }
}
