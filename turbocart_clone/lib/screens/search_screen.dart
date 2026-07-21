import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/colors.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../widgets/product_card.dart';
import '../utils/search_keywords_data.dart';
import '../utils/search_suggestions_data.dart';

import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../utils/snackbar_utils.dart';
import 'package:permission_handler/permission_handler.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Main Screen Widget
// ──────────────────────────────────────────────────────────────────────────────
class SearchScreen extends StatefulWidget {
  final Map<String, dynamic>? extra;
  const SearchScreen({super.key, this.extra});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  // ── Controllers & Keys ──
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _searchBarKey = GlobalKey();

  // ── State ──
  List<String> _recentSearches = [];
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];
  String? _didYouMean;

  // ── Suggestion Overlay ──
  OverlayEntry? _overlayEntry;
  List<SuggestionItem> _suggestions = [];
  Timer? _suggestionDebounce;
  Timer? _searchDebounce;
  late AnimationController _dropdownAnimCtrl;
  late Animation<double> _dropdownFade;
  late Animation<double> _dropdownSize;

  // ── Speech ──
  late stt.SpeechToText _speech;
  bool _isSpeechInitialized = false;
  bool _isListening = false;
  String _listeningText = 'Listening... Speak now';

  Timer? _speechSilenceTimer;
  Timer? _speechDebounceTimer;

  static const List<String> _popularSearches = [
    'tomato', 'milk', 'egg', 'vegetables'
  ];

  @override
  void initState() {
    super.initState();
    _dropdownAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _dropdownFade = CurvedAnimation(
      parent: _dropdownAnimCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    _dropdownSize = CurvedAnimation(
      parent: _dropdownAnimCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );

    _loadRecentSearches();
    _searchController.addListener(_onSearchChanged);
    _focusNode.addListener(_onFocusChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.extra != null && widget.extra!['startVoiceSearch'] == true) {
        _startVoiceSearch();
      }
    });
  }

  @override
  void dispose() {
    _hideSuggestionsOverlay();
    _suggestionDebounce?.cancel();
    _searchDebounce?.cancel();
    _speechSilenceTimer?.cancel();
    _dropdownAnimCtrl.dispose();
    _searchController.removeListener(_onSearchChanged);
    _focusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Overlay Management
  // ──────────────────────────────────────────────────────────────────────────
  void _showSuggestionsOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (_) => _SearchDropdownOverlay(
        anchorKey: _searchBarKey,
        suggestions: _suggestions,
        query: _searchController.text.trim(),
        fadeAnimation: _dropdownFade,
        sizeAnimation: _dropdownSize,
        onSuggestionTap: (item) => _onSuggestionSelected(item, autofillOnly: false),
        onAutofill: (item) => _onSuggestionSelected(item, autofillOnly: true),
        onDismiss: _hideSuggestionsOverlay,
      ),
    );
    overlay.insert(_overlayEntry!);
    _dropdownAnimCtrl.forward(from: 0);
  }

  void _hideSuggestionsOverlay() {
    if (_overlayEntry == null) return;
    _dropdownAnimCtrl.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  void _refreshOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Suggestion Builder
  // ──────────────────────────────────────────────────────────────────────────
  List<SuggestionItem> _buildSuggestions(String query) {
    final q = query.toLowerCase().trim();
    if (q.length < 2) return [];

    final List<SuggestionItem> results = [];

    // Source 1 — Recent searches (max 2)
    final recentMatches = _recentSearches
        .where((s) => s.toLowerCase().contains(q))
        .take(2)
        .map((s) => SuggestionItem(text: s, label: 'Recent', type: SuggestionType.recent))
        .toList();
    results.addAll(recentMatches);

    // Source 2 — Brand matches (max 2)
    final brandMatches = kBrands
        .where((b) => b.toLowerCase().startsWith(q))
        .take(2)
        .map((b) => SuggestionItem(text: b, label: 'Brand', type: SuggestionType.brand))
        .toList();
    results.addAll(brandMatches);

    // Source 3 — Category keyword matches (max 2)
    final catMatches = kCategoryKeywords
        .where((pair) => pair.$1.toLowerCase().startsWith(q))
        .take(2)
        .map((pair) => SuggestionItem(text: pair.$1, label: pair.$2, type: SuggestionType.category))
        .toList();
    results.addAll(catMatches);

    // Source 4 — Instant prefix lookup (max 6, replaces slower Firestore)
    final prefix2 = q.length >= 2 ? q.substring(0, 2) : q;
    final instant = kInstantSuggestions[prefix2] ?? [];
    for (final item in instant) {
      if (item.text.toLowerCase().startsWith(q) &&
          !results.any((r) => r.text.toLowerCase() == item.text.toLowerCase())) {
        results.add(item);
        if (results.length >= 12) break;
      }
    }

    // Source 5 — Local product keyword matches (top 6 if not already full)
    if (results.length < 12) {
      final productMatches = kLocalProducts
          .where((p) => SearchUtils.matchesKeywords(p, q))
          .take(12 - results.length)
          .map((p) => SuggestionItem(
                text: p['title'] ?? p['name'] ?? '',
                label: _categoryLabel(p['category'] ?? ''),
                type: SuggestionType.product,
              ))
          .where((s) => s.text.isNotEmpty &&
              !results.any((r) => r.text.toLowerCase() == s.text.toLowerCase()))
          .toList();
      results.addAll(productMatches);
    }

    return results.take(12).toList();
  }

  String _categoryLabel(String cat) {
    const map = {
      'vacations': 'Grocery',
      'grocery_kitchen': 'Grocery',
      'snacks_drinks': 'Snacks',
      'beauty': 'Beauty',
      'pharmacy': 'Pharmacy',
      'electronics': 'Electronics',
    };
    return map[cat] ?? cat;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Event Handlers
  // ──────────────────────────────────────────────────────────────────────────
  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _hideSuggestionsOverlay();
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    // Update suggestions immediately (300ms debounce)
    if (_suggestionDebounce?.isActive ?? false) _suggestionDebounce!.cancel();
    _suggestionDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (query.length >= 2) {
        setState(() {
          _suggestions = _buildSuggestions(query);
        });
        if (_suggestions.isNotEmpty) {
          _showSuggestionsOverlay();
        } else {
          // Show "search for X" fallback if 3+ chars
          if (query.length >= 3) {
            setState(() {
              _suggestions = [
                SuggestionItem(
                    text: query, label: 'Search directly', type: SuggestionType.product)
              ];
            });
            _showSuggestionsOverlay();
          } else {
            _hideSuggestionsOverlay();
          }
        }
        _refreshOverlay();
      } else {
        _hideSuggestionsOverlay();
        setState(() {
          _suggestions.clear();
          _searchResults.clear();
          _didYouMean = null;
          _isLoading = false;
        });
      }
    });

    // Perform search (400ms debounce)
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (query.length >= 2) {
        _performSearch(query);
      } else {
        if (mounted) {
          setState(() {
            _searchResults.clear();
            _didYouMean = null;
            _isLoading = false;
          });
        }
      }
    });
  }

  void _onSuggestionSelected(SuggestionItem item, {required bool autofillOnly}) {
    _hideSuggestionsOverlay();
    final text = item.text;
    _searchController.text = text;
    _searchController.selection =
        TextSelection.fromPosition(TextPosition(offset: text.length));

    if (!autofillOnly) {
      _focusNode.unfocus();
      _performSearch(text);
      _saveSearch(text);
    }
  }

  void _fillSearch(String term) {
    _searchController.text = term;
    _searchController.selection =
        TextSelection.fromPosition(TextPosition(offset: term.length));
    _performSearch(term);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Search Logic
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _performSearch(String raw) async {
    final query = raw.toLowerCase().trim();
    if (query.length < 2) return;

    setState(() {
      _isLoading = true;
      _didYouMean = null;
    });

    try {
      final bool isHindi = SearchUtils.isHindiScript(query);
      final String searchField = isHindi ? 'searchKeywordsHindi' : 'searchKeywords';

      var snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where(searchField, arrayContains: query)
          .get();

      List<Map<String, dynamic>> results =
          snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      if (results.isEmpty) {
        final prefixSnap = await FirebaseFirestore.instance
            .collection('products')
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: '$query\uf8ff')
            .limit(20)
            .get();
        results = prefixSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      }

      if (results.isEmpty) {
        results = kLocalProducts
            .where((p) => SearchUtils.matchesKeywords(p, query))
            .toList();
      }

      String? suggestion;
      if (results.isEmpty) {
        suggestion = SearchUtils.getSuggestion(query);
        if (suggestion != null) {
          results = kLocalProducts
              .where((p) => SearchUtils.matchesKeywords(p, suggestion!))
              .toList();
        }
      }

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _didYouMean = results.isEmpty ? suggestion : null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Search error: $e — local fallback');
      final q2 = raw.toLowerCase().trim();
      final local = kLocalProducts
          .where((p) => SearchUtils.matchesKeywords(p, q2))
          .toList();
      final suggestion = local.isEmpty ? SearchUtils.getSuggestion(q2) : null;
      final suggested = suggestion != null
          ? kLocalProducts.where((p) => SearchUtils.matchesKeywords(p, suggestion)).toList()
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _searchResults = local.isNotEmpty ? local : suggested;
          _didYouMean = local.isEmpty ? suggestion : null;
          _isLoading = false;
        });
      }
    }
    _saveSearch(raw.trim());
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  Future<void> _saveSearch(String query) async {
    if (query.trim().length < 2) return;
    final prefs = await SharedPreferences.getInstance();
    final q = query.trim();
    _recentSearches.remove(q);
    _recentSearches.insert(0, q);
    if (_recentSearches.length > 5) _recentSearches = _recentSearches.sublist(0, 5);
    await prefs.setStringList('recent_searches', _recentSearches);
    if (mounted) setState(() {});
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
    setState(() => _recentSearches.clear());
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Voice Search
  // ──────────────────────────────────────────────────────────────────────────
  StateSetter? _modalSetState;

  void _processVoiceResult() {
    if (_listeningText.isNotEmpty && 
        !_listeningText.startsWith('Listening') && 
        !_listeningText.startsWith('Tap the ')) {
      _searchController.text = _listeningText;
      _performSearch(_listeningText);
      _saveSearch(_listeningText);
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    }
  }

  void _resumeListening() {
    setState(() {
      _isListening = true;
      _listeningText = 'Listening... Speak now';
    });
    _modalSetState?.call(() {});
    
    void resetSilenceTimer() {
      _speechSilenceTimer?.cancel();
      _speechSilenceTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted || !_isListening) return;
        try {
          _speech.stop();
        } catch (_) {}
        setState(() => _isListening = false);
        _modalSetState?.call(() {});
        _processVoiceResult();
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      });
    }
    
    resetSilenceTimer();

    try {
      _speech.listen(
        onResult: (r) {
          resetSilenceTimer();
          setState(() => _listeningText = r.recognizedWords);
          _modalSetState?.call(() {});
          
          // Auto-search debounce: if no new word is spoken for 1.2 seconds, automatically trigger search!
          _speechDebounceTimer?.cancel();
          _speechDebounceTimer = Timer(const Duration(milliseconds: 1200), () {
            if (mounted && _isListening && _listeningText.isNotEmpty &&
                !_listeningText.startsWith('Listening') && !_listeningText.startsWith('Tap the ')) {
              try {
                _speech.stop();
              } catch (_) {}
              setState(() => _isListening = false);
              _speechSilenceTimer?.cancel();
              _processVoiceResult();
              if (Navigator.canPop(context)) Navigator.pop(context);
            }
          });

          if (r.finalResult) {
            try {
              _speech.stop();
            } catch (_) {}
            setState(() => _isListening = false);
            _speechSilenceTimer?.cancel();
            _speechDebounceTimer?.cancel();
            _processVoiceResult();
            if (Navigator.canPop(context)) Navigator.pop(context);
          }
        },
      );
    } catch (e) {
      debugPrint('Speech listen failed: $e');
      setState(() => _isListening = false);
      _speechSilenceTimer?.cancel();
      _startMockListening();
    }
  }

  Future<void> _startVoiceSearch() async {
    // Request microphone permission explicitly first
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }
    if (status.isPermanentlyDenied) {
      SnackBarUtils.showTopSnackBar(
        context,
        'Microphone permission is permanently denied. Please enable it in Settings.',
        backgroundColor: Colors.redAccent,
      );
      _startMockListening();
      return;
    }
    if (!status.isGranted) {
      _startMockListening();
      return;
    }

    if (!_isSpeechInitialized) {
      _speech = stt.SpeechToText();
      try {
        _isSpeechInitialized = await _speech.initialize(
          onStatus: (s) {
            if ((s == 'done' || s == 'notListening') && mounted && _isListening) {
              setState(() => _isListening = false);
              _modalSetState?.call(() {});
            }
          },
          onError: (e) {
            if (!context.mounted) return;
            if (_isListening) {
              setState(() => _isListening = false);
              _modalSetState?.call(() {});
              SnackBarUtils.showTopSnackBar(context, 'Speech error: ${e.errorMsg}',
                  backgroundColor: Colors.redAccent);
            }
          },
        );
      } catch (e) {
        debugPrint('Speech init failed: $e');
        _isSpeechInitialized = false;
      }
    }
    if (!mounted || !_isSpeechInitialized) {
      if (mounted) {
        _startMockListening();
      }
      return;
    }
    setState(() {
      _isListening = true;
      _listeningText = 'Listening... Speak now';
    });
    
    try {
      _resumeListening();
    } catch (e) {
      debugPrint('Speech listen failed on start: $e');
      setState(() => _isListening = false);
      _startMockListening();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: StatefulBuilder(
          builder: (context, setModalState) {
            _modalSetState = setModalState;
            final hasWords = _listeningText.isNotEmpty && !_listeningText.startsWith('Listening');
            return Container(
              height: 290,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Listening for products...',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: Text(_listeningText, textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500,
                              color: !_isListening
                                  ? Colors.grey[500] : TurbocartColors.primary)),
                    ),
                  ),
                  if (hasWords)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          try {
                            _speech.stop();
                          } catch (_) {}
                          setState(() => _isListening = false);
                          _speechSilenceTimer?.cancel();
                          _speechDebounceTimer?.cancel();
                          _processVoiceResult();
                          if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.search),
                        label: Text('Search "$_listeningText"'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TurbocartColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  _VoiceMicButton(
                    isListening: _isListening,
                    onTap: () {
                      if (_isListening) {
                        try {
                          _speech.stop();
                        } catch (_) {}
                        setState(() => _isListening = false);
                        _modalSetState?.call(() {});
                        _processVoiceResult();
                        if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                      } else {
                        _resumeListening();
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ).then((_) { 
      _modalSetState = null;
      _speechSilenceTimer?.cancel();
      _speechDebounceTimer?.cancel();
      try {
        _speech.stop(); 
      } catch (_) {}
      setState(() => _isListening = false); 
    });
  }

  void _startMockListening() {
    final TextEditingController mockInputController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: StatefulBuilder(
          builder: (context, setModalState) {
            _modalSetState = setModalState;

            return Container(
              height: 280,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Speak Product Name',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Simulate speech input by typing below:',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: mockInputController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Speak/Type search product name...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          _searchController.text = val.trim();
                          _onSearchChanged();
                          if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                        }
                      },
                    ),
                  ),
                  const Spacer(),
                  _VoiceMicButton(
                    isListening: true,
                    onTap: () {
                      final val = mockInputController.text.trim();
                      if (val.isNotEmpty) {
                        _searchController.text = val;
                        _onSearchChanged();
                      }
                      if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ).then((_) { 
      _modalSetState = null;
      _speechSilenceTimer?.cancel();
      setState(() => _isListening = false); 
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        _focusNode.unfocus();
        _hideSuggestionsOverlay();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: Consumer<CartProvider>(
          builder: (context, cart, child) {
            if (cart.itemCount == 0) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
              ),
              child: SafeArea(
                top: false,
                child: ElevatedButton(
                  onPressed: () => context.push('/cart'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0C831F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text('${cart.totalQuantity} ITEM${cart.totalQuantity > 1 ? 'S' : ''}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                        Text('₹${cart.grandTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ]),
                      const Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Proceed to Cart', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_ios, size: 14),
                      ]),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          foregroundColor: TurbocartColors.textDark,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () {
              _hideSuggestionsOverlay();
              context.go('/home');
            },
          ),
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Hero(
              tag: 'search-bar',
              child: Material(
                color: Colors.transparent,
                child: Container(
                  key: _searchBarKey,
                  height: 44,
                  decoration: BoxDecoration(
                    color: TurbocartColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: TurbocartColors.textDark, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (value) {
                            _hideSuggestionsOverlay();
                            _performSearch(value);
                          },
                          decoration: const InputDecoration(
                            hintText: 'tamatar, dudh, atta, maggi...',
                            hintStyle: TextStyle(color: TurbocartColors.textGrey, fontSize: 13),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (query.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            _hideSuggestionsOverlay();
                            setState(() { _searchResults.clear(); _didYouMean = null; });
                          },
                          child: const Icon(Icons.close, color: TurbocartColors.textGrey, size: 18),
                        )
                      else
                        GestureDetector(
                          onTap: _startVoiceSearch,
                          child: Icon(Icons.mic, color: _isListening ? Colors.red : TurbocartColors.textGrey, size: 20),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: query.isEmpty ? _buildEmptyBody() : _buildResultsBody(query),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Empty Body — Recent + Popular
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildEmptyBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recentSearches.isNotEmpty) ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Recent Searches',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: TurbocartColors.textDark)),
              TextButton(
                onPressed: _clearRecentSearches,
                child: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _recentSearches.map((s) => ActionChip(
                avatar: const Icon(Icons.history, size: 14, color: TurbocartColors.textGrey),
                label: Text(s, style: const TextStyle(fontSize: 12, color: TurbocartColors.textDark)),
                backgroundColor: Colors.grey.shade50,
                side: BorderSide(color: Colors.grey.shade200),
                onPressed: () => _fillSearch(s),
              )).toList(),
            ),
            const SizedBox(height: 24),
          ],
          const Text('Popular Searches',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: TurbocartColors.textDark)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _popularSearches.map((term) => GestureDetector(
              onTap: () => _fillSearch(term),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(term, style: const TextStyle(fontSize: 13, color: TurbocartColors.textDark, fontWeight: FontWeight.w500)),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Results Body
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildResultsBody(String query) {
    if (_isLoading) return _buildShimmerGrid();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_didYouMean != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: GestureDetector(
              onTap: () => _fillSearch(_didYouMean!),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  children: [
                    const TextSpan(text: 'Did you mean '),
                    TextSpan(
                      text: _didYouMean!,
                      style: TextStyle(
                        color: TurbocartColors.primary,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        decorationColor: TurbocartColors.primary,
                      ),
                    ),
                    const TextSpan(text: '?'),
                  ],
                ),
              ),
            ),
          ),
        if (_searchResults.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              '${_searchResults.length} result${_searchResults.length != 1 ? 's' : ''} for "$query"',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        Expanded(
          child: _searchResults.isEmpty
              ? _buildEmptyState(query)
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 0.62,
                    crossAxisSpacing: 12, mainAxisSpacing: 12,
                  ),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, i) => ProductCard(product: _searchResults[i], width: null),
                ),
        ),
      ],
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.62, crossAxisSpacing: 12, mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (_, i) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: TurbocartColors.lightGrey),
        ),
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Expanded(child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 12),
              Container(height: 14, color: Colors.white),
              const SizedBox(height: 6),
              Container(height: 10, width: 80, color: Colors.white),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String query) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 140, width: 140,
              child: Lottie.network(
                'https://assets9.lottiefiles.com/packages/lf20_9h5z6p.json',
                errorBuilder: (context2, e, st) =>
                    const Icon(Icons.search_off, size: 80, color: TurbocartColors.textGrey),
              ),
            ),
            const SizedBox(height: 16),
            Text('No results for "$query"',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: TurbocartColors.textDark),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Try tamatar instead of tomato, or aata instead of flour',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            const Text('Try popular searches:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: TurbocartColors.textDark)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
              children: ['tamatar', 'dudh', 'maggi', 'atta', 'chips'].map((s) => GestureDetector(
                onTap: () => _fillSearch(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: TurbocartColors.primary.withValues(alpha: 0.08),
                    border: Border.all(color: TurbocartColors.primary.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(s, style: const TextStyle(fontSize: 12, color: TurbocartColors.primary, fontWeight: FontWeight.w600)),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    ),
  );
}
}

// ──────────────────────────────────────────────────────────────────────────────
// Overlay Widget — Floating Dropdown
// ──────────────────────────────────────────────────────────────────────────────
class _SearchDropdownOverlay extends StatefulWidget {
  final GlobalKey anchorKey;
  final List<SuggestionItem> suggestions;
  final String query;
  final Animation<double> fadeAnimation;
  final Animation<double> sizeAnimation;
  final void Function(SuggestionItem) onSuggestionTap;
  final void Function(SuggestionItem) onAutofill;
  final VoidCallback onDismiss;

  const _SearchDropdownOverlay({
    required this.anchorKey,
    required this.suggestions,
    required this.query,
    required this.fadeAnimation,
    required this.sizeAnimation,
    required this.onSuggestionTap,
    required this.onAutofill,
    required this.onDismiss,
  });

  @override
  State<_SearchDropdownOverlay> createState() => _SearchDropdownOverlayState();
}

class _SearchDropdownOverlayState extends State<_SearchDropdownOverlay>
    with TickerProviderStateMixin {
  late List<AnimationController> _rowControllers;
  late List<Animation<double>> _rowAnims;

  @override
  void initState() {
    super.initState();
    _initRowAnimations();
  }

  @override
  void didUpdateWidget(_SearchDropdownOverlay old) {
    super.didUpdateWidget(old);
    if (old.suggestions.length != widget.suggestions.length) {
      _disposeRowAnimations();
      _initRowAnimations();
    }
  }

  void _initRowAnimations() {
    _rowControllers = List.generate(
      widget.suggestions.length,
      (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 150)),
    );
    _rowAnims = _rowControllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();
    // Staggered start
    for (var i = 0; i < _rowControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 30), () {
        if (mounted) _rowControllers[i].forward();
      });
    }
  }

  void _disposeRowAnimations() {
    for (final c in _rowControllers) { c.dispose(); }
  }

  @override
  void dispose() {
    _disposeRowAnimations();
    super.dispose();
  }

  Rect? _getAnchorRect() {
    final ctx = widget.anchorKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final pos = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height);
  }

  @override
  Widget build(BuildContext context) {
    final anchor = _getAnchorRect();
    if (anchor == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onDismiss,
        child: Stack(
          children: [
            Positioned(
              left: anchor.left,
              top: anchor.bottom + 2,
              width: anchor.width,
              child: FadeTransition(
                opacity: widget.fadeAnimation,
                child: SizeTransition(
                  sizeFactor: widget.sizeAnimation,
                  axisAlignment: -1,
                  child: _buildDropdownCard(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownCard() {
    final isEmpty = widget.suggestions.isEmpty;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: const Border(
            top: BorderSide(color: Color(0xFF0C831F), width: 1.5),
          ),
        ),
        child: isEmpty
            ? _buildNoResultsRow()
            : ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < widget.suggestions.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, thickness: 0.5, color: Colors.grey.withValues(alpha: 0.3)),
                        i < _rowAnims.length
                            ? FadeTransition(
                                opacity: _rowAnims[i],
                                child: _SuggestionRow(
                                  item: widget.suggestions[i],
                                  query: widget.query,
                                  onTap: () => widget.onSuggestionTap(widget.suggestions[i]),
                                  onAutofill: () => widget.onAutofill(widget.suggestions[i]),
                                ),
                              )
                            : _SuggestionRow(
                                item: widget.suggestions[i],
                                query: widget.query,
                                onTap: () => widget.onSuggestionTap(widget.suggestions[i]),
                                onAutofill: () => widget.onAutofill(widget.suggestions[i]),
                              ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildNoResultsRow() {
    return GestureDetector(
      onTap: () => widget.onSuggestionTap(
        SuggestionItem(text: widget.query, label: 'Search directly', type: SuggestionType.product),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.search, size: 18, color: TurbocartColors.textGrey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search for "${widget.query}"',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
            const Icon(Icons.arrow_forward, size: 16, color: TurbocartColors.textGrey),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Suggestion Row Widget
// ──────────────────────────────────────────────────────────────────────────────
class _SuggestionRow extends StatelessWidget {
  final SuggestionItem item;
  final String query;
  final VoidCallback onTap;
  final VoidCallback onAutofill;

  const _SuggestionRow({
    required this.item,
    required this.query,
    required this.onTap,
    required this.onAutofill,
  });

  IconData get _icon {
    switch (item.type) {
      case SuggestionType.recent: return Icons.history;
      case SuggestionType.brand: return Icons.store_outlined;
      case SuggestionType.category: return Icons.grid_view_rounded;
      case SuggestionType.product: return Icons.shopping_basket_outlined;
    }
  }

  Color get _iconColor {
    switch (item.type) {
      case SuggestionType.recent: return Colors.grey;
      case SuggestionType.brand: return Colors.orange.shade600;
      case SuggestionType.category: return Colors.grey.shade600;
      case SuggestionType.product: return const Color(0xFF0C831F);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // ── Left icon ──
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_icon, size: 18, color: _iconColor),
            ),
            const SizedBox(width: 12),
            // ── Middle: highlighted text + label ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HighlightedText(text: item.text, query: query),
                  const SizedBox(height: 2),
                  Text(item.label,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // ── Right: autofill arrow ──
            GestureDetector(
              onTap: onAutofill,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Transform.rotate(
                  angle: -0.785398, // 45 degrees = north-west arrow
                  child: Icon(Icons.arrow_outward, size: 14, color: Colors.grey.shade400),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Highlighted Text — matched portion in green bold
// ──────────────────────────────────────────────────────────────────────────────
class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;

  const _HighlightedText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
          maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchStart = lowerText.indexOf(lowerQuery);

    if (matchStart == -1) {
      return Text(text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
          maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final matchEnd = matchStart + lowerQuery.length;

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          if (matchStart > 0)
            TextSpan(
              text: text.substring(0, matchStart),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
          TextSpan(
            text: text.substring(matchStart, matchEnd),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0C831F),
            ),
          ),
          if (matchEnd < text.length)
            TextSpan(
              text: text.substring(matchEnd),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
        ],
      ),
    );
  }
}

class _VoiceMicButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onTap;
  const _VoiceMicButton({required this.isListening, required this.onTap});

  @override
  _VoiceMicButtonState createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<_VoiceMicButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.isListening) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_VoiceMicButton old) {
    super.didUpdateWidget(old);
    if (widget.isListening) {
      _ctrl.repeat(reverse: true);
    } else {
      _ctrl.stop();
      _ctrl.animateBack(0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isListening ? Colors.red : const Color(0xFF0C831F);
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(Icons.mic, color: Colors.white, size: 28),
              ),
            ),
          );
        },
      ),
    );
  }
}
