import 'package:flutter/material.dart';

Widget buildEmbeddedWebsiteView(String url) {
  return Center(
    child: Text(
      url,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

void launchPhoneDialer(String phoneUrl) {}
