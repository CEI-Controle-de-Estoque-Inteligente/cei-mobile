import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../models/perfil.dart';
import '../models/produto.dart';
import '../models/tabela_descontos.dart';
import 'equipe_repository.dart';
import 'produto_repository.dart';

enum IntencaoAssistente { faltando, vencendo, desconto, resumoVendas, compras, consultaProduto, ajuda }

/// Assistente CEI no app: entende perguntas em linguagem natural (por
/// palavras-chave) e responde com os dados REAIS da empresa.
///
/// A versão com IA generativa e WhatsApp Business roda no backend do PI;
/// no mobile as respostas são calculadas a partir do banco (RN001/RN002 do
/// módulo Assistente).
class AssistenteService {
  AssistenteService({
    required ProdutoRepository produtos,
    required DashboardRepository dashboard,
  }) : _produtos = produtos,
       _dashboard = dashboard;

  final ProdutoRepository _produtos;
  final DashboardRepository _dashboard;

  static const List<String> sugestoes = [
    'O que está faltando?',
    'Quais produtos vão vencer essa semana?',
    'Sugerir desconto',
    'Resumo de vendas de hoje',
    'O que devo comprar?',
  ];

  /// Classificação da pergunta (função pura, coberta por testes).
  static IntencaoAssistente classificar(String pergunta) {
    final t = normalizar(pergunta);
    bool tem(List<String> palavras) => palavras.any(t.contains);

    if (tem(['desconto', 'promoc', 'girar'])) return IntencaoAssistente.desconto;
    if (tem(['vencer', 'vencendo', 'vence', 'validade', 'vencid'])) {
      return IntencaoAssistente.vencendo;
    }
    if (tem(['comprar', 'compra', 'pedido', 'recomend', 'repor', 'reposic'])) {
      return IntencaoAssistente.compras;
    }
    if (tem(['faltando', 'falta', 'acabando', 'acabou', 'baixo', 'critico'])) {
      return IntencaoAssistente.faltando;
    }
    if (tem(['venda', 'vendi', 'faturamento', 'faturei', 'resumo', 'ticket'])) {
      return IntencaoAssistente.resumoVendas;
    }
    if (tem(['quanto tem', 'quantos tem', 'estoque de', 'tem de ', 'saldo de'])) {
      return IntencaoAssistente.consultaProduto;
    }
    return IntencaoAssistente.ajuda;
  }

