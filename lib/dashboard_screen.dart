import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _aptCtrl = TextEditingController(text: '0');
  final TextEditingController _rxCtrl = TextEditingController(text: '0');

  int _aptCount = 0;
  int _rxCount = 0;

  bool _pushing = false;
  String? _lastMessage;

  late final WebViewController _webViewController;

  bool get _hasEmbed => POWER_BI_EMBED_URL.trim().isNotEmpty;

  late AnimationController _animationController;
  late Animation<double> _aptAnimation;
  late Animation<double> _rxAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _aptAnimation = Tween<double>(begin: 0, end: _aptCount.toDouble()).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _rxAnimation = Tween<double>(begin: 0, end: _rxCount.toDouble()).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    if (_hasEmbed) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..loadRequest(Uri.parse(POWER_BI_EMBED_URL));
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pushAppointment() async {
    final value = _safeParse(_aptCtrl.text);
    setState(() => _aptCount = value);
    _aptAnimation = Tween<double>(begin: 0, end: value.toDouble()).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward(from: 0);
    await _pushToPowerBI(APPOINTMENT_PUSH_URL, [
      {"appointments_today": value}
    ]);
  }

  Future<void> _pushPrescription() async {
    final value = _safeParse(_rxCtrl.text);
    setState(() => _rxCount = value);
    _rxAnimation = Tween<double>(begin: 0, end: value.toDouble()).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward(from: 0);
    await _pushToPowerBI(PRESCRIPTION_PUSH_URL, [
      {"prescriptions_today": value}
    ]);
  }

  Future<void> _pushToPowerBI(
      String url, List<Map<String, dynamic>> rows) async {
    setState(() => _pushing = true);
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(rows),
      );

      if (res.statusCode == 200) {
        setState(() => _lastMessage = '✅ Updated successfully');
        if (_hasEmbed) _webViewController.reload();
      } else {
        setState(() => _lastMessage = '❌ Failed: HTTP ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _lastMessage = '❌ Error: $e');
    } finally {
      setState(() => _pushing = false);
    }
  }

  int _safeParse(String s) => int.tryParse(s.trim()) ?? 0;

  void _increment(TextEditingController c) {
    final v = _safeParse(c.text) + 1;
    c.text = v.toString();
  }

  void _decrement(TextEditingController c) {
    final cur = _safeParse(c.text);
    final v = cur > 0 ? cur - 1 : 0;
    c.text = v.toString();
  }

  Widget _buildCounterCard({
    required String title,
    required Color color,
    required int value,
    required TextEditingController controller,
    required VoidCallback onPush,
    required Animation<double> animation,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.3), color.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return CircleAvatar(
                      radius: 28,
                      backgroundColor: color,
                      child: Text(
                        animation.value.toInt().toString(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Enter value',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    IconButton(
                      onPressed: () => _increment(controller),
                      icon: const Icon(Icons.keyboard_arrow_up,
                          color: Colors.white),
                    ),
                    IconButton(
                      onPressed: () => _decrement(controller),
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _pushing ? null : onPush,
                  icon: _pushing
                      ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_upload),
                  label: const Text('Push'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCounterCard(
            title: 'Appointments Today',
            color: Colors.blueAccent,
            value: _aptCount,
            controller: _aptCtrl,
            onPush: _pushAppointment,
            animation: _aptAnimation,
          ),
          const SizedBox(height: 16),
          _buildCounterCard(
            title: 'Prescriptions Today',
            color: Colors.greenAccent,
            value: _rxCount,
            controller: _rxCtrl,
            onPush: _pushPrescription,
            animation: _rxAnimation,
          ),
          if (_lastMessage != null) ...[
            const SizedBox(height: 12),
            Text(_lastMessage!,
                style: const TextStyle(fontSize: 14, color: Colors.white70)),
          ],
          const SizedBox(height: 20),
          if (_hasEmbed)
            Container(
              height: 420,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: WebViewWidget(controller: _webViewController),
              ),
            )
          else

            _EmbedHelpCard(),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Dashboard'),
        actions: [
          if (_hasEmbed)
            IconButton(
              tooltip: 'Refresh dashboard',
              onPressed: () => _webViewController.reload(),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: body,
    );
  }
}


class _EmbedHelpCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Add your Power BI embed URL',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            SizedBox(height: 8),
            Text(
              'Paste your Power BI Embed URL into POWER_BI_EMBED_URL to see the live dashboard.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}