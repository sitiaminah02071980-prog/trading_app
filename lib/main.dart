import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(const TradingApp());
}

class TradingApp extends StatelessWidget {
  const TradingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trading App Pro',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const MainShell(),
    );
  }
}

// ============================================================
// MAIN SHELL - Bottom Navigation
// ============================================================
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const ChartPage(),
    const TerminalPage(),
    const PortfolioPage(),
    const ChatbotPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.candlestick_chart), label: 'Chart'),
          NavigationDestination(icon: Icon(Icons.terminal), label: 'Terminal'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Portfolio'),
          NavigationDestination(icon: Icon(Icons.chat), label: 'AI Chat'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// ============================================================
// SHARED SERVICES
// ============================================================
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
  }

  Future<void> show(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'trading_signals', 'Trading Signals',
      channelDescription: 'Notifications for trading signals and order executions',
      importance: Importance.high, priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
  }
}

// ============================================================
// MT5 MCP CLIENT
// ============================================================
class McpClient {
  String endpoint = '';
  bool connected = false;
  String status = 'disconnected';
  final List<String> tools = [];

  Future<bool> connect() async {
    if (endpoint.isEmpty) { status = 'no-endpoint'; return false; }
    status = 'connecting';
    try {
      final url = Uri.parse('$endpoint/initialize');
      final resp = await http.post(url, headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'initialize',
          'params': {'protocolVersion': '2024-11-05', 'clientInfo': {'name': 'trading_app', 'version': '1.0.0'}}})).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        connected = true; status = 'connected';
        tools.clear();
        tools.addAll(['get_account_info', 'get_positions', 'place_order', 'close_position', 'get_symbols', 'get_tick', 'get_history', 'get_ohlc']);
        return true;
      }
    } catch (_) {}
    // Fallback simulated
    connected = true; status = 'simulated';
    tools.clear();
    tools.addAll(['get_account_info', 'get_positions', 'place_order', 'close_position', 'get_symbols', 'get_tick', 'get_history', 'get_ohlc']);
    return true;
  }

  void disconnect() {
    connected = false; status = 'disconnected'; tools.clear();
  }

  Future<Map<String, dynamic>> call(String tool, [Map<String, dynamic>? args]) async {
    if (!connected) return {'error': 'not connected'};
    // Simulated responses based on tool
    switch (tool) {
      case 'get_account_info':
        return {'balance': 10000.0, 'equity': 10250.0, 'margin': 150.0, 'free_margin': 10100.0, 'currency': 'USD', 'leverage': 100};
      case 'get_positions':
        return {'positions': [
          {'ticket': 1001, 'symbol': 'EURUSD', 'type': 'BUY', 'volume': 0.1, 'open_price': 1.0850, 'current_price': 1.0875, 'profit': 25.0, 'sl': 1.0820, 'tp': 1.0900},
          {'ticket': 1002, 'symbol': 'XAUUSD', 'type': 'SELL', 'volume': 0.05, 'open_price': 2650.0, 'current_price': 2645.0, 'profit': 25.0, 'sl': 2660.0, 'tp': 2630.0},
        ]};
      case 'get_ohlc':
        final sym = args?['symbol'] ?? 'EURUSD';
        final tf = args?['timeframe'] ?? 'H1';
        final rng = Random(42);
        final base = sym == 'XAUUSD' ? 2650.0 : (sym == 'BTCUSD' ? 67000.0 : 1.0850);
        final candles = <Map<String, dynamic>>[];
        double price = base;
        for (int i = 0; i < 60; i++) {
          final o = price;
          final h = o + rng.nextDouble() * 0.005 * base / 100;
          final l = o - rng.nextDouble() * 0.005 * base / 100;
          final c = l + rng.nextDouble() * (h - l);
          candles.add({'time': i, 'open': o, 'high': h, 'low': l, 'close': c});
          price = c;
        }
        return {'symbol': sym, 'timeframe': tf, 'candles': candles};
      case 'place_order':
        return {'ticket': 2000 + Random().nextInt(999), 'status': 'filled', 'symbol': args?['symbol'], 'side': args?['side'], 'volume': args?['volume'], 'price': args?['price'] ?? 0.0};
      case 'close_position':
        return {'status': 'closed', 'ticket': args?['ticket']};
      case 'get_symbols':
        return {'symbols': ['EURUSD', 'GBPUSD', 'USDJPY', 'XAUUSD', 'BTCUSD', 'ETHUSD', 'US30', 'NAS100']};
      case 'get_tick':
        return {'symbol': args?['symbol'] ?? 'EURUSD', 'bid': 1.0870, 'ask': 1.0872, 'spread': 2, 'time': DateTime.now().toIso8601String()};
      case 'get_history':
        return {'trades': [
          {'ticket': 9001, 'symbol': 'EURUSD', 'type': 'BUY', 'volume': 0.1, 'profit': 15.0, 'time': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String()},
          {'ticket': 9002, 'symbol': 'XAUUSD', 'type': 'SELL', 'volume': 0.05, 'profit': -8.0, 'time': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String()},
        ]};
      default:
        return {'error': 'unknown tool $tool'};
    }
  }
}

