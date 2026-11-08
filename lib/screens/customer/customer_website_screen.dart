import 'package:flutter/material.dart';
import 'website_iframe_stub.dart'
    if (dart.library.html) 'website_iframe_web.dart';

class CustomerWebsiteScreen extends StatelessWidget {
  final String url;
  final double bottomPadding;

  const CustomerWebsiteScreen({
    super.key,
    this.url = 'https://www.demirturkinsaat.com/',
    this.bottomPadding = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final mediaBottom = MediaQuery.of(context).padding.bottom;
    final effectiveBottom =
        bottomPadding > mediaBottom ? bottomPadding : mediaBottom;

    return Padding(
      padding: EdgeInsets.only(bottom: effectiveBottom),
      child: ClipRect(
        child: SizedBox.expand(
          child: buildEmbeddedWebsiteView(url),
        ),
      ),
    );
  }
}
