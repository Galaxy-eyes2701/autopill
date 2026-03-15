// lib/presentation/settings/notification_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autopill/core/services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen>
    with SingleTickerProviderStateMixin {
  // ─── State ────────────────────────────────────────────────────────────────
  NotifPrefs _prefs = const NotifPrefs();
  bool _loading = true;
  bool _testingSound = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const _blue = Color(0xFF137FEC);

  // ─── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _load();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ─── Data ──────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    final p = await NotificationService.instance.loadPrefs();
    if (mounted) {
      setState(() {
        _prefs   = p;
        _loading = false;
      });
      _animCtrl.forward();
    }
  }

  Future<void> _save(NotifPrefs updated) async {
    setState(() => _prefs = updated);
    await NotificationService.instance.savePrefs(updated);
    HapticFeedback.selectionClick();
  }

  Future<void> _testSound() async {
    setState(() => _testingSound = true);
    await NotificationService.instance.showTest(_prefs);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _testingSound = false);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_loading)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _blue)))
          else
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Bật / tắt thông báo ──────────────────────────
                        _SectionTitle(title: 'Thông báo chung'),
                        _buildMainToggleCard(),
                        const SizedBox(height: 20),

                        // ── Âm thanh ──────────────────────────────────────
                        _SectionTitle(title: 'Âm thanh'),
                        _buildSoundCard(),
                        const SizedBox(height: 20),

                        // ── Rung ──────────────────────────────────────────
                        _SectionTitle(title: 'Rung'),
                        _buildVibrationCard(),
                        const SizedBox(height: 20),

                        // ── Test ──────────────────────────────────────────
                        _buildTestButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 100,
      backgroundColor: _blue,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
        title: Text(
          'Cài đặt thông báo',
          style: GoogleFonts.lexend(
              fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E88E5), Color(0xFF137FEC), Color(0xFF0D6EDC)],
            ),
          ),
        ),
      ),
    );
  }

  // ── Main toggle card ───────────────────────────────────────────────────────
  Widget _buildMainToggleCard() {
    return _Card(
      child: Column(
        children: [
          _ToggleRow(
            icon: Icons.notifications_active_rounded,
            iconColor: _blue,
            title: 'Âm thanh thông báo',
            subtitle: _prefs.soundEnabled
                ? 'Thông báo sẽ phát âm thanh'
                : 'Thông báo im lặng, chỉ hiện trên màn hình',
            value: _prefs.soundEnabled,
            onChanged: (v) => _save(_prefs.copyWith(soundEnabled: v)),
          ),
        ],
      ),
    );
  }

  // ── Sound card ─────────────────────────────────────────────────────────────
  Widget _buildSoundCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chọn âm thanh
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.music_note_rounded,
                      color: _blue, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  'Chọn âm thanh',
                  style: GoogleFonts.lexend(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          AnimatedOpacity(
            opacity: _prefs.soundEnabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: Column(
              children: kNotifSounds.map((sound) {
                final selected = _prefs.soundAsset == sound.asset;
                return GestureDetector(
                  onTap: _prefs.soundEnabled
                      ? () => _save(_prefs.copyWith(soundAsset: sound.asset))
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? _blue.withOpacity(0.08)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? _blue : const Color(0xFFE2E8F0),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(sound.emoji,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            sound.name,
                            style: GoogleFonts.lexend(
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: selected ? _blue : const Color(0xFF374151),
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(Icons.check_circle_rounded,
                              color: _blue, size: 20),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          // Âm lượng slider
          AnimatedOpacity(
            opacity: _prefs.soundEnabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _prefs.volume == 0
                            ? Icons.volume_off_rounded
                            : _prefs.volume < 0.5
                            ? Icons.volume_down_rounded
                            : Icons.volume_up_rounded,
                        color: _blue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Âm lượng',
                      style: GoogleFonts.lexend(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(_prefs.volume * 100).toInt()}%',
                        style: GoogleFonts.lexend(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _blue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: _blue,
                    inactiveTrackColor: _blue.withOpacity(0.15),
                    thumbColor: _blue,
                    overlayColor: _blue.withOpacity(0.12),
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10),
                    trackHeight: 5,
                  ),
                  child: Slider(
                    value: _prefs.volume,
                    min: 0,
                    max: 1,
                    divisions: 10,
                    onChanged: _prefs.soundEnabled
                        ? (v) => _save(_prefs.copyWith(volume: v))
                        : null,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Im lặng',
                        style: GoogleFonts.lexend(
                            fontSize: 11,
                            color: Colors.grey.shade400)),
                    Text('Tối đa',
                        style: GoogleFonts.lexend(
                            fontSize: 11,
                            color: Colors.grey.shade400)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Vibration card ─────────────────────────────────────────────────────────
  Widget _buildVibrationCard() {
    return _Card(
      child: Column(
        children: [
          _ToggleRow(
            icon: Icons.vibration_rounded,
            iconColor: Colors.purple,
            title: 'Rung khi thông báo',
            subtitle: _prefs.vibrationEnabled
                ? 'Thiết bị sẽ rung khi có nhắc nhở'
                : 'Không rung khi có nhắc nhở',
            value: _prefs.vibrationEnabled,
            onChanged: (v) => _save(_prefs.copyWith(vibrationEnabled: v)),
          ),
          if (_prefs.vibrationEnabled) ...[
            const SizedBox(height: 12),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border:
                Border.all(color: Colors.purple.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: Colors.purple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kiểu rung: 3 nhịp ngắn (500ms – 300ms – 500ms)',
                      style: GoogleFonts.lexend(
                          fontSize: 11,
                          color: Colors.purple.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Test button ─────────────────────────────────────────────────────────────
  Widget _buildTestButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: _blue,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _testingSound ? null : _testSound,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _testingSound
                ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text('Đang gửi thử...',
                    style: GoogleFonts.lexend(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ],
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.send_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Gửi thông báo thử nghiệm',
                    style: GoogleFonts.lexend(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared sub-widgets ────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.lexend(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.grey.shade500,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.lexend(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              Text(subtitle,
                  style: GoogleFonts.lexend(
                      fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF137FEC),
        ),
      ],
    );
  }
}