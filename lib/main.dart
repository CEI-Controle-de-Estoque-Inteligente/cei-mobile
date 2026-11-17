import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/network/connectivity_service.dart';
import 'core/network/http_client.dart';
import 'data/local/database_helper.dart';
import 'data/local/pendencias_local_datasource.dart';
import 'data/local/preferences_service.dart';
import 'data/local/produto_local_datasource.dart';
import 'data/local/secure_session_storage.dart';
import 'data/remote/brasil_api_service.dart';
import 'data/remote/open_food_facts_service.dart';
import 'data/remote/supabase_equipe_datasource.dart';
import 'data/remote/supabase_produto_datasource.dart';
import 'data/remote/supabase_venda_datasource.dart';
import 'data/repositories/assistente_service.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/equipe_repository.dart';
import 'data/repositories/produto_repository.dart';
import 'data/repositories/sync_service.dart';
import 'data/models/tabela_descontos.dart';
import 'data/repositories/venda_repository.dart';
import 'features/auth/viewmodels/session_viewmodel.dart';
import 'features/settings/viewmodels/theme_viewmodel.dart';
import 'features/splash/views/config_error_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  final preferences = await PreferencesService.create();

  if (!Env.isConfigured) {
    runApp(ConfigErrorApp(preferences: preferences));
    return;
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseKey,
    authOptions: const FlutterAuthClientOptions(localStorage: SecureSessionStorage()),
  );

  // Composição das dependências (injeção manual via Provider - C6.8).
  final client = Supabase.instance.client;
  final http = createHttpClient();
  final produtosLocal = ProdutoLocalDataSource();
  final pendencias = PendenciasLocalDataSource();

  final authRepository = SupabaseAuthRepository(client);
  final produtoRepository = ProdutoRepositoryImpl(
    remote: SupabaseProdutoDataSource(client),
    local: produtosLocal,
    pendencias: pendencias,
  );
  final vendaRepository = VendaRepositoryImpl(
    remote: SupabaseVendaDataSource(client),
    produtosLocal: produtosLocal,
    pendencias: pendencias,
  );
  final dashboardRepository = DashboardRepository(SupabaseDashboardDataSource(client));

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: preferences),
        Provider<AuthRepository>.value(value: authRepository),
        Provider<ProdutoRepository>.value(value: produtoRepository),
        Provider<VendaRepository>.value(value: vendaRepository),
        Provider.value(value: EquipeRepository(SupabaseEquipeDataSource(client))),
        Provider.value(value: dashboardRepository),
        Provider.value(
          value: AssistenteService(produtos: produtoRepository, dashboard: dashboardRepository),
        ),
        Provider.value(value: OpenFoodFactsService(http)),
        Provider.value(value: BrasilApiService(http)),
        ChangeNotifierProvider(create: (_) => ThemeViewModel(preferences)),
        ChangeNotifierProvider(create: (_) => ConnectivityService()..start()),
        ChangeNotifierProvider(
          create: (context) => SyncService(
            pendencias: pendencias,
            produtos: produtoRepository,
            vendas: vendaRepository,
            connectivity: context.read<ConnectivityService>(),
          )..carregar(),
        ),
        ChangeNotifierProvider(
          create: (_) => SessionViewModel(
            authRepository,
            preferences,
            limparDadosLocais: DatabaseHelper.instance.limparTudo,
          )..start(),
        ),
        ProxyProvider<SessionViewModel, TabelaDescontos>(
          update: (_, session, _) => session.perfil?.empresa?.descontos ?? TabelaDescontos.padrao,
        ),
      ],
      child: const CeiApp(),
    ),
  );
}
