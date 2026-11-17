import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/models/tabela_descontos.dart';

/// Tabela de descontos da empresa logada, fornecida em main.dart a partir
/// da sessão. Fora de um Provider (ex.: testes de widget) usa o padrão.
/// Use [listen] = false fora do build (ex.: initState).
TabelaDescontos tabelaDescontosDe(BuildContext context, {bool listen = true}) {
  try {
    return Provider.of<TabelaDescontos>(context, listen: listen);
  } on ProviderNotFoundException {
    return TabelaDescontos.padrao;
  }
}