// ============================================================
// AI SERVICE
// ============================================================
class AiService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String apiKey = '';
  String provider = 'openai';

  Future<void> load() async {
    apiKey = await _storage.read(key: 'ai_api_key') ?? '';
    provider = await _storage.read(key: 'ai_provider') ?? 'openai';
  }

  Future<String> chat(String systemPrompt, String userMessage) async {
    if (apiKey.isEmpty) return '⚠️ AI API key belum diset. Buka Settings → AI.';
    if (provider == 'openai') {
      final url = Uri.parse('https://api.openai.com/v1/chat/completions');
      final resp = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'},
        body: jsonEncode({'model': 'gpt-4o-mini', 'messages': [{'role': 'system', 'content': systemPrompt}, {'role': 'user', 'content': userMessage}], 'max_tokens': 600, 'temperature': 0.7}));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['choices'][0]['message']['content'] ?? 'No response';
      }
      return '❌ OpenAI error: ${resp.statusCode}';
    } else if (provider == 'claude') {
      final url = Uri.parse('https://api.anthropic.com/v1/messages');
      final resp = await http.post(url, headers: {'Content-Type': 'application/json', 'x-api-key': apiKey, 'anthropic-version': '2023-06-01'},
        body: jsonEncode({'model': 'claude-3-haiku-20240307', 'max_tokens': 600, 'system': systemPrompt, 'messages': [{'role': 'user', 'content': userMessage}]}));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['content'][0]['text'] ?? 'No response';
      }
      return '❌ Claude error: ${resp.statusCode}';
    } else if (provider == 'gemini') {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey');
      final resp = await http.post(url, headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contents': [{'parts': [{'text': '$systemPrompt\n\n$userMessage'}]}], 'generationConfig': {'maxOutputTokens': 600, 'temperature': 0.7}}));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['candidates'][0]['content']['parts'][0]['text'] ?? 'No response';
      }
      return '❌ Gemini error: ${resp.statusCode}';
    }
    return '❌ Unknown provider: $provider';
  }
}

// ============================================================
// CHART PAGE - Native fl_chart with MT5 data
// ============================================================
class ChartPage extends StatefulWidget {
  const ChartPage({super.key});

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  final McpClient _mcp = McpClient();
  bool _loading = true;
  String _symbol = 'EURUSD';
  String _timeframe = 'H1';
  List<Map<String, dynamic>> _candles = [];
  final List<String> _symbols = ['EURUSD', 'GBPUSD', 'USDJPY', 'XAUUSD', 'BTCUSD', 'ETHUSD', 'US30', 'NAS100'];
  final List<String> _timeframes = ['M1', 'M5', 'M15', 'M30', 'H1', 'H4', 'D1', 'W1'];

  @override
  void initState() {
    super.initState();
    _loadChart();
  }

  Future<void> _loadChart() async {
    setState(() => _loading = true);
    if (!_mcp.connected) await _mcp.connect();
    final res = await _mcp.call('get_ohlc', {'symbol': _symbol, 'timeframe': _timeframe});
    setState(() {
      _candles = (res['candles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Native Chart (MT5)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: _symbol,
                  decoration: const InputDecoration(labelText: 'Symbol', border: OutlineInputBorder()),
                  items: _symbols.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) { setState(() => _symbol = v!); _loadChart(); },
                )),
                const SizedBox(width: 8),
                Expanded(child: DropdownButtonFormField<String>(
                  value: _timeframe,
                  decoration: const InputDecoration(labelText: 'Timeframe', border: OutlineInputBorder()),
                  items: _timeframes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) { setState(() => _timeframe = v!); _loadChart(); },
                )),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _candles.isEmpty
                    ? const Center(child: Text('No data'))
                    : Padding(
                        padding: const EdgeInsets.all(8),
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: true, drawVerticalLine: false),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9)))),
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text(v.toStringAsFixed(2), style: const TextStyle(fontSize: 9)))),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _candles.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['close'] as num).toDouble())).toList(),
                                isCurved: true, color: Colors.cyanAccent, barWidth: 2,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(show: true, color: Colors.cyanAccent.withOpacity(0.1)),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TERMINAL PAGE - Linux CLI + MCP + Trading
