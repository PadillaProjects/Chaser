import 'dart:math';
import 'package:chaser/config/colors.dart';
import 'package:chaser/models/session.dart';
import 'package:chaser/services/firebase/auth_service.dart';
import 'package:chaser/services/firebase/firestore_service.dart';
import 'package:chaser/utils/unit_converter.dart';
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
  int _numChasers = 1;

  // Game Rules
  String _gameMode = 'original';
  int _durationDays = 7;
  String _durationUnit = 'days';
  double _headstartDistance = 0;
  String _headstartDistanceUnit = 'm';
  int _headstartDuration = 0;
  String _headstartDurationUnit = 'min';
  TimeOfDay _restStartTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _restEndTime = const TimeOfDay(hour: 0, minute: 0);

  // Advanced / Capture
  bool _instantCapture = false;
  int _captureResistanceDuration = 0;
  String _captureResistanceDurationUnit = 'min';
  double _captureResistanceDistance = 0;
  String _captureResistanceDistanceUnit = 'm';
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
      // Convert display values to canonical DB units (meters, minutes)
      final headstartDistanceMeters =
          UnitConverter.toMeters(_headstartDistance, _headstartDistanceUnit);
      final headstartDurationMinutes =
          UnitConverter.toMinutes(_headstartDuration, _headstartDurationUnit);
      final captureResistanceDurationMinutes = UnitConverter.toMinutes(
          _captureResistanceDuration, _captureResistanceDurationUnit);
      final captureResistanceDistanceMeters = UnitConverter.toMeters(
          _captureResistanceDistance, _captureResistanceDistanceUnit);

      final session = SessionModel(
        id: '',
        name: _nameController.text.trim(),
        ownerId: userUid,
        createdBy: userUid,
        gameMode: _gameMode,
        durationDays: _durationDays,
        durationUnit: _durationUnit,
        numChasers: _numChasers,
        maxMembers: _maxMembers.round(),
        visibility: 'private',
        joinCode: _generateJoinCode(),
        password: null,
        headstartDistance: headstartDistanceMeters,
        headstartDistanceUnit: _headstartDistanceUnit,
        headstartDuration: headstartDurationMinutes,
        headstartDurationUnit: _headstartDurationUnit,
        restStartHour: _restStartTime.hour,
        restEndHour: _restEndTime.hour,
        switchCooldown: _switchCooldown,
        instantCapture: _instantCapture,
        captureResistanceDuration: captureResistanceDurationMinutes,
        captureResistanceDurationUnit: _captureResistanceDurationUnit,
        captureResistanceDistance: captureResistanceDistanceMeters,
        captureResistanceDistanceUnit: _captureResistanceDistanceUnit,
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
          'START A GAME',
          style: GoogleFonts.specialElite(
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
                       'INITIALIZE',
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
            labelText: 'GAME NAME',
            labelStyle: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary, letterSpacing: 2),
            hintText: 'e.g. Woodsboro High',
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
          'MAX PLAYERS',
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
                onChanged: (val) {
                  setState(() {
                    _maxMembers = val;
                    // Clamp chasers so there's always at least 1 runner
                    final maxChasers = _maxMembers.round() - 1;
                    if (_numChasers > maxChasers) _numChasers = maxChasers.clamp(1, 99);
                  });
                },
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
            DropdownMenuItem(value: 'original', child: Text('Normal')),
            DropdownMenuItem(value: 'target', child: Text('Target Mode')),
          ],
          onChanged: (val) => setState(() => _gameMode = val!),
          icon: Icons.sports_kabaddi,
        ),
        const SizedBox(height: 16),

        _buildValueUnitField(
          label: 'GAME DURATION',
          initialValue: _durationDays.toString(),
          onValueChanged: (val) => _durationDays = int.tryParse(val) ?? 7,
          unitValue: _durationUnit,
          units: const ['min', 'hours', 'days'],
          onUnitChanged: (val) => setState(() => _durationUnit = val!),
          helperText: 'How long survivors must outlast the chasers',
        ),
        const SizedBox(height: 16),

        // Chasers – constrained to [1, maxMembers-1]
        _buildChasersRow(),
        const SizedBox(height: 16),

        const SizedBox(height: 24),
        _buildSectionHeader('HEADSTART'),
        const SizedBox(height: 8),

        _buildValueUnitField(
          label: 'DISTANCE',
          initialValue: _headstartDistance.toString(),
          onValueChanged: (val) => _headstartDistance = double.tryParse(val) ?? 0,
          unitValue: _headstartDistanceUnit,
          units: const ['m', 'km', 'mi'],
          onUnitChanged: (val) => setState(() => _headstartDistanceUnit = val!),
        ),
        const SizedBox(height: 12),
        _buildValueUnitField(
          label: 'DURATION',
          initialValue: _headstartDuration.toString(),
          onValueChanged: (val) => _headstartDuration = int.tryParse(val) ?? 0,
          unitValue: _headstartDurationUnit,
          units: const ['min', 'hours', 'days'],
          onUnitChanged: (val) => setState(() => _headstartDurationUnit = val!),
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
          _buildValueUnitField(
            label: 'RESISTANCE DURATION',
            initialValue: _captureResistanceDuration.toString(),
            onValueChanged: (val) => _captureResistanceDuration = int.tryParse(val) ?? 0,
            unitValue: _captureResistanceDurationUnit,
            units: const ['min', 'hours', 'days'],
            onUnitChanged: (val) => setState(() => _captureResistanceDurationUnit = val!),
          ),
          const SizedBox(height: 12),
          _buildValueUnitField(
            label: 'RESISTANCE DISTANCE',
            initialValue: _captureResistanceDistance.toString(),
            onValueChanged: (val) => _captureResistanceDistance = double.tryParse(val) ?? 0,
            unitValue: _captureResistanceDistanceUnit,
            units: const ['m', 'km', 'mi'],
            onUnitChanged: (val) => setState(() => _captureResistanceDistanceUnit = val!),
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

  Widget _buildChasersRow() {
    final maxChasers = (_maxMembers.round() - 1).clamp(1, 99);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.fogGrey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gps_fixed, color: AppColors.bloodRed, size: 20),
              const SizedBox(width: 12),
              Text(
                'CHASERS',
                style: GoogleFonts.jetBrainsMono(
                  color: AppColors.ghostWhite,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              // Decrease button
              IconButton(
                icon: const Icon(Icons.remove, color: AppColors.ghostWhite),
                onPressed: _numChasers > 1
                    ? () => setState(() => _numChasers--)
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                color: AppColors.voidBlack,
                child: Text(
                  '$_numChasers',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.bloodRed,
                  ),
                ),
              ),
              // Increase button
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.ghostWhite),
                onPressed: _numChasers < maxChasers
                    ? () => setState(() => _numChasers++)
                    : null,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              'Max $maxChasers (must leave ≥ 1 runner)',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildValueUnitField({
    required String label,
    required String initialValue,
    required ValueChanged<String> onValueChanged,
    required String unitValue,
    required List<String> units,
    required ValueChanged<String?> onUnitChanged,
    String? helperText,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildNumberField(
            label: label,
            initialValue: initialValue,
            suffix: '',
            onChanged: onValueChanged,
            helperText: helperText,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 1,
          child: DropdownButtonFormField<String>(
            value: unitValue,
            dropdownColor: AppColors.fogGrey,
            style: GoogleFonts.jetBrainsMono(color: AppColors.bloodRed, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
            onChanged: onUnitChanged,
          ),
        ),
      ],
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
