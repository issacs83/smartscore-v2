import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/ui_state_provider.dart';
import '../state/device_provider.dart';
import '../config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Display'),
            Tab(text: 'Devices'),
            Tab(text: 'About'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDisplaySettings(),
          _buildDeviceSettings(),
          _buildAboutSettings(),
        ],
      ),
    );
  }

  Widget _buildDisplaySettings() {
    return Consumer<UIStateProvider>(
      builder: (context, uiState, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Dark mode toggle
            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Use dark theme for reduced eye strain'),
              value: uiState.darkMode,
              onChanged: (value) {
                uiState.setDarkMode(value);
              },
            ),
            const Divider(),

            // Zoom level
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zoom Level',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('50%'),
                      Expanded(
                        child: Slider(
                          value: uiState.zoomLevel,
                          min: 0.5,
                          max: 2.0,
                          divisions: 30,
                          label: '${(uiState.zoomLevel * 100).toStringAsFixed(0)}%',
                          onChanged: (value) {
                            uiState.setZoomLevel(value);
                          },
                        ),
                      ),
                      const Text('200%'),
                    ],
                  ),
                  Text(
                    'Current: ${(uiState.zoomLevel * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(),

            // Measures per system
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Measures Per System',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<int>(
                    isExpanded: true,
                    value: uiState.measuresPerSystem,
                    items: const [1, 2, 3, 4, 5, 6]
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text('$value measures'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        uiState.setMeasuresPerSystem(value);
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(),

            // Systems per page
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Systems Per Page',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<int>(
                    isExpanded: true,
                    value: uiState.systemsPerPage,
                    items: const [1, 2, 3, 4]
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text('$value systems'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        uiState.setSystemsPerPage(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeviceSettings() {
    return Consumer<DeviceProvider>(
      builder: (context, devices, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Scan for devices button
            ElevatedButton.icon(
              onPressed: () {
                devices.scanDevices('bluetooth');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Scanning for devices...')),
                );
              },
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Scan for Devices'),
            ),
            const SizedBox(height: 24),

            // Connected devices
            Text(
              'Connected Devices',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (devices.connectedDevices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No devices connected',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                itemCount: devices.connectedDevices.length,
                itemBuilder: (context, index) {
                  final device = devices.connectedDevices[index];
                  return ListTile(
                    leading: const Icon(Icons.bluetooth_connected),
                    title: Text(device['name'] ?? 'Unknown Device'),
                    subtitle: Text(device['type'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        devices.disconnectDevice(device['id']);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Device disconnected')),
                        );
                      },
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),
            const Divider(),

            // Device features info
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supported Devices',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('• Bluetooth page turn pedals'),
                  const Text('• USB MIDI controllers'),
                  const Text('• Keyboard shortcuts (Page Up/Down)'),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text(
              'Page Turn Mode',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Manual (Stage 1 Only)',
              style: TextStyle(color: Colors.grey),
            ),
            const Text(
              'Automatic page turning based on audio will be available in Stage 2.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAboutSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          title: const Text('App Version'),
          subtitle: Text(appVersion),
        ),
        const Divider(),
        ListTile(
          title: const Text('App Name'),
          subtitle: const Text(appName),
        ),
        const Divider(),
        ListTile(
          title: const Text('Build Flavor'),
          subtitle: Text(buildFlavor.toString().split('.').last.toUpperCase()),
        ),
        const SizedBox(height: 24),
        Text(
          'Credits',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text('SmartScore is developed by the Music Technology Lab.'),
        const SizedBox(height: 24),
        Text(
          'Legal',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'SmartScore is licensed under the MIT License. '
          'See LICENSE file for details.',
        ),
        const SizedBox(height: 24),
        Text(
          'Performance Targets (Stage 1)',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Cold Startup: ${PerformanceTargets.coldStartupMs}ms',
        ),
        Text(
          'Route Navigation: ${PerformanceTargets.routeNavigationMs}ms',
        ),
        Text(
          'Page Render: ${PerformanceTargets.pageRenderMs}ms',
        ),
        Text(
          'Device Action: ${PerformanceTargets.deviceActionMs}ms',
        ),
      ],
    );
  }
}
