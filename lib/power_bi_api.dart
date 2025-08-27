import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String APPOINTMENT_PUSH_URL = "https://api.powerbi.com/beta/cd575524-9258-4ed8-9487-e1a227be292b/datasets/5d6249fd-fb5b-49d4-9974-31bbe74b0b40/rows?noSignUpCheck=1&ScenarioId=Signup&experience=power-bi&key=ow0zGCBRaRHl4Hc54NcK8bhbggB%2BxigmDiVWcYY3W6qUp77hsymZDFp5KfRVJvf56I%2FPMTEQABzjKu3TXnZvyA%3D%3D";
const String PRESCRIPTION_PUSH_URL = "https://api.powerbi.com/beta/cd575524-9258-4ed8-9487-e1a227be292b/datasets/803f142a-ce9d-44e1-8fe8-60626728dab6/rows?noSignUpCheck=1&ScenarioId=Signup&experience=power-bi&key=Tp4V%2BTljSC0bcf94u1J7a2um60RMxvzCWwuhgZl8uA7Wlmr2owZ5fymPzNt4jazzpWyH9ZrsSQUqx7rYPHN5wg%3D%3D";

class PowerBIPushService {
  final TextEditingController aptCtrl;
  final TextEditingController rxCtrl;
  final Function setStateCallback;
  final Function reloadWebView;

  PowerBIPushService({
    required this.aptCtrl,
    required this.rxCtrl,
    required this.setStateCallback,
    required this.reloadWebView,
  });

  int _safeParse(String s) => int.tryParse(s.trim()) ?? 0;

  Future<void> pushAppointment() async {
    final value = _safeParse(aptCtrl.text);
    setStateCallback(() {});
    await _pushToPowerBI(APPOINTMENT_PUSH_URL, [{"appointments_today": value}]);
  }

  Future<void> pushPrescription() async {
    final value = _safeParse(rxCtrl.text);
    setStateCallback(() {});
    await _pushToPowerBI(PRESCRIPTION_PUSH_URL, [{"prescriptions_today": value}]);
  }

  Future<void> _pushToPowerBI(String url, List<Map<String, dynamic>> rows) async {
    setStateCallback(() {});
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(rows),
      );

      if (res.statusCode == 200) {
        print('✅ Updated successfully');
        reloadWebView();
      } else {
        print('Failed: HTTP ${res.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}
