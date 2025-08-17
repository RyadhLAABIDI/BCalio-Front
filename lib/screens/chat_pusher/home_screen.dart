import 'package:bcalio/controllers/user_controller.dart';
import 'package:bcalio/models/true_user_model.dart';
import 'package:bcalio/screens/chat_pusher/chat_screen.dart';
import 'package:bcalio/services/user_api_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';

class HomeScreen extends StatefulWidget {
  final String currentUserId; // ID de l'utilisateur actuel

  const HomeScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<User> _users = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  final UserApiService userApiService = UserApiService();

  Future<void> _fetchUsers() async {
    try {
      final token = await Get.find<UserController>().getToken();
      final users = await userApiService.fetchUsers(token!);
      setState(() {
        _users =
            users.where((user) => user.id != widget.currentUserId).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat App')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text(user.name[0])),
                      title: Text(user.name),
                      subtitle: Text(user.name),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              currentUserId: widget.currentUserId,
                              recipientUser: user,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
