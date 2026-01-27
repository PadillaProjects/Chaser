import 'dart:math';
import 'package:chaser/config/colors.dart';
import 'package:chaser/models/session.dart';
import 'package:chaser/services/firebase/auth_service.dart';
import 'package:chaser/services/firebase/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // General
  double _maxMembers = 8;

  // Game Rules
  String _gameMode = 'original';
  int _durationDays = 7;
  int _numChasers = 1;
  double _headstartDistance = 0;
  int _headstartDuration = 0;
  TimeOfDay _restStartTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _restEndTime = const TimeOfDay(hour: 0, minute: 0);

  // Advanced / Capture
  bool _instantCapture = false;
  int _captureResistanceDuration = 0;
  double _captureResistanceDistance = 0;
  int _switchCooldown = 0;

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
        title: Text(
          'BEGIN A HUNT',
          style: GoogleFonts.creepster(
            fontSize: 24,
            letterSpacing: 2,
            color: AppColors.ghostWhite,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
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
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppColors.bloodRed.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: FilledButton(
               onPressed: _isLoading ? null : _createSession,
               style: FilledButton.styleFrom(
                 backgroundColor: AppColors.bloodRed,
                 foregroundColor: AppColors.ghostWhite,
                 padding: const EdgeInsets.symmetric(vertical: 18),
                 shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
               ),
               child: _isLoading
                   ? const SizedBox(
                       width: 20,
                       height: 20,
                       child: CircularProgressIndicator(color: AppColors.ghostWhite, strokeWidth: 2),
                     )
                   : Text(
                       'CREATE HUNT',
                       style: GoogleFonts.jetBrainsMono(
                         fontWeight: FontWeight.bold,
                         letterSpacing: 4,
                       ),
                     ),
            ),
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
          style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite),
          decoration: InputDecoration(
            labelText: 'HUNT NAME',
            labelStyle: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary, letterSpacing: 2),
            hintText: 'e.g. Office Bloodbath',
            hintStyle: GoogleFonts.jetBrainsMono(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.fogGrey,
            border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppColors.textMuted.withOpacity(0.3)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppColors.bloodRed, width: 2),
            ),
            prefixIcon: const Icon(Icons.edit, color: AppColors.bloodRed),
          ),
          validator: (v) => v?.isEmpty == true ? 'Required' : null,
        ),
        const SizedBox(height: 24),

        Text(
          'MAX PREY',
          style: GoogleFonts.jetBrainsMono(
            color: AppColors.textSecondary,
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _maxMembers,
                min: 2,
                max: 8,
                divisions: 6,
                activeColor: AppColors.bloodRed,
                inactiveColor: AppColors.textMuted,
                label: _maxMembers.round().toString(),
                onChanged: (val) => setState(() => _maxMembers = val),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.fogGrey,
              child: Text(
                '${_maxMembers.round()}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.bloodRed,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRulesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDropdown(
          label: 'GAME MODE',
          value: _gameMode,
          items: const [
            DropdownMenuItem(value: 'original', child: Text('Original Tag')),
            DropdownMenuItem(value: 'target', child: Text('Target Mode')),
          ],
          onChanged: (val) => setState(() => _gameMode = val!),
          icon: Icons.sports_kabaddi,
        ),
        const SizedBox(height: 16),

        _buildDropdown(
          label: 'DURATION',
          value: _durationDays,
          items: const [
            DropdownMenuItem(value: 3, child: Text('3 Days')),
            DropdownMenuItem(value: 7, child: Text('7 Days')),
            DropdownMenuItem(value: 14, child: Text('14 Days')),
            DropdownMenuItem(value: 30, child: Text('30 Days')),
          ],
          onChanged: (val) => setState(() => _durationDays = val!),
          icon: Icons.timer,
        ),
        const SizedBox(height: 16),

        // Num Chasers
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.fogGrey,
          child: Row(
            children: [
              const Icon(Icons.gps_fixed, color: AppColors.bloodRed),
              const SizedBox(width: 12),
              Text(
                'CHASERS',
                style: GoogleFonts.jetBrainsMono(
                  color: AppColors.ghostWhite,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove, color: AppColors.ghostWhite),
                onPressed: _numChasers > 1 ? () => setState(() => _numChasers--) : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.voidBlack,
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
          label: 'DISTANCE (METERS)',
          initialValue: _headstartDistance.toString(),
          suffix: 'm',
          onChanged: (val) => _headstartDistance = double.tryParse(val) ?? 0,
        ),
        const SizedBox(height: 12),
        _buildNumberField(
          label: 'DURATION (MINUTES)',
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
          color: AppColors.fogGrey,
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
            label: 'RESISTANCE DURATION (MIN)',
            initialValue: _captureResistanceDuration.toString(),
            suffix: 'min',
            onChanged: (val) => _captureResistanceDuration = int.tryParse(val) ?? 0,
          ),
          const SizedBox(height: 12),
          _buildNumberField(
            label: 'RESISTANCE DISTANCE (M)',
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
            helperText: 'Time before a chaser can switch targets',
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

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    IconData? icon,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: AppColors.fogGrey,
      style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary, letterSpacing: 2),
        filled: true,
        fillColor: AppColors.fogGrey,
        border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.textMuted.withOpacity(0.3)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.bloodRed, width: 2),
        ),
        prefixIcon: icon != null ? Icon(icon, color: AppColors.bloodRed) : null,
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildNumberField({
    required String label,
    required String initialValue,
    required String suffix,
    required ValueChanged<String> onChanged,
    String? helperText,
  }) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: TextInputType.number,
      style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary, letterSpacing: 1, fontSize: 12),
        helperText: helperText,
        helperStyle: GoogleFonts.jetBrainsMono(color: AppColors.textMuted, fontSize: 10),
        suffixText: suffix,
        suffixStyle: GoogleFonts.jetBrainsMono(color: AppColors.bloodRed),
        filled: true,
        fillColor: AppColors.fogGrey,
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
          color: AppColors.fogGrey,
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
