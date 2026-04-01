import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
//import '../../../providers/auth_provider.dart';
import '../../../providers/circles_provider.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/create_circle_dialog.dart';
import '../../widgets/join_circle_dialog.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load circles when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_){
      context.read<CirclesProvider>().loadCircles();
    });
  }

  @override
  Widget build(BuildContext context) {
   // final authProvider = context.watch<AuthProvider>();
    final circlesProvider = context.watch<CirclesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tether'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())
              );
            },
          ),
        ],
      ),
      body: circlesProvider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : circlesProvider.error != null 
          ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${circlesProvider.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => circlesProvider.loadCircles(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        : circlesProvider.circles.isEmpty
            ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.circle_outlined, size: 70, color: Colors.blueGrey),
                  const SizedBox(height: 16),
                  const Text('No circles found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Join or create a circle to get started'),
                ],
              ),
            )
          
          : RefreshIndicator(
              onRefresh: () => circlesProvider.loadCircles(),
              child: ListView.builder(
                itemCount: circlesProvider.circles.length,
                itemBuilder: (context, index) {
                  final circle = circlesProvider.circles[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(circle.name[0].toUpperCase()),
                    ),
                    title: Text(circle.name),
                    subtitle: Text(circle.description ?? 'No Description'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => ChatScreen(circle: circle),),
                      );
                    },
                  );
                },
              ),
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'create',
            child: const Icon(Icons.add),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const CreateCircleDialog(),
              );
            },
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'join',
            child: const Icon(Icons.group_add),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const JoinCircleDialog(),
              );
            },
          ),
        ],
      ),
    );
  }
}