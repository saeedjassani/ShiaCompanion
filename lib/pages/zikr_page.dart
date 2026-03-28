import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/utils/deep_links.dart';
import '../constants.dart';
import '../widgets/zikr_settings.dart';
import '../widgets/zikr_counter.dart';
// import 'zikr_counters_list_page.dart';

class ZikrPage extends StatefulWidget {
  final UidTitleData item;
  final bool startEditing;
  ZikrPage(this.item, {this.startEditing = false});

  @override
  _ZikrPageState createState() => _ZikrPageState();
}

class _ZikrPageState extends State<ZikrPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference zikrCollection =
      FirebaseFirestore.instance.collection('zikr');

  bool isAdmin = false;
  bool isEditing = false;
  String? userId;
  Map<String, dynamic>? zikrData;
  TextEditingController? titleController;
  TextEditingController? slugController;
  TextEditingController? codeController;
  TextEditingController? dataController;
  TextEditingController? meritsController;
  TextEditingController? orderController;
  final List<TextEditingController> tabControllers = [];
  final List<ScrollController> _tabScrollControllers = [];
  final List<GlobalKey> _tabHeaderKeys = [];
  final RegExp _numericOrderPattern = RegExp(r'^-?\d+(\.\d+)?$');
  final PageController _pageController = PageController();
  List<String> _slugAliases = const [];
  int _selectedTabIndex = 0;

  TextStyle arabicStyle = TextStyle(
      fontFamily: arabicFont, fontSize: arabicFontSize, letterSpacing: 0);
  TextStyle transliStyle =
      TextStyle(fontWeight: FontWeight.bold, fontSize: englishFontSize);

  @override
  void initState() {
    super.initState();
    if (widget.startEditing) {
      isEditing = true;
    }
    _checkAdmin();
    _fetchZikrData();
  }

  @override
  void dispose() {
    titleController?.dispose();
    slugController?.dispose();
    codeController?.dispose();
    dataController?.dispose();
    meritsController?.dispose();
    orderController?.dispose();
    for (final controller in tabControllers) {
      controller.dispose();
    }
    for (final controller in _tabScrollControllers) {
      controller.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        userId = user.uid;
      });
      final idTokenResult = await user.getIdTokenResult(true);
      final claims = idTokenResult.claims;
      if (claims != null && claims['admin'] == true) {
        setState(() {
          isAdmin = true;
        });
      }
    }
  }

  Future<void> _fetchZikrData() async {
    final doc = await zikrCollection.doc(widget.item.getFirstUId()).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final currentSlug = normalizeSlug(data['slug']?.toString() ?? '');
      final currentAliases = normalizeSlugAliases(
        data['slugAliases'] is Iterable ? data['slugAliases'] : null,
        exclude: currentSlug,
      );
      setState(() {
        zikrData = data;
        titleController = TextEditingController(text: zikrData?['title']);
        slugController = TextEditingController(text: currentSlug);
        codeController = TextEditingController(text: zikrData?['code']);
        dataController = TextEditingController(text: zikrData?['data']);
        meritsController = TextEditingController(text: zikrData?['merits']);
        _slugAliases = currentAliases;
        final rawTabs = zikrData?['tabs'];
        if (rawTabs is List) {
          for (final controller in tabControllers) {
            controller.dispose();
          }
          tabControllers.clear();
          for (final tab in rawTabs) {
            tabControllers
                .add(TextEditingController(text: tab?.toString() ?? ''));
          }
        }
        final double? currentOrder = itemOrder[widget.item.uid];
        orderController = TextEditingController(
            text: currentOrder == null
                ? ''
                : (currentOrder % 1 == 0
                    ? currentOrder.toInt().toString()
                    : currentOrder.toString()));
        _syncTabState(_buildVisibleTabContents().length);
      });
    }
  }

  void _resetControllersFromCurrentData() {
    final currentSlug = normalizeSlug(zikrData?['slug']?.toString() ?? '');
    titleController?.text = zikrData?['title']?.toString() ?? '';
    slugController?.text = currentSlug;
    codeController?.text = zikrData?['code']?.toString() ?? '';
    dataController?.text = zikrData?['data']?.toString() ?? '';
    meritsController?.text = zikrData?['merits']?.toString() ?? '';
    final currentOrder = itemOrder[widget.item.uid];
    orderController?.text = currentOrder == null
        ? ''
        : (currentOrder % 1 == 0
            ? currentOrder.toInt().toString()
            : currentOrder.toString());
    final rawSlugAliases = zikrData?['slugAliases'];
    _slugAliases = normalizeSlugAliases(
      rawSlugAliases is Iterable ? rawSlugAliases : null,
      exclude: currentSlug,
    );

    for (final controller in tabControllers) {
      controller.dispose();
    }
    tabControllers.clear();
    final rawTabs = zikrData?['tabs'];
    if (rawTabs is List) {
      for (final tab in rawTabs) {
        tabControllers.add(TextEditingController(text: tab?.toString() ?? ''));
      }
    }
    _syncTabState(_buildVisibleTabContents().length);
  }

  void _toggleEdit() {
    setState(() {
      if (isEditing) {
        _resetControllersFromCurrentData();
      }
      isEditing = !isEditing;
    });
  }

  Future<void> _saveEdits() async {
    if (zikrData != null) {
      final trimmedTitle = titleController?.text.trim() ?? '';
      final rawOrder = orderController?.text.trim() ?? '';
      final savedTabs = tabControllers
          .map((controller) => controller.text)
          .where((content) => content.trim().isNotEmpty)
          .toList();
      final existingSlug = normalizeSlug(zikrData?['slug']?.toString() ?? '');
      final enteredSlug = slugController?.text.trim() ?? '';
      final normalizedEnteredSlug = normalizeSlug(enteredSlug);
      if (enteredSlug.isNotEmpty && normalizedEnteredSlug.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Slug must contain letters or numbers'),
        ));
        return;
      }
      if (rawOrder.isNotEmpty && !_numericOrderPattern.hasMatch(rawOrder)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Order must be a number (examples: -2, 5, 5.5) or left blank'),
        ));
        return;
      }
      final parsedOrder = rawOrder.isEmpty ? null : double.parse(rawOrder);
      final nextSlug = enteredSlug.isNotEmpty
          ? normalizedEnteredSlug
          : existingSlug.isNotEmpty
              ? existingSlug
              : makeUniqueSlug(
                  buildSlugSeed(
                    uid: widget.item.uid,
                    title: trimmedTitle,
                  ),
                  currentUid: widget.item.uid,
                );
      if (!isSlugAvailable(nextSlug, currentUid: widget.item.uid)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Slug is already in use. Please choose another one.'),
        ));
        return;
      }
      final nextSlugAliases = normalizeSlugAliases(
        [
          ..._slugAliases,
          if (existingSlug.isNotEmpty && existingSlug != nextSlug) existingSlug,
        ],
        exclude: nextSlug,
      );

      await zikrCollection.doc(widget.item.uid).update({
        'title': titleController?.text,
        'slug': nextSlug,
        'slugAliases':
            nextSlugAliases.isEmpty ? FieldValue.delete() : nextSlugAliases,
        'code': codeController?.text,
        'data': dataController?.text,
        'merits': (meritsController?.text.trim().isEmpty ?? true)
            ? FieldValue.delete()
            : meritsController?.text,
        'tabs': savedTabs.isEmpty ? FieldValue.delete() : savedTabs,
        'order': parsedOrder ?? FieldValue.delete(),
      });
      if (parsedOrder == null) {
        itemOrder.remove(widget.item.uid);
      } else {
        itemOrder[widget.item.uid] = parsedOrder;
      }
      items[widget.item.uid] = titleController?.text ?? widget.item.title;
      widget.item.title = titleController?.text ?? widget.item.title;
      setLocalSlugData(
        widget.item.uid,
        slug: nextSlug,
        aliases: nextSlugAliases,
      );
      setState(() {
        isEditing = false;
        zikrData?['title'] = titleController?.text;
        zikrData?['slug'] = nextSlug;
        zikrData?['slugAliases'] = nextSlugAliases;
        zikrData?['code'] = codeController?.text;
        zikrData?['data'] = dataController?.text;
        zikrData?['merits'] = meritsController?.text;
        zikrData?['tabs'] = savedTabs;
        slugController?.text = nextSlug;
        _slugAliases = nextSlugAliases;
        _syncTabState(_buildVisibleTabContents().length);
      });
    }
  }

  void _addTabField() {
    setState(() {
      tabControllers.add(TextEditingController());
    });
  }

  void _showMeritsSheet() {
    final merits = meritsController?.text.trim() ?? '';
    if (merits.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Merits',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    SelectableText(
                      merits,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _buildVisibleTabContents() {
    final primary = dataController?.text ?? zikrData?['data']?.toString() ?? '';
    final extraTabs = <String>[];
    final rawTabs = zikrData?['tabs'];

    if (tabControllers.isNotEmpty) {
      extraTabs.addAll(tabControllers.map((controller) => controller.text));
    } else if (rawTabs is List) {
      extraTabs.addAll(rawTabs.map((tab) => tab?.toString() ?? ''));
    }

    final visibleTabs = <String>[];
    if (primary.trim().isNotEmpty ||
        extraTabs.every((tab) => tab.trim().isEmpty)) {
      visibleTabs.add(primary);
    }
    visibleTabs.addAll(extraTabs.where((tab) => tab.trim().isNotEmpty));
    return visibleTabs;
  }

  void _syncTabState(int count) {
    if (count <= 0) {
      _selectedTabIndex = 0;
      _syncTabHeaderKeys(0);
      _syncTabScrollControllers(0);
      return;
    }

    final clampedIndex = _selectedTabIndex.clamp(0, count - 1);
    final didClampIndex = clampedIndex != _selectedTabIndex;
    if (didClampIndex) {
      _selectedTabIndex = clampedIndex;
    }

    if (didClampIndex && _pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_selectedTabIndex);
        }
      });
    }

    _syncTabHeaderKeys(count);
    _syncTabScrollControllers(count);
  }

  void _syncTabHeaderKeys(int count) {
    while (_tabHeaderKeys.length < count) {
      _tabHeaderKeys.add(GlobalKey());
    }
    while (_tabHeaderKeys.length > count) {
      _tabHeaderKeys.removeLast();
    }
  }

  void _syncTabScrollControllers(int count) {
    while (_tabScrollControllers.length < count) {
      _tabScrollControllers.add(ScrollController());
    }
    while (_tabScrollControllers.length > count) {
      _tabScrollControllers.removeLast().dispose();
    }
  }

  void _centerSelectedTab(
      {Duration duration = const Duration(milliseconds: 360)}) {
    if (!mounted ||
        _selectedTabIndex < 0 ||
        _selectedTabIndex >= _tabHeaderKeys.length) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _selectedTabIndex < 0 ||
          _selectedTabIndex >= _tabHeaderKeys.length) {
        return;
      }

      final currentContext = _tabHeaderKeys[_selectedTabIndex].currentContext;
      if (currentContext == null) return;

      Scrollable.ensureVisible(
        currentContext,
        alignment: 0.5,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _getTabHeader(String content, int index) {
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    if (lines.isNotEmpty) {
      return lines.first;
    }
    return 'Tab ${index + 1}';
  }

  Future<void> _animateToTab(int index) async {
    if (!_pageController.hasClients) {
      setState(() {
        _selectedTabIndex = index;
      });
      _centerSelectedTab(duration: Duration.zero);
      return;
    }

    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  void _shareCurrentZikr() {
    final tabContents = _buildVisibleTabContents();
    if (tabContents.isEmpty) return;

    final selectedIndex = _selectedTabIndex.clamp(0, tabContents.length - 1);
    final currentContent = tabContents[selectedIndex].trim();
    final title = titleController?.text.trim().isNotEmpty == true
        ? titleController!.text.trim()
        : widget.item.title;
    final deepLink = buildZikrDeepLinkUrl(
      uid: widget.item.uid,
      slug: itemSlugs[widget.item.uid],
    );

    SharePlus.instance.share(
      ShareParams(
        text: '$title\n$currentContent\n\nOpen in Shia Companion: $deepLink',
        sharePositionOrigin: Rect.fromLTWH(
          MediaQuery.of(context).size.width / 2,
          0,
          2,
          2,
        ),
      ),
    );
  }

  Widget _buildTabContent(
    String rawContent,
    ScrollController controller, {
    required bool hideHeaderLine,
  }) {
    final parsedContent = _parseContent(
      rawContent,
      hideHeaderLine: hideHeaderLine,
    );

    return Scrollbar(
      controller: controller,
      child: ListView.builder(
        controller: controller,
        itemCount: parsedContent.lines.length,
        itemBuilder: (BuildContext context, int index) {
          final str = parsedContent.lines[index].trim();

          if (parsedContent.arabicCodes.contains(index)) {
            return Padding(
              padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
              child: Text(
                formatArabicText(str),
                style: arabicStyle,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
            );
          } else if (parsedContent.transliCodes.contains(index)) {
            return showTransliteration
                ? Text(
                    str.toUpperCase(),
                    style: transliStyle,
                    textAlign: TextAlign.center,
                  )
                : Container();
          } else if (parsedContent.translaCodes.contains(index)) {
            return showTranslation
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      str,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: englishFontSize),
                    ),
                  )
                : Container();
          } else {
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4.0),
              child: Text(str),
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteZikr() async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete Zikr?'),
            content: Text(
              'This will permanently delete "${titleController?.text ?? widget.item.title}".',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;

    await zikrCollection.doc(widget.item.uid).delete();
    items.remove(widget.item.uid);
    itemOrder.remove(widget.item.uid);
    removeLocalSlugData(widget.item.uid);

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final merits = meritsController?.text.trim() ?? '';
    final hasMerits = merits.isNotEmpty;
    final tabContents = _buildVisibleTabContents();
    final pageTitle = isEditing
        ? (titleController?.text.trim().isNotEmpty == true
            ? titleController!.text.trim()
            : widget.item.title)
        : (zikrData?['title']?.toString().trim().isNotEmpty == true
            ? zikrData!['title'].toString().trim()
            : widget.item.title);
    _syncTabState(tabContents.length);
    final hasAnyContent =
        tabContents.any((content) => content.trim().isNotEmpty);
    final showTabHeaders = tabContents.length > 1;

    // Counter overlay state
    ValueNotifier<Offset> counterOffset = ValueNotifier(const Offset(20, 80));
    ValueNotifier<bool> showCounter = ValueNotifier(false);

    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(pageTitle),
          actions: [
            if (isAdmin && zikrData != null && isEditing)
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete Zikr',
                onPressed: _deleteZikr,
              ),
            if (isAdmin && zikrData != null && isEditing)
              IconButton(
                icon: const Icon(Icons.done),
                tooltip: 'Save Changes',
                onPressed: _saveEdits,
              ),
            if (zikrData != null)
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share',
                onPressed: _shareCurrentZikr,
              ),
            isAdmin && zikrData != null
                ? IconButton(
                    icon: Icon(isEditing ? Icons.close : Icons.edit),
                    onPressed: _toggleEdit,
                  )
                : Container(),
            Builder(builder: (BuildContext innerContext) {
              return IconButton(
                icon: Icon(Icons.filter_list),
                onPressed: () => Scaffold.of(innerContext).openEndDrawer(),
              );
            }),
          ],
        ),
        endDrawer: ZikrSettingsPage(refreshState),
        floatingActionButton: ValueListenableBuilder<bool>(
          valueListenable: showCounter,
          builder: (context, visible, _) => visible
              ? const SizedBox.shrink()
              : FloatingActionButton(
                  onPressed: () => showCounter.value = true,
                  tooltip: 'Show Counter',
                  child: const Icon(Icons.exposure_plus_1),
                ),
        ),
        body: Stack(
          children: [
            zikrData == null
                ? const Center(child: CircularProgressIndicator())
                : !hasAnyContent && !isEditing
                    ? const Center(child: Text('Coming soon...'))
                    : Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: isEditing
                            ? SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: titleController,
                                      decoration: const InputDecoration(
                                          labelText: 'Title'),
                                    ),
                                    TextField(
                                      controller: slugController,
                                      decoration: const InputDecoration(
                                        labelText: 'Slug',
                                        helperText:
                                            'Canonical URL path. Leave blank to auto-generate once; old slugs keep working.',
                                      ),
                                    ),
                                    TextField(
                                      controller: codeController,
                                      decoration: const InputDecoration(
                                          helperMaxLines: 3,
                                          helperText:
                                              'Blank for Only Arabic, 0 for Arabic, 1 for transliteration, 2 for translation. Example: 012 will have Arabic, transliteration, and translation. 02 for Arabic and translation only',
                                          labelText: 'Code'),
                                    ),
                                    TextField(
                                      controller: orderController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                        signed: true,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Order',
                                        helperText:
                                            'Custom list order for this zikr',
                                      ),
                                    ),
                                    TextField(
                                      controller: meritsController,
                                      decoration: const InputDecoration(
                                          labelText: 'Merits'),
                                      maxLines: null,
                                    ),
                                    TextField(
                                      controller: dataController,
                                      decoration: const InputDecoration(
                                          labelText: 'Data'),
                                      maxLines: null,
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: _addTabField,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add Tab'),
                                    ),
                                    for (int i = 0;
                                        i < tabControllers.length;
                                        i++)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: TextField(
                                          controller: tabControllers[i],
                                          decoration: InputDecoration(
                                            labelText: 'Tab ${i + 1}',
                                            helperText:
                                                'First line becomes the tab title',
                                          ),
                                          maxLines: null,
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  if (hasMerits)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: TextButton.icon(
                                          onPressed: _showMeritsSheet,
                                          label: const Text(
                                            'Merits',
                                            style: TextStyle(
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            visualDensity:
                                                VisualDensity.compact,
                                            alignment: Alignment.centerLeft,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        if (showTabHeaders)
                                          Container(
                                            width: double.infinity,
                                            margin: const EdgeInsets.only(
                                                bottom: 20),
                                            child: LayoutBuilder(
                                              builder: (context, constraints) {
                                                return SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  child: ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                      minWidth:
                                                          constraints.maxWidth,
                                                    ),
                                                    child: Center(
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: List.generate(
                                                          tabContents.length,
                                                          (index) {
                                                            final isSelected =
                                                                index ==
                                                                    _selectedTabIndex;
                                                            return Padding(
                                                              key:
                                                                  _tabHeaderKeys[
                                                                      index],
                                                              padding:
                                                                  EdgeInsets
                                                                      .only(
                                                                right: index ==
                                                                        tabContents.length -
                                                                            1
                                                                    ? 0
                                                                    : 12,
                                                              ),
                                                              child: Material(
                                                                color: isSelected
                                                                    ? Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .secondaryContainer
                                                                    : Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .surfaceContainerHighest
                                                                        .withValues(
                                                                            alpha:
                                                                                0.45),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            18),
                                                                elevation:
                                                                    isSelected
                                                                        ? 2
                                                                        : 0,
                                                                child: InkWell(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              18),
                                                                  onTap: () =>
                                                                      _animateToTab(
                                                                          index),
                                                                  child:
                                                                      Padding(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .symmetric(
                                                                      horizontal:
                                                                          18,
                                                                      vertical:
                                                                          10,
                                                                    ),
                                                                    child: Text(
                                                                      _getTabHeader(
                                                                        tabContents[
                                                                            index],
                                                                        index,
                                                                      ),
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            15,
                                                                        fontWeight: isSelected
                                                                            ? FontWeight.w600
                                                                            : FontWeight.w500,
                                                                        color: isSelected
                                                                            ? Theme.of(context).colorScheme.onSecondaryContainer
                                                                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        Expanded(
                                          child: PageView.builder(
                                            controller: _pageController,
                                            itemCount: tabContents.length,
                                            onPageChanged: (index) {
                                              setState(() {
                                                _selectedTabIndex = index;
                                              });
                                              _centerSelectedTab();
                                            },
                                            itemBuilder: (context, index) =>
                                                _buildTabContent(
                                              tabContents[index],
                                              _tabScrollControllers[index],
                                              hideHeaderLine: showTabHeaders,
                                            ),
                                            pageSnapping: true,
                                            physics: const PageScrollPhysics(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
            // Counter overlay
            ValueListenableBuilder<bool>(
              valueListenable: showCounter,
              builder: (context, visible, _) {
                if (!visible) return const SizedBox.shrink();
                return ValueListenableBuilder<Offset>(
                  valueListenable: counterOffset,
                  builder: (context, offset, __) => Positioned(
                    left: offset.dx,
                    top: offset.dy,
                    child: Draggable(
                      feedback: Material(
                        color: Colors.transparent,
                        child: ZikrCounter(zikrId: widget.item.uid),
                      ),
                      childWhenDragging: const SizedBox.shrink(),
                      onDragEnd: (details) {
                        counterOffset.value = details.offset;
                      },
                      child: Stack(
                        children: [
                          ZikrCounter(zikrId: widget.item.uid),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => showCounter.value = false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  _ParsedZikrContent _parseContent(
    String content, {
    required bool hideHeaderLine,
  }) {
    final split = content.split('\n');
    if (hideHeaderLine && split.isNotEmpty) {
      split.removeAt(0);
    }
    final arabicCodes = <int>{};

    for (int i = 0, n = split.length; i < n; i++) {
      split[i] = split[i].trim();
      if (split[i].isEmpty) continue;
      if (isArabic(split[i])) {
        arabicCodes.add(i);
      }
    }

    return _ParsedZikrContent(
      lines: split,
      arabicCodes: arabicCodes,
      transliCodes: _generateEnglishCodes(arabicCodes, true),
      translaCodes: _generateEnglishCodes(arabicCodes, false),
    );
  }

  bool isArabic(String s) {
    for (int i = 0, n = s.length; i < n && i < 35;) {
      int c = s.codeUnitAt(i);
      if (c >= 0x0600 && c <= 0x06E0) {
        return true;
      }
      i += c.bitLength;
    }
    return false;
  }

  Set<int> _generateEnglishCodes(Set<int> arabicCodes, bool transliteration) {
    final englishCodes = <int>{};
    String code = zikrData?['code'];
    if (code == "102") {
      for (final i in arabicCodes) {
        englishCodes.add(transliteration ? i - 1 : i + 1);
      }
    } else if (code == "012") {
      for (final i in arabicCodes) {
        englishCodes.add(transliteration ? i + 1 : i + 2);
      }
    } else if (code == "02" && !transliteration) {
      for (final i in arabicCodes) {
        englishCodes.add(i + 1);
      }
    }
    return englishCodes;
  }

  String formatArabicText(String str) {
    if (arabicFont == 'Qalam') {
      return str;
    } else {
      return str
          .replaceAll("ی", "ي")
          .replaceAll("ہ", "ه")
          .replaceAll("ک", "ك")
          .replaceAll("ۃ", "ة")
          .replaceAll('الله', 'اللّٰه');
    }
  }

  void refreshState() {
    arabicStyle = TextStyle(
        fontFamily: arabicFont, fontSize: arabicFontSize, letterSpacing: 0);
    transliStyle =
        TextStyle(fontWeight: FontWeight.bold, fontSize: englishFontSize);
    setState(() {});
  }
}

class _ParsedZikrContent {
  final List<String> lines;
  final Set<int> arabicCodes;
  final Set<int> transliCodes;
  final Set<int> translaCodes;

  const _ParsedZikrContent({
    required this.lines,
    required this.arabicCodes,
    required this.transliCodes,
    required this.translaCodes,
  });
}
