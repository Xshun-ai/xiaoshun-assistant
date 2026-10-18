import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../ui/components/app_card.dart';
import 'debug/app_info_debug_page.dart';
import 'debug/cache_debug_page.dart';
import 'debug/debug_shared.dart';
import 'debug/log_tools_debug_page.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  int _currentTabIndex = 0;

  Future<void> _openDebugPage(Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => page));
  }

  Widget _buildHubList({required Key key, required List<Widget> children}) {
    return ListView(
      key: key,
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [...children, const SizedBox(height: 28)],
    );
  }

  Widget _buildInfoHubTab() {
    return _buildHubList(
      key: const Key('debug-hub-info'),
      children: [
        const DebugSectionTitle(
          title: '信息调试',
          subtitle: '按调试主题进入独立页面，避免所有内容堆在同一个长列表中。',
        ),
        AppCard(
          child: Column(
            children: [
              DebugActionTile(
                tileKey: const Key('debug-entry-app-info'),
                title: '应用与环境',
                subtitle: '查看版本、账号、设备平台和安全摘要。',
                onTap: () => _openDebugPage(const AppInfoDebugPage()),
                icon: Icons.info_outline_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocalHubTab() {
    return _buildHubList(
      key: const Key('debug-hub-local'),
      children: [
        const DebugSectionTitle(
          title: '本地调试',
          subtitle: '把缓存、会话和日志工具分别拆开，方便继续增加其他本地调试能力。',
        ),
        AppCard(
          child: Column(
            children: [
              DebugActionTile(
                tileKey: const Key('debug-entry-cache-tools'),
                title: '缓存与会话',
                subtitle: '处理缓存清理和会话重置相关调试操作。',
                onTap: () => _openDebugPage(const CacheDebugPage()),
                icon: Icons.delete_forever_outlined,
              ),
              const Divider(height: 1),
              DebugActionTile(
                tileKey: const Key('debug-entry-log-tools'),
                title: '日志工具',
                subtitle: '查看、复制和清空最近的本地运行日志。',
                onTap: () => _openDebugPage(const LogToolsDebugPage()),
                icon: Icons.receipt_long_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '调试界面',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildInfoHubTab(),
          _buildLocalHubTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        key: const Key('debug-navigation-bar'),
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.info_outline, key: Key('debug-nav-info')),
            selectedIcon: Icon(Icons.info),
            label: '信息',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined, key: Key('debug-nav-local')),
            selectedIcon: Icon(Icons.build),
            label: '本地',
          ),
        ],
      ),
    );
  }
}
