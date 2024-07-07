import 'dart:async';
import 'dart:io';

import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ConnectionsFragment extends StatefulWidget {
  const ConnectionsFragment({super.key});

  @override
  State<ConnectionsFragment> createState() => _ConnectionsFragmentState();
}

class _ConnectionsFragmentState extends State<ConnectionsFragment> {
  final connectionsNotifier =
      ValueNotifier<ConnectionsAndKeywords>(const ConnectionsAndKeywords());
  final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );

  Timer? timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      connectionsNotifier.value = connectionsNotifier.value
          .copyWith(connections: clashCore.getConnections());
      if (timer != null) {
        timer?.cancel();
        timer = null;
      }
      timer = Timer.periodic(
        const Duration(seconds: 1),
        (timer) {
          connectionsNotifier.value = connectionsNotifier.value
              .copyWith(connections: clashCore.getConnections());
        },
      );
    });
  }

  _initActions() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        final commonScaffoldState =
            context.findAncestorStateOfType<CommonScaffoldState>();
        commonScaffoldState?.actions = [
          IconButton(
            onPressed: () {
              showSearch(
                context: context,
                delegate: ConnectionsSearchDelegate(
                  state: connectionsNotifier.value,
                ),
              );
            },
            icon: const Icon(Icons.search),
          ),
          const SizedBox(
            width: 8,
          )
        ];
      },
    );
  }

  _addKeyword(String keyword) {
    final isContains = connectionsNotifier.value.keywords.contains(keyword);
    if (isContains) return;
    final keywords = List<String>.from(connectionsNotifier.value.keywords)
      ..add(keyword);
    connectionsNotifier.value = connectionsNotifier.value.copyWith(
      keywords: keywords,
    );
  }

  _deleteKeyword(String keyword) {
    final isContains = connectionsNotifier.value.keywords.contains(keyword);
    if (!isContains) return;
    final keywords = List<String>.from(connectionsNotifier.value.keywords)
      ..remove(keyword);
    connectionsNotifier.value = connectionsNotifier.value.copyWith(
      keywords: keywords,
    );
  }

  _handleBlockConnection(String id) {
    clashCore.closeConnections(id);
    connectionsNotifier.value = connectionsNotifier.value
        .copyWith(connections: clashCore.getConnections());
  }

  @override
  void dispose() {
    super.dispose();
    timer?.cancel();
    connectionsNotifier.dispose();
    _scrollController.dispose();
    timer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppState, bool?>(
      selector: (_, appState) =>
          appState.currentLabel == 'connections' ||
          appState.viewMode == ViewMode.mobile &&
              appState.currentLabel == "tools",
      builder: (_, isCurrent, child) {
        if (isCurrent == null || isCurrent) {
          _initActions();
        }
        return child!;
      },
      child: ValueListenableBuilder<ConnectionsAndKeywords>(
        valueListenable: connectionsNotifier,
        builder: (_, state, __) {
          var connections = state.filteredConnections;
          if (connections.isEmpty) {
            return NullStatus(
              label: appLocalizations.nullConnectionsDesc,
            );
          }
          connections = connections.reversed.toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.keywords.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Wrap(
                    runSpacing: 6,
                    spacing: 6,
                    children: [
                      for (final keyword in state.keywords)
                        CommonChip(
                          label: keyword,
                          type: ChipType.delete,
                          onPressed: () {
                            _deleteKeyword(keyword);
                          },
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  itemBuilder: (_, index) {
                    final connection = connections[index];
                    return ConnectionItem(
                      key: Key(connection.id),
                      connection: connection,
                      onClick: _addKeyword,
                      onBlock: _handleBlockConnection,
                    );
                  },
                  separatorBuilder: (BuildContext context, int index) {
                    return const Divider(
                      height: 0,
                    );
                  },
                  itemCount: connections.length,
                ),
              )
            ],
          );
        },
      ),
    );
  }
}

class ConnectionItem extends StatelessWidget {
  final Connection connection;
  final Function(String)? onClick;
  final Function(String)? onBlock;

  const ConnectionItem({
    super.key,
    required this.connection,
    this.onClick,
    this.onBlock,
  });

  Future<ImageProvider?> _getPackageIcon(Connection connection) async {
    return await app?.getPackageIcon(connection.metadata.process);
  }

  String _getRequestText(Metadata metadata) {
    var text = "${metadata.network}://";
    final ips = [
      metadata.host,
      metadata.destinationIP,
    ].where((ip) => ip.isNotEmpty);
    text += ips.join("/");
    text += ":${metadata.destinationPort}";
    return text;
  }

