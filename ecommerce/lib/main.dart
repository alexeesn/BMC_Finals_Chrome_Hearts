import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'services/shop_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late Future<ShopGateway> _connection;
  @override
  void initState() {
    super.initState();
    _connection = _connect();
  }

  Future<ShopGateway> _connect() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublicKey,
      debug: false,
    );
    return SupabaseShopGateway(Supabase.instance.client);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ShopGateway>(
    future: _connection,
    builder: (context, snapshot) => MyApp(
      gateway: snapshot.data,
      startupFailed: snapshot.hasError,
      onRetry: () => setState(() => _connection = _connect()),
    ),
  );
}
