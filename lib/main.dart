/*
// Flutter + Power BI Live Dashboard
// ------------------------------------------------------------
// What this does
// - Lets you input Appointment & Prescription counts from the app
// - Pushes those values to your Power BI Streaming Datasets (via Push API)
// - Shows the live Power BI dashboard/report inside the app (WebView)
// - Animates the counters so you can see front-end changes instantly
//
// Quick setup
// 1) Replace the three constants below with your URLs.
//    - APPOINTMENT_PUSH_URL: your Appointment dataset "rows" push URL
//    - PRESCRIPTION_PUSH_URL: your Prescription dataset "rows" push URL
//    - POWER_BI_EMBED_URL: a public/embed URL to your report or dashboard.
//      (For a quick demo, use Power BI "Publish to Web" and paste the view URL.)
// 2) pubspec.yaml -> add dependencies:
//      http: ^1.1.0
//      webview_flutter: ^4.7.0
// 3) ANDROID: AndroidManifest.xml -> add Internet permission
//      <uses-permission android:name="android.permission.INTERNET" />
// 4) iOS: If needed for non-https assets, set ATS exceptions. For normal https Power BI, not required.
//
// Security note: Do NOT ship production apps with Power BI push keys hardcoded.
// Use a secure backend to proxy requests in real projects.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

// ===================== CONFIGURE ME =====================
const String APPOINTMENT_PUSH_URL =
    "https://api.powerbi.com/beta/cd575524-9258-4ed8-9487-e1a227be292b/datasets/5d6249fd-fb5b-49d4-9974-31bbe74b0b40/rows?noSignUpCheck=1&ScenarioId=Signup&experience=power-bi&key=ow0zGCBRaRHl4Hc54NcK8bhbggB%2BxigmDiVWcYY3W6qUp77hsymZDFp5KfRVJvf56I%2FPMTEQABzjKu3TXnZvyA%3D%3D";

const String PRESCRIPTION_PUSH_URL =
    "https://api.powerbi.com/beta/cd575524-9258-4ed8-9487-e1a227be292b/datasets/803f142a-ce9d-44e1-8fe8-60626728dab6/rows?noSignUpCheck=1&ScenarioId=Signup&experience=power-bi&key=Tp4V%2BTljSC0bcf94u1J7a2um60RMxvzCWwuhgZl8uA7Wlmr2owZ5fymPzNt4jazzpWyH9ZrsSQUqx7rYPHN5wg%3D%3D";

// Power BI public/embed URL (report or dashboard). Example: Publish-to-web link.
// Paste your Power BI view URL here. Leave empty to hide the WebView.
const String POWER_BI_EMBED_URL = ""; // e.g. "https://app.powerbi.com/view?r=..."
// ========================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LiveDashboardApp());
}

class LiveDashboardApp extends StatelessWidget {
  const LiveDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Medical Live Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _aptCtrl = TextEditingController(text: '0');
  final TextEditingController _rxCtrl = TextEditingController(text: '0');

  int _aptCount = 0;
  int _rxCount = 0;

  bool _pushing = false;
  String? _lastMessage;

  late final WebViewController _webViewController;
  bool get _hasEmbed => POWER_BI_EMBED_URL.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();

    if (_hasEmbed) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..loadRequest(Uri.parse(POWER_BI_EMBED_URL));
    }
  }

  Future<void> _pushAppointment(int value) async {
    await _pushToPowerBI(APPOINTMENT_PUSH_URL, [{"appointments_today": value}]);
  }

  Future<void> _pushPrescription(int value) async {
    await _pushToPowerBI(PRESCRIPTION_PUSH_URL, [{"prescriptions_today": value}]);
  }

  Future<void> _pushToPowerBI(String url, List<Map<String, dynamic>> rows) async {
    setState(() => _pushing = true);
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(rows),
      );

      if (res.statusCode == 200) {
        setState(() => _lastMessage = '✅ Updated successfully');
        // Optionally refresh the WebView so you see changes faster
        if (_hasEmbed) {
          _webViewController.reload();
        }
      } else {
        setState(() => _lastMessage = '❌ Failed: HTTP ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _lastMessage = '❌ Error: $e');
    } finally {
      setState(() => _pushing = false);
    }
  }

  int _safeParse(String s) {
    return int.tryParse(s.trim()) ?? 0;
  }

  void _increment(TextEditingController c, void Function(int) onNew) {
    final v = _safeParse(c.text) + 1;
    c.text = v.toString();
    onNew(v);
  }

  void _decrement(TextEditingController c, void Function(int) onNew) {
    final cur = _safeParse(c.text);
    final v = cur > 0 ? cur - 1 : 0;
    c.text = v.toString();
    onNew(v);
  }

  Widget _buildCounterCard({
    required String title,
    required int value,
    required TextEditingController controller,
    required VoidCallback onPush,
    required void Function(int) onChangedLocal,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value.toDouble()),
                  duration: const Duration(milliseconds: 400),
                  builder: (context, v, _) => Text(
                    v.toInt().toString(),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
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
                    decoration: const InputDecoration(
                      labelText: 'Enter value',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (s) => onChangedLocal(_safeParse(s)),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    IconButton(
                      onPressed: () => _increment(controller, onChangedLocal),
                      icon: const Icon(Icons.keyboard_arrow_up),
                      tooltip: 'Increase',
                    ),
                    IconButton(
                      onPressed: () => _decrement(controller, onChangedLocal),
                      icon: const Icon(Icons.keyboard_arrow_down),
                      tooltip: 'Decrease',
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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.cloud_upload),
                  label: const Text('Push to Power BI'),
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
            value: _aptCount,
            controller: _aptCtrl,
            onPush: () async {
              final v = _safeParse(_aptCtrl.text);
              setState(() => _aptCount = v);
              await _pushAppointment(v);
            },
            onChangedLocal: (v) => setState(() => _aptCount = v),
          ),
          _buildCounterCard(
            title: 'Prescriptions Today',
            value: _rxCount,
            controller: _rxCtrl,
            onPush: () async {
              final v = _safeParse(_rxCtrl.text);
              setState(() => _rxCount = v);
              await _pushPrescription(v);
            },
            onChangedLocal: (v) => setState(() => _rxCount = v),
          ),
          if (_lastMessage != null) ...[
            const SizedBox(height: 8),
            Text(_lastMessage!, style: const TextStyle(fontSize: 14)),
          ],
          const SizedBox(height: 12),
          if (_hasEmbed)
            Container(
              height: 420,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
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
        title: const Text('Medical Live Dashboard'),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Add your Power BI embed URL',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text(
              'To see the live dashboard inside the app, paste your Power BI\n'
                  'Publish-to-web or Embedded report URL into POWER_BI_EMBED_URL\n'
                  'at the top of this file and rebuild the app.',
            ),
            SizedBox(height: 8),
            Text('Note: Publish-to-web makes the report public. For secure access,\n'
                'use Power BI Embedded with an access token served by your backend.'),
          ],
        ),
      ),
    );
  }
}
*/
/*import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medical Dashboard',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController appointmentController = TextEditingController();
  final TextEditingController prescriptionController = TextEditingController();

  final String appointmentApiUrl =
      "https://api.powerbi.com/beta/cd575524-9258-4ed8-9487-e1a227be292b/datasets/5d6249fd-fb5b-49d4-9974-31bbe74b0b40/rows?key=ow0zGCBRaRHl4Hc54NcK8bhbggB%2BxigmDiVWcYY3W6qUp77hsymZDFp5KfRVJvf56I%2FPMTEQABzjKu3TXnZvyA%3D%3D";

  final String prescriptionApiUrl =
      "https://api.powerbi.com/beta/cd575524-9258-4ed8-9487-e1a227be292b/datasets/803f142a-ce9d-44e1-8fe8-60626728dab6/rows?key=Tp4V%2BTljSC0bcf94u1J7a2um60RMxvzCWwuhgZl8uA7Wlmr2owZ5fymPzNt4jazzpWyH9ZrsSQUqx7rYPHN5wg%3D%3D";

  Future<void> pushAppointmentData() async {
    if (appointmentController.text.isEmpty) return;

    final response = await http.post(
      Uri.parse(appointmentApiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "rows": [
          {"AppointmentCount": appointmentController.text}
        ]
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment Data Pushed Successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${response.body}')),
      );
    }
  }

  Future<void> pushPrescriptionData() async {
    if (prescriptionController.text.isEmpty) return;

    final response = await http.post(
      Uri.parse(prescriptionApiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "rows": [
          {"PrescriptionCount": prescriptionController.text}
        ]
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription Data Pushed Successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${response.body}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medical Dashboard Controller')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: appointmentController,
              decoration: const InputDecoration(
                labelText: 'Enter Appointment Count',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: pushAppointmentData,
              child: const Text('Push Appointment Data'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: prescriptionController,
              decoration: const InputDecoration(
                labelText: 'Enter Prescription Count',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: pushPrescriptionData,
              child: const Text('Push Prescription Data'),
            ),
          ],
        ),
      ),
    );
  }
}*/
/*import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Medical Dashboard',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController appointmentController = TextEditingController();
  final TextEditingController prescriptionController = TextEditingController();

  final String appointmentApiUrl =
      "https://api.powerbi.com/beta/cd575524-9258-4ed8-9487-e1a227be292b/datasets/5d6249fd-fb5b-49d4-9974-31bbe74b0b40/rows?key=ow0zGCBRaRHl4Hc54NcK8bhbggB%2BxigmDiVWcYY3W6qUp77hsymZDFp5KfRVJvf56I%2FPMTEQABzjKu3TXnZvyA%3D%3D";

  final String prescriptionApiUrl =
      "https://api.powerbi.com/beta/cd575524-9258-4ed8-9487-e1a227be292b/datasets/803f142a-ce9d-44e1-8fe8-60626728dab6/rows?key=Tp4V%2BTljSC0bcf94u1J7a2um60RMxvzCWwuhgZl8uA7Wlmr2owZ5fymPzNt4jazzpWyH9ZrsSQUqx7rYPHN5wg%3D%3D";

  Future<void> pushAppointmentData() async {
    if (appointmentController.text.isEmpty) return;

    final response = await http.post(
      Uri.parse(appointmentApiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "rows": [
          {"AppointmentCount": appointmentController.text}
        ]
      }),
    );

    _showResult(response, "Appointment");
  }

  Future<void> pushPrescriptionData() async {
    if (prescriptionController.text.isEmpty) return;

    final response = await http.post(
      Uri.parse(prescriptionApiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "rows": [
          {"PrescriptionCount": prescriptionController.text}
        ]
      }),
    );

    _showResult(response, "Prescription");
  }

  void _showResult(http.Response response, String type) {
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type Data Pushed Successfully ✅')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to Push $type: ${response.body}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Medical Dashboard Controller'),
        backgroundColor: Colors.teal,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Update Appointment Count",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: appointmentController,
              decoration: InputDecoration(
                hintText: 'Enter Appointment Number',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                onPressed: pushAppointmentData,
                icon: const Icon(Icons.send),
                label: const Text('Submit Appointment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Update Prescription Count",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: prescriptionController,
              decoration: InputDecoration(
                hintText: 'Enter Prescription Number',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                onPressed: pushPrescriptionData,
                icon: const Icon(Icons.send),
                label: const Text('Submit Prescription'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}*/
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

