import 'package:flutter/material.dart';
import 'website_iframe_stub.dart'
    if (dart.library.html) 'website_iframe_web.dart';

class CustomerWebsiteScreen extends StatelessWidget {
  final String url;

  const CustomerWebsiteScreen({
    super.key,
    this.url = 'https://www.demirturkinsaat.com/',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: buildEmbeddedWebsiteView(url),
    );
  }
}
