import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/services.dart';

/// Home view - main screen of the app
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool _isHostMode = false;
  WSConnectionState _connectionState = WSConnectionState.disconnected;
  final WebSocketService _wsService = WebSocketService();

  StorageService get _storage => Provider.of<StorageService>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _wsService.stateChanges.listen((state) {
      setState(() {
        _connectionState = state;
      });
    });
  }

  @override
  void dispose() {
    _wsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          NavigationRail(
            selectedIndex: _isHostMode ? 0 : 1,
            onDestinationSelected: (index) {
              setState(() {
                _isHostMode = index == 0;
              });
            },
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Icon(
                    Icons.rocket_launch,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'BattleLM',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.computer),
                selectedIcon: Icon(Icons.computer),
                label: Text('Host'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.phone_android),
                selectedIcon: Icon(Icons.phone_android),
                label: Text('Client'),
              ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildConnectionIndicator(),
                      const SizedBox(height: 8),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () {
                          // Open settings
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main content
          Expanded(
            child: _isHostMode
                ? _buildHostView()
                : _buildClientView(),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionIndicator() {
    Color color;
    String text;

    switch (_connectionState) {
      case WSConnectionState.connected:
        color = Colors.green;
        text = 'Connected';
        break;
      case WSConnectionState.connecting:
      case WSConnectionState.authenticating:
        color = Colors.orange;
        text = 'Connecting';
        break;
      case WSConnectionState.error:
        color = Colors.red;
        text = 'Error';
        break;
      case WSConnectionState.disconnected:
      default:
        color = Colors.grey;
        text = 'Offline';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }

  Widget _buildHostView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dns,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Host Mode',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Running BattleLM as a host server',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 32),
          if (_connectionState == WSConnectionState.disconnected)
            ElevatedButton.icon(
              onPressed: _startHostServer,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Server'),
            )
          else
            ElevatedButton.icon(
              onPressed: _stopHostServer,
              icon: const Icon(Icons.stop),
              label: const Text('Stop Server'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Port: 8765',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildClientView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.phone_android,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Client Mode',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to a remote BattleLM host',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _connectToHost,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR'),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _enterEndpoint,
                icon: const Icon(Icons.link),
                label: const Text('Enter URL'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildPairedDevicesList(),
        ],
      ),
    );
  }

  Widget _buildPairedDevicesList() {
    return FutureBuilder<List<PairedDevice>>(
      future: _storage.loadPairedDevices(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text(
            'No paired devices',
            style: TextStyle(color: Colors.grey),
          );
        }

        final devices = snapshot.data!;
        return SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                leading: const Icon(Icons.computer),
                title: Text(device.name),
                subtitle: Text(device.endpoint),
                trailing: IconButton(
                  icon: const Icon(Icons.link),
                  onPressed: () => _connectToDevice(device),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _startHostServer() {
    // TODO: Implement host server start
    setState(() {
      // _connectionState = WSConnectionState.connecting;
    });
  }

  void _stopHostServer() {
    // TODO: Implement host server stop
    setState(() {
      // _connectionState = WSConnectionState.disconnected;
    });
  }

  void _connectToHost() {
    // TODO: Implement QR scanner
  }

  void _enterEndpoint() {
    // TODO: Implement endpoint entry dialog
  }

  void _connectToDevice(PairedDevice device) async {
    try {
      await _wsService.connect(device.endpoint);
    } catch (e) {
      // Try local endpoint if remote fails
      if (device.endpointLocal != null) {
        await _wsService.connect(device.endpointLocal!);
      }
    }
  }
}
