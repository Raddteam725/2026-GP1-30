import 'package:flutter/material.dart';

import 'volunteer_components.dart';

class VolunteerPolicyScreen extends StatelessWidget {
  const VolunteerPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = stringsOf(context);
    final text = s.vPrivacyDocument;
    return Scaffold(
      appBar: AppBar(title: Text(s.vPrivacyTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            for (final paragraph in text.split('\n\n'))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: paragraph.startsWith('### ')
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          VolunteerHeading(
                            paragraph.split('\n').first.substring(4),
                          ),
                          const SizedBox(height: 8),
                          Text(paragraph.split('\n').skip(1).join(' ')),
                        ],
                      )
                    : Text(paragraph.replaceAll('\n', ' ')),
              ),
          ],
        ),
      ),
    );
  }
}
