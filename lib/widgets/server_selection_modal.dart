import 'package:flutter/material.dart';
import '../models/episode_server.dart';

class ServerSelectionResult {
  final String serverName;
  final String category;

  ServerSelectionResult({required this.serverName, required this.category});
}

class ServerSelectionModal extends StatelessWidget {
  final EpisodeServers servers;

  const ServerSelectionModal({super.key, required this.servers});

  static Future<ServerSelectionResult?> show(
    BuildContext context,
    EpisodeServers servers,
  ) {
    return showModalBottomSheet<ServerSelectionResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ServerSelectionModal(servers: servers),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Select Server',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (servers.sub.isNotEmpty) ...[
                  _buildCategorySection(
                    context,
                    'Subbed',
                    servers.sub,
                    'sub',
                    Icons.subtitles,
                  ),
                  const SizedBox(height: 16),
                ],
                if (servers.dub.isNotEmpty) ...[
                  _buildCategorySection(
                    context,
                    'Dubbed',
                    servers.dub,
                    'dub',
                    Icons.mic,
                  ),
                  const SizedBox(height: 16),
                ],
                if (servers.raw.isNotEmpty) ...[
                  _buildCategorySection(
                    context,
                    'Raw',
                    servers.raw,
                    'raw',
                    Icons.movie,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    String title,
    List<EpisodeServer> serverList,
    String category,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: serverList.map((server) {
            return ActionChip(
              label: Text(server.serverName),
              onPressed: () {
                Navigator.of(context).pop(
                  ServerSelectionResult(
                    serverName: server.serverName,
                    category: category,
                  ),
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
