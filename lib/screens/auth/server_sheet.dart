import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

/// Where the XAMPP API lives. All records are stored in the MySQL database.
class ServerSheet extends StatefulWidget {
  const ServerSheet({super.key});
  static Future<void> open(BuildContext context) => sheet(context, const ServerSheet());

  @override
  State<ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends State<ServerSheet> {
  late final TextEditingController url;
  String? result;
  bool resultOk = false, testing = false, saving = false;

  @override
  void initState() {
    super.initState();
    url = TextEditingController(text: AppScope.read(context).apiUrl);
  }

  @override
  void dispose() {
    url.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() {
      testing = true;
      result = null;
    });
    try {
      final r = await AppScope.read(context).testConnection(url.text);
      if (!mounted) return;
      setState(() {
        result = 'Connected · $r';
        resultOk = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        result = '$e';
        resultOk = false;
      });
    } finally {
      if (mounted) setState(() => testing = false);
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    await AppScope.read(context).setServer(url.text);
    if (!mounted) return;
    toast(context, 'Saved · sign in again');
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 18),
          Text('Database server', style: T.h2),
          const SizedBox(height: 4),
          Text('Bookings and accounts are saved in the XAMPP MySQL database.', style: T.bodyMuted),
          const SizedBox(height: 18),
          Field(label: 'API address', hint: 'http://localhost/tala_api/api.php', controller: url, keyboard: TextInputType.url),
          Text(
            '1. Start Apache and MySQL in XAMPP.\n'
            '2. Run 1_SETUP_XAMPP.bat once (or import tala_hotel.sql in phpMyAdmin).\n'
            'On another phone or PC, replace localhost with this PC\'s IP (e.g. 192.168.1.5).',
            style: T.small,
          ),
          AnimatedSwitcher(
            duration: Motion.medium,
            child: result == null
                ? const SizedBox(height: 18)
                : Container(
                    key: ValueKey(result),
                    margin: const EdgeInsets.only(top: 18),
                    padding: const EdgeInsets.all(14),
                    width: double.infinity,
                    decoration: BoxDecoration(color: resultOk ? C.card2 : C.dangerBg, borderRadius: BorderRadius.circular(10)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(resultOk ? Icons.check_circle_rounded : Icons.error_outline_rounded, size: 18, color: resultOk ? C.accent : C.danger),
                      const SizedBox(width: 10),
                      Expanded(child: Text(result!, style: TextStyle(fontSize: 13, color: resultOk ? C.text : C.danger))),
                    ]),
                  ),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: Btn('Test', style: BtnStyle.secondary, loading: testing, onTap: _test)),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: Btn('Save', loading: saving, onTap: _save)),
          ]),
        ]),
      );
}