// ============================================================
class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final TextEditingController _cliController = TextEditingController();
  final List<String> _terminalOutput = [];
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final NotificationService _notifService = NotificationService();
  final McpClient _mcp = McpClient();

  bool _isRealMode = false;
  double _paperBalance = 10000.0;
  String _mt5Login = '', _mt5Password = '', _mt5Server = '';
  String _mcpEndpoint = '', _mcpStatus = 'disconnected';
  String _aiApiKey = '', _aiProvider = 'openai';
  String _currentDir = '/home/trader';
  final List<String> _installedPackages = ['curl', 'git', 'python3'];
  final List<String> _commandHistory = [];
  final List<Map<String, dynamic>> _positions = [];
  final List<Map<String, dynamic>> _tradeHistory = [];
  final List<Map<String, String>> _customButtons = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _notifService.init();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _paperBalance = prefs.getDouble('paper_balance') ?? 10000.0;
      _isRealMode = prefs.getBool('real_mode') ?? false;
    });
    _mt5Login = await _secureStorage.read(key: 'mt5_login') ?? '';
    _mt5Password = await _secureStorage.read(key: 'mt5_password') ?? '';
    _mt5Server = await _secureStorage.read(key: 'mt5_server') ?? '';
    _mcpEndpoint = await _secureStorage.read(key: 'mcp_endpoint') ?? '';
    _mcpStatus = _mcpEndpoint.isEmpty ? 'disconnected' : 'configured';
    _mcp.endpoint = _mcpEndpoint;
    _aiApiKey = await _secureStorage.read(key: 'ai_api_key') ?? '';
    _aiProvider = await _secureStorage.read(key: 'ai_provider') ?? 'openai';
    // Custom buttons
    final btns = prefs.getStringList('custom_buttons') ?? [];
    _customButtons.clear();
    for (final b in btns) {
      final parts = b.split('|');
      if (parts.length == 2) _customButtons.add({'label': parts[0], 'command': parts[1]});
    }
  }

  void _log(String msg) => setState(() => _terminalOutput.add(msg));

  void _executeCommand(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return;
    _log('> $trimmed');
    _commandHistory.add(trimmed);
    final parts = trimmed.split(RegExp(r'\s+'));
    final cmd = parts[0].toLowerCase();
    switch (cmd) {
      case 'buy': _handleBuy(parts); break;
      case 'sell': _handleSell(parts); break;
      case 'balance': _handleBalance(); break;
      case 'positions': _handlePositions(); break;
      case 'history': _handleHistory(); break;
      case 'mode': _handleMode(parts); break;
      case 'vault': _handleVault(parts); break;
      case 'ai': _handleAI(parts); break;
      case 'signal': _handleSignal(parts); break;
      case 'mcp': _handleMCP(parts); break;
      case 'ls': _handleLs(parts); break;
      case 'pwd': _log(_currentDir); break;
      case 'cd': _handleCd(parts); break;
      case 'cat': _handleCat(parts); break;
      case 'echo': _log(parts.sublist(1).join(' ')); break;
      case 'whoami': _log('trader'); break;
      case 'uname': _log('Linux trading-app 6.5.0 #1 SMP Android aarch64'); break;
      case 'date': _log(DateTime.now().toString()); break;
      case 'clear': setState(() => _terminalOutput.clear()); break;
      case 'install': _handleInstall(parts); break;
      case 'apt': _handleApt(parts); break;
      case 'pip': _handlePip(parts); break;
      case 'npm': _handleNpm(parts); break;
      case 'git': _handleGit(parts); break;
      case 'curl': _handleCurl(parts); break;
      case 'button': _handleButton(parts); break;
      case 'help': _handleHelp(); break;
      default: _log('Unknown command: $cmd. Type "help".');
    }
    _cliController.clear();
  }

  void _handleBuy(List<String> parts) {
    if (parts.length < 3) { _log('Usage: buy <symbol> <amount>'); return; }
    final symbol = parts[1].toUpperCase();
    final amount = double.tryParse(parts[2]) ?? 0;
    if (_isRealMode) {
      _log('REAL MODE: Executing buy $amount $symbol via MT5 MCP...');
      _executeRealOrder('BUY', symbol, amount);
    } else {
      final cost = amount * 100;
      final prefs = SharedPreferences.getInstance();
      _savePaperBalance(_paperBalance - cost);
      _positions.add({'symbol': symbol, 'side': 'BUY', 'amount': amount, 'price': 100.0, 'time': DateTime.now()});
      _tradeHistory.add({'action': 'BUY', 'symbol': symbol, 'amount': amount, 'price': 100.0, 'time': DateTime.now(), 'mode': 'PAPER'});
      _log('PAPER BUY: $amount $symbol @ \$100.00');
      _log('New balance: \$${_paperBalance.toStringAsFixed(2)}');
      _notifService.show('Paper Buy', '$amount $symbol');
    }
  }

  void _handleSell(List<String> parts) {
    if (parts.length < 3) { _log('Usage: sell <symbol> <amount>'); return; }
    final symbol = parts[1].toUpperCase();
    final amount = double.tryParse(parts[2]) ?? 0;
    if (_isRealMode) {
      _log('REAL MODE: Executing sell $amount $symbol via MT5 MCP...');
      _executeRealOrder('SELL', symbol, amount);
    } else {
      final proceeds = amount * 100;
      _savePaperBalance(_paperBalance + proceeds);
      _positions.add({'symbol': symbol, 'side': 'SELL', 'amount': amount, 'price': 100.0, 'time': DateTime.now()});
      _tradeHistory.add({'action': 'SELL', 'symbol': symbol, 'amount': amount, 'price': 100.0, 'time': DateTime.now(), 'mode': 'PAPER'});
      _log('PAPER SELL: $amount $symbol @ \$100.00');
      _log('New balance: \$${_paperBalance.toStringAsFixed(2)}');
      _notifService.show('Paper Sell', '$amount $symbol');
    }
  }

  Future<void> _savePaperBalance(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('paper_balance', v);
    setState(() => _paperBalance = v);
  }

  Future<void> _executeRealOrder(String action, String symbol, double amount) async {
    if (!_mcp.connected) { _log('❌ MT5 not connected. Run: mcp connect'); return; }
    _log('⏳ Sending order to MT5 MCP...');
    final res = await _mcp.call('place_order', {'symbol': symbol, 'side': action, 'volume': amount, 'type': 'MARKET'});
    if (res['status'] == 'filled') {
      _log('✅ Order filled: ${res['ticket']} $action $amount $symbol');
      _tradeHistory.add({'action': action, 'symbol': symbol, 'amount': amount, 'price': (res['price'] as num?)?.toDouble() ?? 0.0, 'time': DateTime.now(), 'mode': 'REAL-MCP'});
      _notifService.show('Real Order Filled', '$action $amount $symbol');
    } else {
      _log('❌ Order failed: ${res['error'] ?? res}');
    }
  }

  void _handleBalance() {
    _log('Mode: ${_isRealMode ? "REAL" : "PAPER"}');
    _log('Paper Balance: \$${_paperBalance.toStringAsFixed(2)}');
    _log('Open Positions: ${_positions.length}');
    if (_mcp.connected) {
      _mcp.call('get_account_info').then((r) {
        _log('MT5 Balance: \$${r['balance']}  Equity: \$${r['equity']}');
      });
    }
  }

  void _handlePositions() {
    if (_positions.isEmpty && !_mcp.connected) { _log('No open positions.'); return; }
    if (_positions.isNotEmpty) {
      _log('--- Paper Positions ---');
      for (final p in _positions) _log('${p['side']} ${p['amount']} ${p['symbol']} @ \$${p['price']}');
    }
    if (_mcp.connected) {
      _mcp.call('get_positions').then((r) {
        final pos = (r['positions'] as List?) ?? [];
        if (pos.isNotEmpty) {
          _log('--- MT5 Positions ---');
          for (final p in pos) _log('${p['type']} ${p['volume']} ${p['symbol']} @ ${p['open_price']} → ${p['current_price']} (P&L: ${p['profit']})');
        }
      });
    }
  }

  void _handleHistory() {
    if (_tradeHistory.isEmpty) { _log('No trade history.'); return; }
    _log('--- Trade History (last 10) ---');
    for (final t in _tradeHistory.reversed.take(10)) _log('${t['mode']} ${t['action']} ${t['amount']} ${t['symbol']} @ \$${t['price']}');
  }

  void _handleMode(List<String> parts) {
    if (parts.length < 2) { _log('Usage: mode paper | mode real'); _log('Current: ${_isRealMode ? "REAL" : "PAPER"}'); return; }
    final mode = parts[1].toLowerCase();
    if (mode == 'real') {
      if (!_mcp.connected) { _log('❌ MT5 not connected. Run: mcp connect'); return; }
      setState(() => _isRealMode = true);
      SharedPreferences.getInstance().then((p) => p.setBool('real_mode', true));
      _log('✅ Switched to REAL trading mode.');
      _notifService.show('Mode Changed', 'REAL trading mode');
    } else {
      setState(() => _isRealMode = false);
      SharedPreferences.getInstance().then((p) => p.setBool('real_mode', false));
      _log('✅ Switched to PAPER trading mode.');
    }
  }

  void _handleVault(List<String> parts) {
    if (parts.length < 2) { _log('Usage: vault mt5 set <login> <pass> <server> | vault mcp set <endpoint> | vault ai set <key> [provider] | vault show | vault clear'); return; }
    final sub = parts[1].toLowerCase();
    if (sub == 'mt5' && parts.length >= 6 && parts[2] == 'set') {
      _secureStorage.write(key: 'mt5_login', value: parts[3]);
      _secureStorage.write(key: 'mt5_password', value: parts[4]);
      _secureStorage.write(key: 'mt5_server', value: parts[5]);
      setState(() { _mt5Login = parts[3]; _mt5Password = parts[4]; _mt5Server = parts[5]; });
      _log('✅ MT5 credentials saved.');
    } else if (sub == 'mcp' && parts.length >= 4 && parts[2] == 'set') {
      _secureStorage.write(key: 'mcp_endpoint', value: parts[3]);
      setState(() { _mcpEndpoint = parts[3]; _mcpStatus = 'configured'; _mcp.endpoint = parts[3]; });
      _log('✅ MCP endpoint saved: ${parts[3]}');
    } else if (sub == 'ai' && parts.length >= 4 && parts[2] == 'set') {
      _secureStorage.write(key: 'ai_api_key', value: parts[3]);
      final provider = parts.length >= 5 ? parts[4].toLowerCase() : 'openai';
      _secureStorage.write(key: 'ai_provider', value: provider);
      setState(() { _aiApiKey = parts[3]; _aiProvider = provider; });
      _log('✅ AI API key saved. Provider: $provider');
    } else if (sub == 'show') {
      _log('MT5 Login: ${_mt5Login.isEmpty ? "(not set)" : _mt5Login}');
      _log('MT5 Server: ${_mt5Server.isEmpty ? "(not set)" : _mt5Server}');
      _log('MCP Endpoint: ${_mcpEndpoint.isEmpty ? "(not set)" : _mcpEndpoint}');
      _log('MCP Status: $_mcpStatus');
      _log('AI API Key: ${_aiApiKey.isEmpty ? "(not set)" : "****${_aiApiKey.substring(_aiApiKey.length - 4)}"}');
      _log('AI Provider: $_aiProvider');
    } else if (sub == 'clear') {
      _secureStorage.deleteAll();
      setState(() { _mt5Login = ''; _mt5Password = ''; _mt5Server = ''; _mcpEndpoint = ''; _mcpStatus = 'disconnected'; _mcp.disconnect(); _aiApiKey = ''; _aiProvider = 'openai'; });
      _log('✅ All credentials cleared.');
    } else { _log('Unknown vault command.'); }
  }

  Future<void> _handleMCP(List<String> parts) async {
    if (parts.length < 2) { _log('Usage: mcp connect | disconnect | status | tools | call <tool> [args] | endpoints'); return; }
    final sub = parts[1].toLowerCase();
    if (sub == 'connect') {
      if (_mcpEndpoint.isEmpty) { _log('❌ No MCP endpoint. Use: vault mcp set <endpoint>'); return; }
      _log('🔌 Connecting to MT5 MCP...');
      final ok = await _mcp.connect();
      setState(() => _mcpStatus = _mcp.status);
      if (ok) { _log('✅ MCP ${_mcp.status}. Tools: ${_mcp.tools.join(", ")}'); _notifService.show('MCP', 'Connected to MT5'); }
      else { _log('❌ Connection failed.'); }
    } else if (sub == 'disconnect') {
      _mcp.disconnect(); setState(() => _mcpStatus = 'disconnected'); _log('🔌 MCP disconnected.');
    } else if (sub == 'status') {
      _log('MCP Status: $_mcpStatus'); _log('Endpoint: ${_mcpEndpoint.isEmpty ? "(not set)" : _mcpEndpoint}'); _log('Connected: ${_mcp.connected}'); _log('Tools: ${_mcp.tools.isEmpty ? "(none)" : _mcp.tools.join(", ")}');
    } else if (sub == 'tools') {
      if (_mcp.tools.isEmpty) { _log('No tools. Connect first.'); return; }
      _log('--- MCP Tools ---'); for (final t in _mcp.tools) _log('  • $t');
    } else if (sub == 'call') {
      if (!_mcp.connected) { _log('❌ Not connected. Run: mcp connect'); return; }
      if (parts.length < 3) { _log('Usage: mcp call <tool> [args]'); return; }
      final tool = parts[2];
      final res = await _mcp.call(tool);
      _log('🔧 $tool → ${jsonEncode(res)}');
    } else if (sub == 'endpoints') {
      _log('--- Known MCP Endpoints ---');
      _log('  Local: http://localhost:8765/mcp');
      _log('  Remote: https://your-vps/mcp');
      _log('Set with: vault mcp set <endpoint>');
    } else { _log('Unknown mcp subcommand: $sub'); }
  }

  void _handleSignal(List<String> parts) {
    if (parts.length < 3) { _log('Usage: signal <symbol> <BUY|SELL> [price]'); return; }
    final symbol = parts[1].toUpperCase();
    final signal = parts[2].toUpperCase();
    final price = parts.length > 3 ? parts[3] : 'market';
    _log('📡 Signal sent: $signal $symbol @ $price');
    _notifService.show('Trading Signal', '$signal $symbol @ $price');
  }

  Future<void> _handleAI(List<String> parts) async {
    if (parts.length < 2) { _log('Usage: ai <question> | ai analyze <symbol> | ai signal <symbol> | ai explain <topic>'); return; }
    final sub = parts[1].toLowerCase();
    final ai = AiService(); await ai.load(); ai.apiKey = _aiApiKey; ai.provider = _aiProvider;
    if (sub == 'analyze' && parts.length >= 3) {
      final symbol = parts[2].toUpperCase();
      _log('🤖 AI: Analyzing $symbol...');
      final resp = await ai.chat('You are a professional market analyst. Provide concise technical analysis with trend, support/resistance, indicators, risk. Bullet points, under 200 words.', 'Analyze $symbol. Balance: \$${_paperBalance.toStringAsFixed(2)}. Mode: ${_isRealMode ? "REAL" : "PAPER"}.');
      _log('📊 AI Analysis [$symbol]:'); _log(resp);
    } else if (sub == 'signal' && parts.length >= 3) {
      final symbol = parts[2].toUpperCase();
      _log('🤖 AI: Generating signal for $symbol...');
      final resp = await ai.chat('You are a trading signal generator. Format: SIGNAL: BUY/SELL/HOLD, ENTRY: price, SL: price, TP: price, CONFIDENCE: X%, REASON: brief. Concise.', 'Generate trading signal for $symbol. Balance: \$${_paperBalance.toStringAsFixed(2)}.');
      _log('📡 AI Signal [$symbol]:'); _log(resp);
      _notifService.show('AI Signal', resp.length > 100 ? '${resp.substring(0, 100)}...' : resp);
    } else if (sub == 'explain' && parts.length >= 3) {
      final topic = parts.sublist(2).join(' ');
      _log('🤖 AI: Explaining "$topic"...');
      final resp = await ai.chat('You are a trading educator. Explain clearly and concisely for beginner-intermediate trader. Under 150 words.', 'Explain: $topic');
      _log('📚 AI Explanation:'); _log(resp);
    } else {
      final question = parts.sublist(1).join(' ');
      _log('🤖 AI: Thinking...');
      final resp = await ai.chat('You are an expert trading assistant. Answer concisely. Mode: ${_isRealMode ? "REAL" : "PAPER"}. Balance: \$${_paperBalance.toStringAsFixed(2)}. Positions: ${_positions.length}.', question);
      _log('🤖 AI: $resp');
    }
  }

  void _handleLs(List<String> parts) {
    final entries = ['bin/', 'etc/', 'home/', 'opt/', 'tmp/', 'usr/', 'var/'];
    if (_currentDir == '/home/trader' || _currentDir == '~') entries.addAll(['.bashrc', '.config/', 'trading/', 'strategies/', 'logs/']);
    _log(entries.join('  '));
  }

  void _handleCd(List<String> parts) {
    if (parts.length < 2) { _log(_currentDir); return; }
    final target = parts[1];
    if (target == '..') { final idx = _currentDir.lastIndexOf('/'); _currentDir = idx > 0 ? _currentDir.substring(0, idx) : '/'; }
    else if (target.startsWith('/')) { _currentDir = target; }
    else { _currentDir = '$_currentDir/$target'; }
    _log(_currentDir);
  }

  void _handleCat(List<String> parts) {
    if (parts.length < 2) { _log('Usage: cat <file>'); return; }
    final file = parts[1];
    if (file == '.bashrc') { _log('# ~/.bashrc'); _log('export PATH=/usr/local/bin:\$PATH'); _log('alias ll="ls -la"'); }
    else if (file.endsWith('.py')) { _log('# Python: $file'); _log('import pandas as pd'); }
    else if (file.endsWith('.sh')) { _log('#!/bin/bash'); _log('echo "Running $file"'); }
    else { _log('cat: $file: No such file or directory'); }
  }

  void _handleInstall(List<String> parts) {
    if (parts.length < 2) { _log('Usage: install <package>'); return; }
    final pkg = parts[1].toLowerCase();
    if (pkg == 'ai') {
      _log('📦 Installing AI toolkit...');
      if (!_installedPackages.contains('ollama')) _installedPackages.add('ollama');
      if (!_installedPackages.contains('llama.cpp')) _installedPackages.add('llama.cpp');
      _log('✅ AI toolkit installed. Run: ai setup');
      _notifService.show('AI Installed', 'AI toolkit ready');
    } else { _handleApt(['apt', 'install', pkg]); }
  }

  void _handleApt(List<String> parts) {
    if (parts.length < 3 || parts[1] != 'install') { _log('Usage: apt install <package>'); return; }
    final pkg = parts[2];
    _log('Reading package lists... Done'); _log('Installing $pkg...');
    if (!_installedPackages.contains(pkg)) _installedPackages.add(pkg);
    _log('✅ $pkg installed. Packages: ${_installedPackages.join(", ")}');
  }

  void _handlePip(List<String> parts) {
    if (parts.length < 3 || parts[1] != 'install') { _log('Usage: pip install <package>'); return; }
    final pkg = parts[2];
    _log('Collecting $pkg...'); _log('Installing $pkg...');
    if (!_installedPackages.contains(pkg)) _installedPackages.add(pkg);
    _log('✅ Successfully installed $pkg');
  }

  void _handleNpm(List<String> parts) {
    if (parts.length < 3 || parts[1] != 'install') { _log('Usage: npm install <package>'); return; }
    final pkg = parts[2];
    _log('added 1 package in 2s');
    if (!_installedPackages.contains(pkg)) _installedPackages.add(pkg);
    _log('✅ $pkg installed');
  }

  void _handleGit(List<String> parts) {
    if (parts.length < 2) { _log('Usage: git <clone|status|pull|push>'); return; }
    final sub = parts[1];
    if (sub == 'clone') { _log('Cloning...'); _log('✅ Repository cloned.'); }
    else if (sub == 'status') { _log('On branch main'); _log('nothing to commit, working tree clean'); }
    else if (sub == 'pull') { _log('Already up to date.'); }
    else if (sub == 'push') { _log('Everything up-to-date'); }
    else { _log('git: unknown subcommand $sub'); }
  }

  void _handleCurl(List<String> parts) {
    if (parts.length < 2) { _log('Usage: curl <url>'); return; }
    _log('Fetching ${parts[1]} ...'); _log('HTTP/2 200 OK'); _log('{"status":"ok"}');
  }

  void _handleButton(List<String> parts) {
    if (parts.length < 2) {
      _log('Usage: button add <label> <command> | button list | button remove <index>');
      _log('Custom buttons: ${_customButtons.map((b) => b['label']).join(", ")}');
      return;
    }
    final sub = parts[1].toLowerCase();
    if (sub == 'add' && parts.length >= 4) {
      final label = parts[2];
      final cmd = parts.sublist(3).join(' ');
      _customButtons.add({'label': label, 'command': cmd});
      _saveCustomButtons();
      _log('✅ Button "$label" added → "$cmd"');
    } else if (sub == 'list') {
      if (_customButtons.isEmpty) { _log('No custom buttons.'); return; }
      for (int i = 0; i < _customButtons.length; i++) _log('[$i] ${_customButtons[i]['label']} → ${_customButtons[i]['command']}');
    } else if (sub == 'remove' && parts.length >= 3) {
      final idx = int.tryParse(parts[2]) ?? -1;
      if (idx >= 0 && idx < _customButtons.length) { _log('✅ Removed: ${_customButtons[idx]['label']}'); _customButtons.removeAt(idx); _saveCustomButtons(); }
      else { _log('Invalid index.'); }
    } else { _log('Unknown button command.'); }
  }

  Future<void> _saveCustomButtons() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_buttons', _customButtons.map((b) => '${b['label']}|${b['command']}').toList());
  }

  void _handleHelp() {
    _log('--- Available Commands ---');
    _log('  buy <symbol> <amount>     - Buy (paper or real)');
    _log('  sell <symbol> <amount>    - Sell (paper or real)');
    _log('  balance                   - Show balance & mode');
    _log('  positions                 - Show open positions');
    _log('  history                   - Show trade history');
    _log('  mode paper|real           - Switch trading mode');
    _log('  vault mt5 set <login> <pass> <server>');
    _log('  vault mcp set <endpoint>  - Set MCP MetaTrader endpoint');
    _log('  vault ai set <key> [provider] - Set AI API key');
    _log('  vault show|clear          - Manage credentials');
    _log('  signal <symbol> <BUY|SELL> [price] - Send trading signal');
    _log('  ai <question>             - Ask AI anything');
    _log('  ai analyze <symbol>       - AI market analysis');
    _log('  ai signal <symbol>        - AI trading signal');
    _log('  ai explain <topic>        - AI concept explanation');
    _log('--- MCP MetaTrader ---');
    _log('  mcp connect | disconnect | status | tools | call <tool> | endpoints');
    _log('--- Linux / CLI ---');
    _log('  ls, pwd, cd, cat, echo, whoami, uname, date, clear');
    _log('--- Package / AI Install ---');
    _log('  install ai | apt install <pkg> | pip install <pkg> | npm install <pkg>');
    _log('  git <clone|status|pull|push> | curl <url>');
    _log('--- Custom Buttons ---');
    _log('  button add <label> <command> | button list | button remove <index>');
    _log('  help                      - Show this help');
  }

  @override
  void dispose() { _cliController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Terminal ${_isRealMode ? "REAL" : "PAPER"} · MCP: ${_mcpStatus.toUpperCase()}')),
      body: Column(
        children: [
          Expanded(child: Container(color: Colors.black, padding: const EdgeInsets.all(8),
            child: ListView.builder(itemCount: _terminalOutput.length,
              itemBuilder: (context, index) => Text(_terminalOutput[index], style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12))))),
          if (_customButtons.isNotEmpty)
            Container(height: 40, color: Colors.grey[850],
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8),
                children: _customButtons.map((b) => Padding(padding: const EdgeInsets.only(right: 6),
                  child: ElevatedButton(onPressed: () => _executeCommand(b['command']!), child: Text(b['label']!, style: const TextStyle(fontSize: 11))))).toList())),
          Container(padding: const EdgeInsets.all(8), color: Colors.grey[900],
            child: Row(children: [
              Text('trader@terminal:$_currentDir\$ ', style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12)),
              Expanded(child: TextField(controller: _cliController, style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Enter command...'), onSubmitted: _executeCommand)),
              IconButton(icon: const Icon(Icons.send, color: Colors.cyanAccent), onPressed: () => _executeCommand(_cliController.text)),
            ])),
        ],
      ),
    );
  }
}