  String _getSourceText(Connection connection) {
    final metadata = connection.metadata;
    if (metadata.process.isEmpty) {
      return connection.start.lastUpdateTimeDesc;
    }
    return "${metadata.process} · ${connection.start.lastUpdateTimeDesc}";
  }

  @override
  Widget build(BuildContext context) {
    return ListItem(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      tileTitleAlignment: ListTileTitleAlignment.titleHeight,
      leading: Platform.isAndroid
          ? Container(
              margin: const EdgeInsets.only(top: 4),
              width: 48,
              height: 48,
              child: FutureBuilder<ImageProvider?>(
                future: _getPackageIcon(connection),
                builder: (_, snapshot) {
                  if (!snapshot.hasData && snapshot.data == null) {
                    return Container();
                  } else {
                    return Image(
                      image: snapshot.data!,
                      gaplessPlayback: true,
                      width: 48,
                      height: 48,
                    );
                  }
                },
              ),
            )
          : null,
      title: Text(
        _getRequestText(connection.metadata),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            height: 8,
          ),
          Text(
            _getSourceText(connection),
          ),
          const SizedBox(
            height: 8,
          ),
          Wrap(
            runSpacing: 6,
            spacing: 6,
            children: [
              for (final chain in connection.chains)
                CommonChip(
                  label: chain,
                  onPressed: () {
                    if (onClick == null) return;
                    onClick!(chain);
                  },
                ),
            ],
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.block),
        onPressed: () {
          if (onBlock == null) return;
          onBlock!(connection.id);
        },
      ),
    );
  }
}

class ConnectionsSearchDelegate extends SearchDelegate {
  ValueNotifier<ConnectionsAndKeywords> connectionsNotifier;

  ConnectionsSearchDelegate({
    required ConnectionsAndKeywords state,
  }) : connectionsNotifier = ValueNotifier<ConnectionsAndKeywords>(state);

  get state => connectionsNotifier.value;

  List<Connection> get _results {
    final lowerQuery = query.toLowerCase().trim();
    return connectionsNotifier.value.filteredConnections.where((request) {
      final lowerNetwork = request.metadata.network.toLowerCase();
      final lowerHost = request.metadata.host.toLowerCase();
      final lowerDestinationIP = request.metadata.destinationIP.toLowerCase();
      final lowerProcess = request.metadata.process.toLowerCase();
      final lowerChains = request.chains.join("").toLowerCase();
      return lowerNetwork.contains(lowerQuery) ||
          lowerHost.contains(lowerQuery) ||
          lowerDestinationIP.contains(lowerQuery) ||
          lowerProcess.contains(lowerQuery) ||
          lowerChains.contains(lowerQuery);
    }).toList();
  }

  _addKeyword(String keyword) {
    final isContains = connectionsNotifier.value.keywords.contains(keyword);
    if (isContains) return;
    final keywords = List<String>.from(connectionsNotifier.value.keywords)
      ..add(keyword);
    connectionsNotifier.value = connectionsNotifier.value.copyWith(
      keywords: keywords,
    );
  }

  _deleteKeyword(String keyword) {
    final isContains = connectionsNotifier.value.keywords.contains(keyword);
    if (!isContains) return;
    final keywords = List<String>.from(connectionsNotifier.value.keywords)
      ..remove(keyword);
    connectionsNotifier.value = connectionsNotifier.value.copyWith(
      keywords: keywords,
    );
  }


  _handleBlockConnection(String id) {
    clashCore.closeConnections(id);
    connectionsNotifier.value = connectionsNotifier.value
        .copyWith(connections: clashCore.getConnections());
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          if (query.isEmpty) {
            close(context, null);
            return;
          }
          query = '';
        },
        icon: const Icon(Icons.clear),
      ),
      const SizedBox(
        width: 8,
      )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        close(context, null);
      },
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildSuggestions(context);
  }

  @override
  void dispose() {
    connectionsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: connectionsNotifier,
      builder: (_, __, ___) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.keywords.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Wrap(
                  runSpacing: 6,
                  spacing: 6,
                  children: [
                    for (final keyword in state.keywords)
                      CommonChip(
                        label: keyword,
                        type: ChipType.delete,
                        onPressed: () {
                          _deleteKeyword(keyword);
                        },
                      ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                itemBuilder: (_, index) {
                  final connection = _results[index];
                  return ConnectionItem(
                    key: Key(connection.id),
                    connection: connection,
                    onClick: _addKeyword,
                    onBlock: _handleBlockConnection,
                  );
                },
                separatorBuilder: (BuildContext context, int index) {
                  return const Divider(
                    height: 0,
                  );
                },
                itemCount: _results.length,
              ),
            )
          ],
        );
      },
    );
  }
}