  static String normalizar(String texto) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const para = 'aaaaaeeeeiiiiooooouuuuc';
    final buffer = StringBuffer();
    for (final rune in texto.toLowerCase().runes) {
      final c = String.fromCharCode(rune);
      final i = de.indexOf(c);
      buffer.write(i >= 0 ? para[i] : c);
    }
    return buffer.toString();
  }

  Future<String> responder(String pergunta, Perfil perfil) async {
    try {
      return switch (classificar(pergunta)) {
        IntencaoAssistente.faltando => await _faltando(perfil),
        IntencaoAssistente.vencendo => await _vencendo(perfil, pergunta),
        IntencaoAssistente.desconto => await _desconto(perfil),
        IntencaoAssistente.resumoVendas => await _resumo(perfil),
        IntencaoAssistente.compras => await _compras(perfil),
        IntencaoAssistente.consultaProduto => await _consulta(perfil, pergunta),
        IntencaoAssistente.ajuda => _ajuda(),
      };
    } on AppException catch (e) {
      return 'Não consegui consultar agora: ${e.message}';
    }
  }

  Future<List<Produto>> _todos(Perfil perfil, FiltroEstoque filtro) async {
    final pagina = await _produtos.listar(
      empresaId: perfil.empresaId,
      filtro: filtro,
      tamanho: 100,
    );
    return pagina.itens;
  }

  Future<String> _faltando(Perfil perfil) async {
    final itens = await _todos(perfil, FiltroEstoque.criticos);
    if (itens.isEmpty) return 'Boa notícia: nenhum produto está abaixo do estoque mínimo. ✅';
    final linhas = itens
        .take(15)
        .map((p) => '• ${p.nome}: ${p.quantidade} un. (mínimo ${p.estoqueMinimo})');
    return 'Há ${itens.length} produto(s) abaixo do estoque mínimo:\n${linhas.join('\n')}';
  }

  Future<String> _vencendo(Perfil perfil, String pergunta) async {
    final t = normalizar(pergunta);
    final dias = t.contains('mes') ? 30 : (t.contains('hoje') ? 0 : 7);
    final itens = (await _todos(perfil, FiltroEstoque.vencendo)).where((p) {
      final d = p.diasParaVencer();
      return d != null && d <= dias && p.quantidade > 0;
    }).toList();

    final periodo = dias == 0 ? 'hoje' : 'nos próximos $dias dias';
    if (itens.isEmpty) return 'Nenhum produto com estoque vence $periodo. ✅';
    final linhas = itens.take(15).map((p) {
      final d = p.diasParaVencer()!;
      final quando = d < 0 ? 'VENCIDO há ${-d} dia(s)' : (d == 0 ? 'vence hoje' : 'vence em $d dia(s)');
      return '• ${p.nome} (${p.quantidade} un.): $quando';
    });
    return 'Produtos que vencem $periodo:\n${linhas.join('\n')}';
  }

  Future<String> _desconto(Perfil perfil) async {
    final tabela = perfil.empresa?.descontos ?? TabelaDescontos.padrao;
    final vencendo = await _todos(perfil, FiltroEstoque.vencendo);
    final sugeridos = vencendo.where((p) => p.descontoSugerido(tabela: tabela) != null).toList();
    final emPromocao = vencendo.where((p) => p.emPromocao).toList();
    if (sugeridos.isEmpty && emPromocao.isEmpty) {
      return 'Nenhum produto com menos de 7 dias para vencer. Não há descontos a sugerir agora.';
    }
    final partes = <String>[];
    if (sugeridos.isNotEmpty) {
      final linhas = sugeridos.take(15).map((p) {
        final desconto = p.descontoSugerido(tabela: tabela)!;
        return '• ${p.nome}: $desconto% off → ${Formatters.currency(p.precoComDesconto(desconto))} '
            '(vence em ${p.diasParaVencer()} dia(s))';
      });
      partes.add('Sugestão de descontos para girar o estoque:\n${linhas.join('\n')}');
    }
    if (emPromocao.isNotEmpty) {
      final linhas = emPromocao.take(10).map(
        (p) => '• ${p.nome}: -${p.promocaoPercentual}% (${Formatters.currency(p.precoVenda)})',
      );
      partes.add('Já em promoção:\n${linhas.join('\n')}');
    }
    return partes.join('\n\n');
  }

  Future<String> _resumo(Perfil perfil) async {
    if (!perfil.pode(Modulo.vendas)) {
      return 'Seu perfil (${perfil.cargo.label}) não tem acesso ao módulo de vendas.';
    }
    final r = await _dashboard.resumo();
    final quem = perfil.pode(Modulo.vendasTodas) ? 'da loja' : 'suas';
    final variacao = r.variacaoFaturamento;
    final comparativo = variacao == null
        ? ''
        : '\nEm relação a ontem: ${Formatters.percent(variacao)}.';
    final ticket = r.vendasHoje == 0 ? 0 : r.faturamentoHoje / r.vendasHoje;
    return 'Resumo de vendas $quem hoje:\n'
        '• Faturamento: ${Formatters.currency(r.faturamentoHoje)}\n'
        '• Vendas: ${r.vendasHoje}\n'
        '• Ticket médio: ${Formatters.currency(ticket)}$comparativo';
  }

  Future<String> _compras(Perfil perfil) async {
    final giro = await _dashboard.giro();
    final sugestoes = giro
        .where((g) => g.sugestaoCompra > 0 && (g.quantidade <= g.estoqueMinimo || (g.diasCobertura ?? 999) < 15))
        .take(10)
        .toList();
    if (sugestoes.isEmpty) {
      return 'Pelo ritmo de vendas dos últimos 30 dias, o estoque está bem abastecido. '
          'Nenhuma compra urgente.';
    }
    final linhas = sugestoes.map((g) {
      final cobertura = g.diasCobertura == null ? '' : ', dura ~${g.diasCobertura!.toStringAsFixed(0)} dia(s)';
      return '• ${g.nome}: comprar ${g.sugestaoCompra} un. (tem ${g.quantidade}$cobertura)';
    });
    return 'Recomendações de compra (giro dos últimos 30 dias):\n${linhas.join('\n')}';
  }

  Future<String> _consulta(Perfil perfil, String pergunta) async {
    final t = normalizar(pergunta);
    final termo = t
        .replaceAll(RegExp(r'(quanto|quantos|tem|de|do|da|no|estoque|saldo|\?)'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (termo.length < 2) return 'Qual produto você quer consultar? Ex.: "quanto tem de arroz?"';
    final pagina = await _produtos.listar(empresaId: perfil.empresaId, busca: termo, tamanho: 5);
    if (pagina.itens.isEmpty) return 'Não encontrei produtos com "$termo".';
    final linhas = pagina.itens.map(
      (p) => '• ${p.nome}: ${p.quantidade} un. (${p.status.label}) - ${Formatters.currency(p.preco)}',
    );
    return linhas.join('\n');
  }

  String _ajuda() =>
      'Posso ajudar com o estoque e as vendas. Experimente perguntar:\n'
      '${sugestoes.map((s) => '• $s').join('\n')}\n'
      '• Quanto tem de arroz?';
}