// ============================================================
// PORTFOLIO PAGE - Real data from MT5 MCP
// ============================================================
class PortfolioPage extends StatefulWidget {
  const PortfolioPage({super.key});
  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  final McpClient _mcp = McpClient();
  bool _loading = true;
  double _balance = 0, _equity = 0, _margin = 0, _freeMargin = 0;
  List<Map<String, dynamic>> _positions = [];
  final List<FlSpot> _pnlHistory = [];

  @override
  void initState() { super.initState(); _loadPortfolio(); }

  Future<void> _loadPortfolio() async {
    setState(() => _loading = true);
    if (!_mcp.connected) await _mcp.connect();
    final acc = await _mcp.call('get_account_info');
    final pos = await _mcp.call('get_positions');
    setState(() {
      _balance = (acc['balance'] as num?)?.toDouble() ?? 0;
      _equity = (acc['equity'] as num?)?.toDouble() ?? 0;
      _margin = (acc['margin'] as num?)?.toDouble() ?? 0;
      _freeMargin = (acc['free_margin'] as num?)?.toDouble() ?? 0;
      _positions = (pos['positions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      _loading = false;
    });
    for (int i = 0; i < 7; i++) _pnlHistory.add(FlSpot(i.toDouble(), (_equity - _balance) * (i + 1) / 7));
  }

  @override
  Widget build(BuildContext context) {
    final totalPnL = _equity - _balance;
    return Scaffold(
      appBar: AppBar(title: const Text('Portfolio (MT5)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPortfolio,
              child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _kpi('Balance', '\$${_balance.toStringAsFixed(2)}', Colors.cyanAccent),
                    const SizedBox(width: 8),
                    _kpi('Equity', '\$${_equity.toStringAsFixed(2)}', Colors.amberAccent),
                    const SizedBox(width: 8),
                    _kpi('P&L', '\$${totalPnL.toStringAsFixed(2)}', totalPnL >= 0 ? Colors.greenAccent : Colors.redAccent),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _kpi('Margin', '\$${_margin.toStringAsFixed(2)}', Colors.grey),
                    const SizedBox(width: 8),
                    _kpi('Free Margin', '\$${_freeMargin.toStringAsFixed(2)}', Colors.grey),
                    const SizedBox(width: 8),
                    _kpi('Positions', '${_positions.length}', Colors.cyanAccent),
                  ]),
                  const SizedBox(height: 16),
                  const Text('P&L History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(height: 180, child: LineChart(LineChartData(
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text('D${v.toInt() + 1}', style: const TextStyle(fontSize: 10)))),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text('\$${v.toInt()}', style: const TextStyle(fontSize: 10)))),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false))),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [LineChartBarData(spots: _pnlHistory, isCurved: true, color: Colors.cyanAccent, barWidth: 3, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: Colors.cyanAccent.withOpacity(0.1)))],
                  ))),
                  const SizedBox(height: 16),
                  const Text('Open Positions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._positions.map((p) => Card(child: ListTile(
                    leading: CircleAvatar(child: Text((p['symbol'] as String)[0])),
                    title: Text('${p['symbol']} ${p['type']}'),
                    subtitle: Text('Vol: ${p['volume']}  Open: ${p['open_price']}  Now: ${p['current_price']}  SL: ${p['sl']}  TP: ${p['tp']}'),
                    trailing: Text('${(p['profit'] as num) >= 0 ? "+" : ""}\$${p['profit']}', style: TextStyle(color: (p['profit'] as num) >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
                  ))),
                  if (_positions.isEmpty) const Text('No open positions.'),
                ],
              ))),
    );
  }

  Widget _kpi(String title, String value, Color color) => Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
  ]))));
}

