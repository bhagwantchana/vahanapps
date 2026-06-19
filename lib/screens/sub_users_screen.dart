import 'dart:math' as math;
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/cubits/home_cubit/home_cubit.dart';
import 'package:fleet_monitor/models/sub_user_model.dart';
import 'package:fleet_monitor/models/vehicle_record.dart';
import 'package:fleet_monitor/repositorys/sub_user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

/// Primary customer screen to manage sub-users (foreman / manager).
///   • list current sub-users with their assigned-vehicle counts
///   • add a new sub-user (first/last/email/username/phone/password)
///   • reset password
///   • assign vehicles (multi-select)
///   • delete (soft)
///
/// Hidden from sub-users — they shouldn't see this drawer entry; the
/// server also blocks the endpoints if they somehow reach them.
class SubUsersScreen extends StatefulWidget {
  const SubUsersScreen({super.key});
  static const String routeName = 'sub_users_screen';

  @override
  State<SubUsersScreen> createState() => _SubUsersScreenState();
}

class _SubUsersScreenState extends State<SubUsersScreen> {
  final SubUserRepository _repo = SubUserRepository();
  bool _loading = true;
  String? _error;
  List<SubUser> _subUsers = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.list();
      if (!mounted) return;
      setState(() {
        _subUsers = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openAddDialog() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _AddSubUserSheet(repo: _repo),
      ),
    );
    if (created == true) _refresh();
  }

  /// Bottom sheet showing the vehicles currently assigned to this
  /// sub-user with a Remove button on each row — direct unassign.
  Future<void> _openAssignedListSheet(SubUser sub) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AssignedListSheet(repo: _repo, subUser: sub),
    );
    if (changed == true) _refresh();
  }

  Future<void> _openAssignDialog(SubUser sub) async {
    final assigned = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AssignVehiclesSheet(repo: _repo, subUser: sub),
    );
    if (assigned == true) _refresh();
  }

  Future<void> _openResetPwdDialog(SubUser sub) async {
    // Stored passwords are bcrypt-hashed → original CAN'T be recovered.
    // What we CAN do: let the primary type / generate a new one with
    // eye-toggle to see it, copy & share, then save.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ResetPasswordDialog(sub: sub),
    );
    if (ok != true) return;
    // The dialog already called the API + showed a snackbar. Refresh.
    _refresh();
  }

  Future<void> _confirmDelete(SubUser sub) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${sub.displayName}?'),
        content: Text(
            'They will lose access to all ${sub.assignedCount} assigned vehicle(s).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.delete(sub.id);
      _toast('Sub-user removed');
      _refresh();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _shareLink(SubUser sub) async {
    try {
      final url = await _repo.shareLink(sub.id);
      if (!mounted) return;
      if (url.isEmpty) {
        _toast('Could not generate link', error: true);
        return;
      }
      // No auto-copy on open — the user picks Share (real share sheet) or
      // Copy (clipboard fallback) explicitly.
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Share link — ${sub.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                  'Share this link with the user. It shows only their assigned '
                  'vehicle(s) live on a map — no login needed.'),
              const SizedBox(height: 10),
              SelectableText(url,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close')),
            // Secondary fallback: copy to clipboard.
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                Navigator.pop(ctx);
                _toast('Link copied');
              },
            ),
            // Primary action: real OS share sheet.
            ElevatedButton.icon(
              icon: const Icon(Icons.share, size: 16),
              label: const Text('Share'),
              onPressed: () {
                Navigator.pop(ctx);
                Share.share(
                  url,
                  subject: 'Live tracking — ${sub.displayName}',
                );
              },
            ),
          ],
        ),
      );
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : AppTheme.primaryGreen,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Manage Sub-Users')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryGreen,
        onPressed: _openAddDialog,
        icon: const Icon(LucideIcons.userPlus, color: Colors.white),
        label: const Text('Add Sub-User',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _subUsers.isEmpty
                  ? _emptyView()
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                        itemCount: _subUsers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _subUserCard(_subUsers[i]),
                      ),
                    ),
    );
  }

  Widget _emptyView() {
    return ListView(
      padding: const EdgeInsets.all(24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(LucideIcons.users, size: 56, color: Colors.grey.shade400),
        const SizedBox(height: 18),
        Text(
          'No sub-users yet',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface),
        ),
        const SizedBox(height: 6),
        Text(
          'Create a sub-user (e.g. foreman, manager) and assign a few of your vehicles to them. They will get read-only access to only those vehicles.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13, color: Colors.grey.shade600, height: 1.4),
        ),
      ],
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.cloudOff, size: 56, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(_error ?? 'Failed',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700)),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(LucideIcons.refreshCcw, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subUserCard(SubUser s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.12),
                child: Text(
                  _initials(s.displayName),
                  style: const TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text('@${s.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600)),
                    if (s.hasRealEmail)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(s.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                      ),
                    if (s.phone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(s.phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                      ),
                  ],
                ),
              ),
              // Tap badge → opens a sheet listing assigned vehicles with
              // per-row "remove" so the primary can unassign without
              // wading through the multi-select editor.
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openAssignedListSheet(s),
                child: _badge(
                    '${s.assignedCount} 🚗',
                    AppTheme.primaryGreen,
                    AppTheme.primaryGreen.withValues(alpha: 0.1)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.car, size: 15),
                  label: const Text('Assign vehicles'),
                  onPressed: () => _openAssignDialog(s),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Share link',
                icon: const Icon(LucideIcons.share2, size: 18),
                onPressed: () => _shareLink(s),
              ),
              IconButton(
                tooltip: 'Reset password',
                icon: const Icon(LucideIcons.keyRound, size: 18),
                onPressed: () => _openResetPwdDialog(s),
              ),
              IconButton(
                tooltip: 'Remove',
                icon: Icon(LucideIcons.trash2,
                    size: 18, color: Colors.red.shade600),
                onPressed: () => _confirmDelete(s),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, color: fg, fontWeight: FontWeight.w700)),
      );

  String _initials(String name) {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

// ───────── Add Sub-User bottom sheet ─────────────────────────────────
class _AddSubUserSheet extends StatefulWidget {
  const _AddSubUserSheet({required this.repo});
  final SubUserRepository repo;

  @override
  State<_AddSubUserSheet> createState() => _AddSubUserSheetState();
}

class _AddSubUserSheetState extends State<_AddSubUserSheet> {
  final _firstCtl = TextEditingController();
  final _lastCtl = TextEditingController();
  final _userCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _pwdCtl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _firstCtl.dispose();
    _lastCtl.dispose();
    _userCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _pwdCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final first = _firstCtl.text.trim();
    final user = _userCtl.text.trim();
    final pwd = _pwdCtl.text;
    if (first.isEmpty) {
      setState(() => _error = 'First name required');
      return;
    }
    if (user.length < 3) {
      setState(() => _error = 'Username: at least 3 chars');
      return;
    }
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(user)) {
      setState(() => _error = 'Username: letters, digits, . _ - only');
      return;
    }
    if (pwd.length < 6) {
      setState(() => _error = 'Password: at least 6 chars');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repo.create(
        firstName: first,
        lastName: _lastCtl.text.trim(),
        username: user,
        password: pwd,
        email: _emailCtl.text.trim(),
        phone: _phoneCtl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Add Sub-User',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _field(_firstCtl, 'First name *', LucideIcons.user)),
              const SizedBox(width: 10),
              Expanded(child: _field(_lastCtl, 'Last name', LucideIcons.user)),
            ]),
            _field(_userCtl, 'Username * (login id)', LucideIcons.atSign,
                helper: 'Letters / digits / . _ - · min 3 chars'),
            _field(_emailCtl, 'Email (optional)', LucideIcons.mail,
                keyboard: TextInputType.emailAddress,
                helper: 'Leave blank if user has no email'),
            _field(_phoneCtl, 'Phone (optional)', LucideIcons.phone,
                keyboard: TextInputType.phone),
            _field(_pwdCtl, 'Password * (min 6 chars)', LucideIcons.lock,
                obscure: _obscure,
                suffix: IconButton(
                  icon: Icon(
                      _obscure ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 18),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.30))),
                child: Row(children: [
                  Icon(LucideIcons.alertCircle,
                      color: Colors.red.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!,
                          style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.w600))),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white)))
                    : const Icon(LucideIcons.userPlus, size: 18),
                label: Text(_saving ? 'Saving…' : 'Create Sub-User',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {bool obscure = false,
      String? helper,
      TextInputType? keyboard,
      Widget? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: keyboard,
        inputFormatters: keyboard == TextInputType.phone
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))]
            : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 18),
          suffixIcon: suffix,
          helperText: helper,
          helperMaxLines: 2,
        ),
      ),
    );
  }
}

