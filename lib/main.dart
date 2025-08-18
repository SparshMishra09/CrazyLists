import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:lottie/lottie.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import 'package:to_do_list/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.init();
  
  // Request notification permission
  await notificationService.requestPermission();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Crazy To-Do List',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A1B9A),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isLoading = true;
  User? _user;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _animationController.repeat(reverse: true);
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    try {
      // Check if user is already signed in
      _user = FirebaseAuth.instance.currentUser;
      
      if (_user == null) {
        // Sign in anonymously if no user is signed in
        final userCredential = await FirebaseAuth.instance.signInAnonymously();
        _user = userCredential.user;
      }
      
      // Request notification permission
      await _notificationService.requestPermission();
    } catch (e) {
      // Handle any errors
      debugPrint('Error signing in: $e');
    } finally {
      // Update state regardless of outcome
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.network(
                'https://lottie.host/5ccbf881-8c1c-4e1d-9d9a-a9a0b7196c66/sXBfYSU9Jj.json',
                width: 200,
                height: 200,
              ),
              const SizedBox(height: 20),
              Text(
                'Preparing Your Crazy To-Do List...',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ).animate(controller: _animationController)
                .fadeIn(duration: const Duration(milliseconds: 500))
                .then(delay: const Duration(milliseconds: 200))
                .slideY(begin: 0.2, end: 0),
            ],
          ),
        ),
      );
    }

    return const TodoListScreen();
  }
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final TextEditingController _taskController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 1));
  final NotificationService _notificationService = NotificationService();
  
  String? _userId;
  bool _isAddingTask = false;
  final List<Color> _taskColors = [
    const Color(0xFF6A1B9A),
    const Color(0xFF1E88E5),
    const Color(0xFFD81B60),
    const Color(0xFF43A047),
    const Color(0xFFFF6F00),
  ];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
  }

  @override
  void dispose() {
    _taskController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // Add a new task to Firestore
  Future<void> _addTask(String title) async {
    if (_userId == null || title.trim().isEmpty) return;

    setState(() {
      _isAddingTask = true;
    });

    try {
      // Add task to Firestore
      DocumentReference docRef = await _firestore.collection('users').doc(_userId).collection('tasks').add({
        'title': title,
        'is_completed': false,
        'created_at': FieldValue.serverTimestamp(),
        'color': _taskColors[_random.nextInt(_taskColors.length)].value,
      });
      
      // Schedule notification for 5 hours later
      await _notificationService.scheduleTaskReminder(docRef.id, title);
      
      _taskController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding task: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingTask = false;
        });
      }
    }
  }

  // Toggle task completion status
  Future<void> _toggleTaskStatus(String taskId, bool currentStatus) async {
    if (_userId == null) return;

    try {
      await _firestore.collection('users').doc(_userId).collection('tasks').doc(taskId).update({
        'is_completed': !currentStatus,
      });

      // Play confetti animation when task is completed
      if (!currentStatus) {
        _confettiController.play();
        // Cancel notification when task is completed
        await _notificationService.cancelTaskReminder(taskId);
      } else {
        // Re-schedule notification if task is marked as incomplete
        DocumentSnapshot taskDoc = await _firestore.collection('users').doc(_userId).collection('tasks').doc(taskId).get();
        if (taskDoc.exists) {
          final taskData = taskDoc.data() as Map<String, dynamic>;
          final title = taskData['title'] as String;
          await _notificationService.scheduleTaskReminder(taskId, title);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating task: $e')),
      );
    }
  }

  // Delete a task
  Future<void> _deleteTask(String taskId) async {
    if (_userId == null) return;

    try {
      await _firestore.collection('users').doc(_userId).collection('tasks').doc(taskId).delete();
      // Cancel notification when task is deleted
      await _notificationService.cancelTaskReminder(taskId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting task: $e')),
      );
    }
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'CRAZY TO-DO LIST',
          style: GoogleFonts.permanentMarker(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ).animate()
          .fadeIn(duration: const Duration(milliseconds: 600))
          .then(delay: const Duration(milliseconds: 200))
          .slideY(begin: -0.2, end: 0),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                  Color(0xFF0F3460),
                  Color(0xFF541690),
                ],
              ),
            ),
          ),
          
          // Animated background shapes
          Positioned(
            top: MediaQuery.of(context).size.height * 0.1,
            left: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
              ),
            ).animate()
              .fadeIn(duration: const Duration(milliseconds: 800))
              .then(delay: const Duration(milliseconds: 400))
              .moveY(begin: 100, end: 0)
              .then()
              .animate(onPlay: (controller) => controller.repeat())
              .moveY(begin: 0, end: 20, duration: const Duration(seconds: 2))
              .then()
              .moveY(begin: 20, end: 0, duration: const Duration(seconds: 2)),
          ),
          
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.2,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
            ).animate()
              .fadeIn(duration: const Duration(milliseconds: 800))
              .then(delay: const Duration(milliseconds: 600))
              .moveY(begin: 100, end: 0)
              .then()
              .animate(onPlay: (controller) => controller.repeat())
              .moveY(begin: 0, end: -20, duration: const Duration(seconds: 3))
              .then()
              .moveY(begin: -20, end: 0, duration: const Duration(seconds: 3)),
          ),
          
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Confetti effect
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirection: pi / 2,
                    maxBlastForce: 5,
                    minBlastForce: 1,
                    emissionFrequency: 0.05,
                    numberOfParticles: 20,
                    gravity: 0.2,
                    colors: const [
                      Colors.pink,
                      Colors.purple,
                      Colors.blue,
                      Colors.green,
                      Colors.orange,
                      Colors.yellow,
                    ],
                  ),
                ),
                
                // Task input field
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _taskController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Add a crazy task...',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (value) {
                                if (value.isNotEmpty) {
                                  _addTask(value);
                                }
                              },
                            ),
                          ),
                          _isAddingTask
                              ? const CircularProgressIndicator()
                              : IconButton(
                                  icon: const Icon(Icons.add_circle, color: Colors.white, size: 30),
                                  onPressed: () {
                                    if (_taskController.text.isNotEmpty) {
                                      _addTask(_taskController.text);
                                    }
                                  },
                                ).animate()
                                  .scale(duration: const Duration(milliseconds: 200)),
                        ],
                      ),
                    ),
                  ).animate()
                    .fadeIn(duration: const Duration(milliseconds: 800))
                    .slideY(begin: 0.5, end: 0),
                ),
                
                // Task list
                Expanded(
                  child: _userId == null
                      ? const Center(child: Text('Not authenticated'))
                      : StreamBuilder<QuerySnapshot>(
                          stream: _firestore
                              .collection('users')
                              .doc(_userId)
                              .collection('tasks')
                              .orderBy('created_at', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError) {
                              return Center(child: Text('Error: ${snapshot.error}'));
                            }

                            final tasks = snapshot.data?.docs ?? [];

                            if (tasks.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Lottie.network(
                                      'https://lottie.host/c2d08d8e-d5b9-4c2c-af0e-d5e1fc51c789/hVBgzSLQQi.json',
                                      width: 200,
                                      height: 200,
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'No tasks yet! Add something crazy!',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: tasks.length,
                              padding: const EdgeInsets.all(16),
                              itemBuilder: (context, index) {
                                final task = tasks[index];
                                final taskData = task.data() as Map<String, dynamic>;
                                final taskId = task.id;
                                final title = taskData['title'] as String;
                                final isCompleted = taskData['is_completed'] as bool;
                                final color = Color(taskData['color'] as int);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Slidable(
                                    endActionPane: ActionPane(
                                      motion: const ScrollMotion(),
                                      children: [
                                        SlidableAction(
                                          onPressed: (_) => _deleteTask(taskId),
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          icon: Icons.delete,
                                          label: 'Delete',
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            color.withOpacity(0.7),
                                            color.withOpacity(0.4),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withOpacity(0.3),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 8,
                                        ),
                                        leading: Checkbox(
                                          value: isCompleted,
                                          onChanged: (value) => _toggleTaskStatus(taskId, isCompleted),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          checkColor: Colors.white,
                                          fillColor: WidgetStateProperty.resolveWith<Color>(
                                            (Set<WidgetState> states) {
                                              if (states.contains(WidgetState.selected)) {
                                                return Colors.green;
                                              }
                                              return Colors.white.withOpacity(0.3);
                                            },
                                          ),
                                        ),
                                        title: Text(
                                          title,
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            decoration: isCompleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                            decorationThickness: 2,
                                          ),
                                        ),
                                        trailing: Icon(
                                          Icons.arrow_back_ios,
                                          color: Colors.white.withOpacity(0.7),
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ).animate()
                                    .fadeIn(duration: const Duration(milliseconds: 400), delay: Duration(milliseconds: index * 100))
                                    .slideX(begin: 0.2, end: 0),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