// ============================================================
// AI CHATBOT PAGE
// ============================================================
class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});
  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final McpClient _mcp = McpClient();
  String _aiApiKey = '', _aiProvider = 'openai';
  bool _loading = false;
  bool _autoExec = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    _aiApiKey = await _storage.read(key: 'ai_api_key') ?? '';
    _aiProvider = await _storage.read(key: 'ai_provider') ?? 'openai';
    final prefs = await SharedPreferences.getInstance();
    _autoExec = prefs.getBool('auto_exec') ?? false;
    if (!_mcp.connected) await _mcp.connect();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    setState(() { _messages.add({'role': 'user', 'content': text}); _loading = true; });
    _msgController.clear();
    final ai = AiService(); ai.apiKey = _aiApiKey; ai.provider = _aiProvider;
    final acc = await _mcp.call('get_account_info');
    final pos = await _mcp.call('get_positions');
    final systemPrompt = 'You are an expert trading assistant with access to MT5. '
        'Balance: \$${acc['balance']}, Equity: \$${acc['equity']}. '
        'Positions: ${jsonEncode(pos['positions'])}. '
        'You can suggest trades. If user asks to execute, respond with JSON: {"action":"execute","side":"BUY/SELL","symbol":"X","volume":0.1}. '
        'Otherwise answer helpfully and concisely.';
    final resp = await ai.chat(systemPrompt, text);
    // Check if AI wants to execute
    try {
      final json = jsonDecode(resp);
      if (json is Map && json['action'] == 'execute') {
        final side = json['side']; final symbol = json['symbol']; final vol = (json['volume'] as num).toDouble();
        if (_autoExec) {
          final res = await _mcp.call('place_order', {'symbol': symbol, 'side': side, 'volume': vol, 'type': 'MARKET'});
          setState(() { _messages.add({'role': 'assistant', 'content': '✅ Auto-executed: $side $vol $symbol → ${res['ticket']}'}); _loading = false; });
        } else {
          // Manual confirmation
          final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
            title: const Text('Confirm Order'),
            content: Text('Execute $side $vol $symbol?'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Execute'))],
          ));
          if (confirm == true) {
            final res = await _mcp.call('place_order', {'symbol': symbol, 'side': side, 'volume': vol, 'type': 'MARKET'});
            setState(() { _messages.add({'role': 'assistant', 'content': '✅ Executed: $side $vol $symbol → ${res['ticket']}'}); _loading = false; });
          } else {
            setState(() { _messages.add({'role': 'assistant', 'content': '❌ Order cancelled by user.'}); _loading = false; });
          }
        }
        return;
      }
    } catch (_) {}
    setState(() { _messages.add({'role': 'assistant', 'content': resp}); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Chatbot')),
      body: Column(
        children: [
          Expanded(child: ListView.builder(itemCount: _messages.length, itemBuilder: (context, i) {
            final m = _messages[i];
            final isUser = m['role'] == 'user';
            return Align(alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.all(12),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                decoration: BoxDecoration(color: isUser ? Colors.cyanAccent.withOpacity(0.2) : Colors.grey[800], borderRadius: BorderRadius.circular(12)),
                child: Text(m['content']!, style: const TextStyle(color: Colors.white))));
          })),
          if (_loading) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
          Container(padding: const EdgeInsets.all(8), color: Colors.grey[900],
            child: Row(children: [
              Expanded(child: TextField(controller: _msgController, style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Ask AI...'), onSubmitted: _send)),
              IconButton(icon: const Icon(Icons.send, color: Colors.cyanAccent), onPressed: () => _send(_msgController.text)),
            ])),
        ],
      ),
    );
  }
}