// ───────── Assign Vehicles bottom sheet ──────────────────────────────
class _AssignVehiclesSheet extends StatefulWidget {
  const _AssignVehiclesSheet({required this.repo, required this.subUser});
  final SubUserRepository repo;
  final SubUser subUser;

  @override
  State<_AssignVehiclesSheet> createState() => _AssignVehiclesSheetState();
}

class _AssignVehiclesSheetState extends State<_AssignVehiclesSheet> {
  late Set<int> _selected;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = <int>{};
    // Pre-select currently assigned vehicles
    widget.repo.assignments(widget.subUser.id).then((rows) {
      if (!mounted) return;
      setState(() {
        _selected = rows.map((r) => r.vehicleId).toSet();
      });
    }).catchError((_) {});
  }

  Future<void> _save(List<VehicleRecord> all) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // First unassign anything de-selected, then bulk-assign the new set.
      final current =
          await widget.repo.assignments(widget.subUser.id);
      final currentIds = current.map((r) => r.vehicleId).toSet();
      final toAdd = _selected.difference(currentIds).toList();
      final toRemove = currentIds.difference(_selected).toList();
      for (final vid in toRemove) {
        await widget.repo.unassign(widget.subUser.id, vid);
      }
      if (toAdd.isNotEmpty) {
        await widget.repo.assignVehicles(widget.subUser.id, toAdd);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read the primary's vehicles from the existing HomeCubit state — no
    // extra network call needed.
    final state = context.watch<HomeCubit>().state;
    final vehicles =
        state.dashboardModel?.data?.vehicleList ?? const <VehicleRecord>[];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      AppTheme.primaryGreen.withValues(alpha: 0.15),
                  child: const Icon(LucideIcons.userCheck,
                      color: AppTheme.primaryGreen, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Assign to ${widget.subUser.displayName}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      Text('@${widget.subUser.username}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Text('${_selected.length} / ${vehicles.length}',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const Divider(height: 24),
            if (vehicles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text('No vehicles to assign.',
                    style: TextStyle(color: Colors.grey.shade600)),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: vehicles.length,
                  itemBuilder: (_, i) {
                    final v = vehicles[i];
                    final id = v.id;
                    final isSel = _selected.contains(id);
                    return CheckboxListTile(
                      value: isSel,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selected.add(id);
                          } else {
                            _selected.remove(id);
                          }
                        });
                      },
                      title: Text(
                          v.name.isEmpty ? v.registrationNumber : v.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(v.registrationNumber,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                      activeColor: AppTheme.primaryGreen,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    );
                  },
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed:
                    _saving || vehicles.isEmpty ? null : () => _save(vehicles),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white)))
                    : const Icon(LucideIcons.check, size: 18),
                label: Text(_saving ? 'Saving…' : 'Save Assignment',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────── Reset password dialog ─────────────────────────────────────
/// Shows a text field for the NEW password with an eye-toggle so the
/// primary can verify what they typed before saving. Also has a
/// "Generate" button that creates a strong random password and a
/// "Copy" button so the primary can share it with the sub-user.
///
/// Note: stored passwords are bcrypt-hashed. The original CANNOT be
/// recovered — by design. If the primary forgets the password they
/// previously set, they simply set a new one here.
class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.sub});
  final SubUser sub;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final TextEditingController _ctl = TextEditingController();
  final SubUserRepository _repo = SubUserRepository();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _generate() {
    // Friendly random — no confusing chars (0/O, 1/l/I removed).
    const chars =
        'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rand = math.Random.secure();
    final out = List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
    setState(() {
      _ctl.text = out;
      _obscure = false; // show it so they can copy immediately
    });
  }

  Future<void> _save() async {
    final pwd = _ctl.text;
    if (pwd.length < 6) {
      setState(() => _error = 'At least 6 characters');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.resetPassword(widget.sub.id, pwd);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reset password — ${widget.sub.displayName}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.30)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.shieldAlert,
                    color: Colors.amber.shade800, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Old password cannot be recovered (encrypted). Set a new one below and share it with @${widget.sub.username}.',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade900,
                        height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctl,
            autofocus: true,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: const Icon(LucideIcons.lock, size: 18),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Copy',
                    icon: const Icon(LucideIcons.copy, size: 16),
                    onPressed: _ctl.text.isEmpty
                        ? null
                        : () {
                            Clipboard.setData(
                                ClipboardData(text: _ctl.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Copied'),
                                  duration: Duration(seconds: 1)),
                            );
                          },
                  ),
                  IconButton(
                    tooltip: _obscure ? 'Show' : 'Hide',
                    icon: Icon(
                        _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                        size: 18),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ],
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(LucideIcons.wand2, size: 16),
            label: const Text('Generate strong password'),
            onPressed: _generate,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        ElevatedButton.icon(
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white)))
              : const Icon(LucideIcons.check, size: 16),
          label: Text(_saving ? 'Saving…' : 'Save'),
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

