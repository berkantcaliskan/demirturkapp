// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

bool _isRegistered = false;
const String _viewType = 'demirturk-official-website-iframe';

Widget buildEmbeddedWebsiteView(String url) {
  if (!_isRegistered) {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#1A2026'
        ..allow = 'fullscreen; geolocation; clipboard-write';
      return iframe;
    });
    _isRegistered = true;
  }

  return const HtmlElementView(viewType: _viewType);
}

void launchPhoneDialer(String phoneUrl) {
  final anchor = html.AnchorElement(href: phoneUrl)..target = '_self';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