const String APPOINTMENT_PUSH_URL =
    "https://api.powerbi.com/beta/cd575524-9258-4ed8-9487-e1a227be292b/datasets/"
    "5d6249fd-fb5b-49d4-9974-31bbe74b0b40/rows?noSignUpCheck=1&ScenarioId=Signup&"
    "experience=power-bi&key=ow0zGCBRaRHl4Hc54NcK8bhbggB%2BxigmDiVWcYY3W6qUp77hs"
    "ymZDFp5KfRVJvf56I%2FPMTEQABzjKu3TXnZvyA%3D%3D";

const String PRESCRIPTION_PUSH_URL =
    "https://api.powerbi.com/beta/cd575524-9258-4ed8-9487-e1a227be292b/datasets/"
    "803f142a-ce9d-44e1-8fe8-60626728dab6/rows?noSignUpCheck=1&ScenarioId=Signup&"
    "experience=power-bi&key=Tp4V%2BTljSC0bcf94u1J7a2um60RMxvzCWwuhgZl8uA7Wlmr2"
    "owZ5fymPzNt4jazzpWyH9ZrsSQUqx7rYPHN5wg%3D%3D";

const String POWER_BI_EMBED_URL =
    "https://app.powerbi.com/reportEmbed?reportId=35addb2c-4e4e-4f70-89c1-9dac07"
    "0294c9&groupId=3482e7eb-66b7-4816-b847-95d14a8dd2dc&autoAuth=true&ctid=<cd5"
    "75524-9258-4ed8-9487-e1a227be292b>";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LiveDashboardApp());
}

class LiveDashboardApp extends StatelessWidget {
  const LiveDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Live Dashboard',
      theme: ThemeData.dark().copyWith(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.blueAccent,
        ),
        scaffoldBackgroundColor: Colors.grey[900],
      ),
      home: const DashboardScreen(),
    );
  }
}

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