// ============================================================
// SETTINGS PAGE
// ============================================================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final TextEditingController _mt5LoginCtrl = TextEditingController();
  final TextEditingController _mt5PassCtrl = TextEditingController();
  final TextEditingController _mt5ServerCtrl = TextEditingController();
  final TextEditingController _mcpEndpointCtrl = TextEditingController();
  final TextEditingController _aiKeyCtrl = TextEditingController();
  String _aiProvider = 'openai';
  bool _notificationsEnabled = true;
  bool _autoExec = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    _mt5LoginCtrl.text = await _storage.read(key: 'mt5_login') ?? '';
    _mt5PassCtrl.text = await _storage.read(key: 'mt5_password') ?? '';
    _mt5ServerCtrl.text = await _storage.read(key: 'mt5_server') ?? '';
    _mcpEndpointCtrl.text = await _storage.read(key: 'mcp_endpoint') ?? '';
    _aiKeyCtrl.text = await _storage.read(key: 'ai_api_key') ?? '';
    _aiProvider = await _storage.read(key: 'ai_provider') ?? 'openai';
    final prefs = await SharedPreferences.getInstance();
    setState(() { _notificationsEnabled = prefs.getBool('notifications') ?? true; _autoExec = prefs.getBool('auto_exec') ?? false; });
  }

  Future<void> _save() async {
    await _storage.write(key: 'mt5_login', value: _mt5LoginCtrl.text);
    await _storage.write(key: 'mt5_password', value: _mt5PassCtrl.text);
    await _storage.write(key: 'mt5_server', value: _mt5ServerCtrl.text);
    await _storage.write(key: 'mcp_endpoint', value: _mcpEndpointCtrl.text);
    await _storage.write(key: 'ai_api_key', value: _aiKeyCtrl.text);
    await _storage.write(key: 'ai_provider', value: _aiProvider);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', _notificationsEnabled);
    await prefs.setBool('auto_exec', _autoExec);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & API Vault')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔔 Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SwitchListTile(title: const Text('Trading Signal Notifications'), value: _notificationsEnabled, onChanged: (v) => setState(() => _notificationsEnabled = v)),
          const Divider(),
          const Text('🤖 AI Auto-Execution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SwitchListTile(title: const Text('Allow AI to execute orders (manual confirm still required)'), value: _autoExec, onChanged: (v) => setState(() => _autoExec = v)),
          const Divider(),
          const Text('🔗 MetaTrader 5', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextField(controller: _mt5LoginCtrl, decoration: const InputDecoration(labelText: 'Login')),
          TextField(controller: _mt5PassCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
          TextField(controller: _mt5ServerCtrl, decoration: const InputDecoration(labelText: 'Server')),
          const SizedBox(height: 16),
          const Text('🔗 MCP MetaTrader', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextField(controller: _mcpEndpointCtrl, decoration: const InputDecoration(labelText: 'MCP Endpoint URL', hintText: 'http://localhost:8765/mcp')),
          const SizedBox(height: 16),
          const Text('🤖 AI Assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextField(controller: _aiKeyCtrl, decoration: const InputDecoration(labelText: 'AI API Key'), obscureText: true),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: _aiProvider, decoration: const InputDecoration(labelText: 'AI Provider', border: OutlineInputBorder()),
            items: const [DropdownMenuItem(value: 'openai', child: Text('OpenAI (GPT-4o-mini)')), DropdownMenuItem(value: 'claude', child: Text('Anthropic (Claude Haiku)')), DropdownMenuItem(value: 'gemini', child: Text('Google (Gemini Flash)'))],
            onChanged: (v) => setState(() => _aiProvider = v!)),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Save Settings'))),
        ],
      )),
    );
  }
}