// ───────── View Assigned Vehicles sheet ──────────────────────────────
/// Shows the vehicles currently assigned to a sub-user with a per-row
/// "remove" button. Pure view + unassign — for bulk assignment use the
/// existing _AssignVehiclesSheet which is a multi-select editor.
class _AssignedListSheet extends StatefulWidget {
  const _AssignedListSheet({required this.repo, required this.subUser});
  final SubUserRepository repo;
  final SubUser subUser;

  @override
  State<_AssignedListSheet> createState() => _AssignedListSheetState();
}

class _AssignedListSheetState extends State<_AssignedListSheet> {
  List<SubUserAssignedVehicle> _items = const [];
  bool _loading = true;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.repo.assignments(widget.subUser.id);
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _unassign(SubUserAssignedVehicle v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            'Remove ${v.vName.isEmpty ? v.vRegistrationNo : v.vName}?'),
        content: const Text(
            'The sub-user will lose access to this vehicle. Re-assign anytime.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.repo.unassign(widget.subUser.id, v.vehicleId);
      _changed = true;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      AppTheme.primaryGreen.withValues(alpha: 0.15),
                  child: const Icon(LucideIcons.car,
                      color: AppTheme.primaryGreen, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Assigned to ${widget.subUser.displayName}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      Text('${_items.length} vehicle(s)',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  tooltip: 'Refresh',
                  onPressed: _load,
                ),
              ],
            ),
            const Divider(height: 22),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(_error!,
                    style: TextStyle(color: Colors.red.shade700)),
              )
            else if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(children: [
                  Icon(LucideIcons.car,
                      size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text('No vehicles assigned yet',
                      style: TextStyle(color: Colors.grey.shade600)),
                ]),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (_, i) {
                    final v = _items[i];
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color:
                              AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(LucideIcons.car,
                            color: AppTheme.primaryBlue, size: 18),
                      ),
                      title: Text(
                          v.vName.isEmpty ? v.vRegistrationNo : v.vName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                      subtitle: Text(v.vRegistrationNo,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                      trailing: IconButton(
                        tooltip: 'Remove',
                        icon: Icon(LucideIcons.userMinus,
                            color: Colors.red.shade600, size: 18),
                        onPressed: () => _unassign(v),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context, _changed),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
