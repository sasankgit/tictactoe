import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const TicTacToeApp());
}

const _ink = Color(0xFF211747);
const _purple = Color(0xFF7357F5);
const _pink = Color(0xFFFF6B9A);
const _cyan = Color(0xFF54D8D1);

class TicTacToeApp extends StatelessWidget {
  const TicTacToeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Tic Tac Toe',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: _purple),
          fontFamily: 'Roboto',
        ),
        home: const _SplashScreen(),
      );
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  late final Timer _splashTimer;

  @override
  void initState() {
    super.initState();
    _splashTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const GamePage()),
      );
    });
  }

  @override
  void dispose() {
    _splashTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF0F6),
                Color(0xFFF0EEFF),
                Color(0xFFE6FBF7),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 76,
                  width: 76,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.grid_3x3_rounded,
                    color: _purple,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'TIC TAC TOE',
                  style: TextStyle(
                    color: _purple,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.4,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: _purple,
                    strokeWidth: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

enum GameMode { humanAi, humanHuman }

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final List<String?> _board = List.filled(9, null);
  GameMode _mode = GameMode.humanAi;
  String _turn = 'X';
  String? _winner;
  bool _draw = false;
  bool _thinking = false;
  Timer? _roundResetTimer;
  int _xScore = 0;
  int _oScore = 0;
  int _draws = 0;
  int _completedGamesSinceInterstitial = 0;
  BannerAd? _banner;
  bool _bannerReady = false;
  InterstitialAd? _interstitial;
  bool _showingInterstitial = false;

  static const _wins = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  @override
  void initState() {
    super.initState();
    _loadBanner();
    _loadInterstitial();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      // Google's test unit is used in debug builds to avoid invalid live-ad traffic.
      adUnitId: kDebugMode
          ? 'ca-app-pub-3940256099942544/1033173712'
          : 'ca-app-pub-7422399256358629/5003183610',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitial = null;
          debugPrint('Interstitial ad failed to load: $error');
        },
      ),
    );
  }

  void _showInterstitial({VoidCallback? onDismissed}) {
    final ad = _interstitial;
    if (ad == null || _showingInterstitial) {
      onDismissed?.call();
      return;
    }

    _interstitial = null;
    _showingInterstitial = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingInterstitial = false;
        _loadInterstitial();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _showingInterstitial = false;
        _loadInterstitial();
        debugPrint('Interstitial ad failed to show: $error');
        onDismissed?.call();
      },
    );
    ad.show();
  }

  void _loadBanner() {
    final ad = BannerAd(
      // Google's test unit is used in debug builds to avoid invalid live-ad traffic.
      adUnitId: kDebugMode
          ? 'ca-app-pub-3940256099942544/9214589741'
          : 'ca-app-pub-7422399256358629/2477625458',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _banner = ad as BannerAd;
            _bannerReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner ad failed to load: $error');
        },
      ),
    );
    ad.load();
  }

  @override
  void dispose() {
    _roundResetTimer?.cancel();
    _banner?.dispose();
    _interstitial?.dispose();
    super.dispose();
  }

  void _setMode(GameMode mode) {
    if (_mode == mode) return;
    _showInterstitial(onDismissed: () {
      if (!mounted) return;
      setState(() {
        _mode = mode;
        _resetBoard();
      });
    });
    // Mode change occurs after a shown ad is dismissed. If no ad is ready,
    // _showInterstitial invokes the callback immediately.
  }

  void _resetBoard() {
    _roundResetTimer?.cancel();
    _board.fillRange(0, 9, null);
    _turn = 'X';
    _winner = null;
    _draw = false;
    _thinking = false;
  }

  void _play(int index) {
    if (_board[index] != null || _winner != null || _draw || _thinking) return;
    setState(() {
      _board[index] = _turn;
      _finishOrAdvance();
      if (_winner == null &&
          !_draw &&
          _mode == GameMode.humanAi &&
          _turn == 'O') {
        _thinking = true;
      }
      _scheduleRoundResetIfFinished();
    });
    if (_thinking) {
      Future<void>.delayed(const Duration(milliseconds: 420), _playAi);
    }
  }

  void _playAi() {
    if (!mounted || _winner != null || _draw) return;
    final move = _bestMove();
    setState(() {
      if (move >= 0) _board[move] = 'O';
      _thinking = false;
      _finishOrAdvance();
      _scheduleRoundResetIfFinished();
    });
  }

  void _scheduleRoundResetIfFinished() {
    if (_winner == null && !_draw) return;
    _roundResetTimer?.cancel();
    _roundResetTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(_resetBoard);
    });
  }

  int _bestMove() {
    final open = <int>[];
    for (var i = 0; i < 9; i++) {
      if (_board[i] == null) open.add(i);
    }
    if (open.isEmpty) return -1;
    // Prefer a winning move, then a block, then the center/corners.
    for (final mark in ['O', 'X']) {
      for (final index in open) {
        _board[index] = mark;
        final wins = _hasWon(mark);
        _board[index] = null;
        if (wins) return index;
      }
    }
    if (open.contains(4)) return 4;
    final corners = open.where((i) => const [0, 2, 6, 8].contains(i)).toList();
    if (corners.isNotEmpty)
      return corners[math.Random().nextInt(corners.length)];
    return open.first;
  }

  bool _hasWon(String mark) =>
      _wins.any((line) => line.every((i) => _board[i] == mark));

  void _finishOrAdvance() {
    if (_hasWon(_turn)) {
      _winner = _turn;
      _recordCompletedGame();
      if (_turn == 'X') {
        _xScore++;
      } else {
        _oScore++;
      }
      return;
    }
    if (_board.every((cell) => cell != null)) {
      _draw = true;
      _draws++;
      _recordCompletedGame();
      return;
    }
    _turn = _turn == 'X' ? 'O' : 'X';
  }

  void _recordCompletedGame() {
    _completedGamesSinceInterstitial++;
    if (_completedGamesSinceInterstitial >= 5) {
      _completedGamesSinceInterstitial = 0;
      // Let the result render before presenting the full-screen ad.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showInterstitial();
      });
    }
  }

  String get _status {
    if (_winner != null) {
      if (_mode == GameMode.humanAi) {
        return _winner == 'O' ? 'Computer won!' : 'You won!';
      }
      return '${_winner == 'X' ? 'Player 1' : 'Player 2'} won!';
    }
    if (_draw) return 'It’s a draw!';
    if (_thinking) return 'Computer is thinking…';
    return _mode == GameMode.humanAi
        ? (_turn == 'X' ? 'Your turn' : 'Computer’s turn')
        : '${_turn == 'X' ? 'Player 1' : 'Player 2'}’s turn';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF0F6), Color(0xFFF0EEFF), Color(0xFFE6FBF7)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight - 34),
                      child: Column(
                        children: [
                          _topBar(),
                          const SizedBox(height: 22),
                          _title(),
                          const SizedBox(height: 24),
                          _modePicker(),
                          const SizedBox(height: 20),
                          _scoreCard(),
                          const SizedBox(height: 22),
                          _boardWidget(),
                          const SizedBox(height: 18),
                          _statusCard(),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              _bannerFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(.78), shape: BoxShape.circle),
            child: const Icon(Icons.grid_3x3_rounded, color: _purple),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => setState(() {
              _xScore = 0;
              _oScore = 0;
              _draws = 0;
              _resetBoard();
            }),
            icon: const Icon(Icons.refresh_rounded, size: 19),
            label: const Text('Reset scores'),
            style: TextButton.styleFrom(foregroundColor: _ink),
          ),
        ],
      );

  Widget _title() => Column(
        children: [
          const Text('TIC TAC TOE',
              style: TextStyle(
                  color: _purple,
                  fontSize: 12,
                  letterSpacing: 3.4,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          const Text('Ready to play?',
              style: TextStyle(
                  color: _ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.7)),
          const SizedBox(height: 5),
          Text('A little friendly competition goes a long way.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _ink.withOpacity(.6), fontSize: 13)),
        ],
      );

  Widget _modePicker() => Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(.7),
            borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          _modeButton(GameMode.humanAi, Icons.smart_toy_rounded, 'VS COMPUTER'),
          _modeButton(
              GameMode.humanHuman, Icons.people_alt_rounded, '2 PLAYERS'),
        ]),
      );

  Widget _modeButton(GameMode mode, IconData icon, String label) {
    final selected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: selected ? _purple : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: _purple.withOpacity(.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]
                  : null),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 17,
                color: selected ? Colors.white : _ink.withOpacity(.55)),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : _ink.withOpacity(.6),
                    fontSize: 10,
                    letterSpacing: .7,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }

  Widget _scoreCard() => Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(.82),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: _ink.withOpacity(.05),
                  blurRadius: 20,
                  offset: const Offset(0, 7))
            ]),
        child: Row(children: [
          _score('PLAYER 1', '$_xScore', _cyan),
          _score('DRAWS', '$_draws', const Color(0xFFFFC857)),
          _score(_mode == GameMode.humanAi ? 'COMPUTER' : 'PLAYER 2',
              '$_oScore', _pink),
        ]),
      );

  Widget _score(String label, String value, Color color) => Expanded(
        child: Column(children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: _ink.withOpacity(.53),
                  fontSize: 9,
                  letterSpacing: .8,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 25, fontWeight: FontWeight.w900)),
        ]),
      );

  Widget _boardWidget() => AspectRatio(
        aspectRatio: 1,
        child: Stack(
          children: [
            Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(.75),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                    color: _purple.withOpacity(.12),
                    blurRadius: 26,
                    offset: const Offset(0, 12))
              ]),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 9,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => _play(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                    color: _board[i] == null
                        ? const Color(0xFFF3F1FF)
                        : (_board[i] == 'X'
                            ? _cyan.withOpacity(.19)
                            : _pink.withOpacity(.17)),
                    borderRadius: BorderRadius.circular(18)),
                child: Center(
                    child: AnimatedScale(
                  scale: _board[i] == null ? 0 : 1,
                  duration: const Duration(milliseconds: 170),
                  curve: Curves.easeOutBack,
                  child: Text(_board[i] ?? '',
                      style: TextStyle(
                          color: _board[i] == 'X'
                              ? const Color(0xFF17AFA8)
                              : _pink,
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          height: 1)),
                )),
              ),
            ),
          ),
            ),
            if (_winner != null || _draw)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: _ink.withOpacity(.78),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _statusCard() =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
                color: _winner != null ? _pink : _cyan,
                shape: BoxShape.circle)),
        const SizedBox(width: 9),
        Flexible(
            child: Text(_status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _ink, fontWeight: FontWeight.w800, fontSize: 14))),
      ]);

  Widget _bannerFooter() => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(vertical: 4),
        color: Colors.white.withOpacity(.72),
        child: Center(
          child: _bannerReady && _banner != null
              ? SizedBox(
                  width: _banner!.size.width.toDouble(),
                  height: _banner!.size.height.toDouble(),
                  child: AdWidget(ad: _banner!))
              : const SizedBox(
                  width: 320,
                  height: 50,
                  child: Center(
                      child: Text('Advertisement',
                          style: TextStyle(
                              color: Color(0xFFAAA5BC),
                              fontSize: 10,
                              letterSpacing: 1.1)))),
        ),
      );
}
