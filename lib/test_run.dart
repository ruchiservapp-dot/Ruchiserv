import 'package:flutter/material.dart';
import 'screens/5.3_return_screen.dart';
import 'screens/5.4_kitchen_unload_screen.dart';
import 'db/database_helper.dart'; // We might need to mock this

void main() async {
  // Ensure binding
  WidgetsFlutterBinding.ensureInitialized();
  
  // We need to mock the database or the screen will fail loading.
  // Since mocking DB is hard, let's create a "TestReturnScreen" that accepts items directly 
  // OR we can just modify the screen to accept a "testMode" flag or "initialItems".
  
  // Actually, simpler: The validation logic is in the widget. 
  // Let's modify ReturnScreen/ReturnRowItem to be testable or mock the DB call.
  // The current ReturnScreen loads from DB in initState.
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Fix',
      theme: ThemeData(
        fontFamily: '', // Force default font
        useMaterial3: false,
      ),
      home: const TestSelector(),
    );
  }
}

class TestSelector extends StatelessWidget {
  const TestSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Test Screen')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text('Test Return Row (Isolated)'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TestReturnRowHost())),
            ),
          ],
        ),
      ),
    );
  }
}

// Host widget to test JUST the row logic without DB dependencies
class TestReturnRowHost extends StatefulWidget {
  const TestReturnRowHost({super.key});

  @override
  State<TestReturnRowHost> createState() => _TestReturnRowHostState();
}

class _TestReturnRowHostState extends State<TestReturnRowHost> {
  // Mock Item
  final Map<String, dynamic> item = {
    'id': 1,
    'itemName': 'Test Spoon',
    'loadedQty': 10,
    'returnedQty': 0, // start at 0
    'itemType': 'UTENSIL',
  };
  
  String _log = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Row Test - Fix Verification')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('Test Instructions: Type "18". Should show "18", not "81".'),
            const SizedBox(height: 20),
            // Use the actual ReturnRowItem from the file? 
            // We need to import it. It is in 5.3_return_screen.dart.
            // Since it is not public in the original file (it is, I made it public class ReturnRowItem), 
            // we can use it.
            ReturnRowItem(
              key: const ValueKey(1),
              item: item,
              onChanged: (val) {
                 setState(() {
                   item['returnedQty'] = val;
                   _log = 'Value changed to: $val';
                 });
              },
            ),
            const SizedBox(height: 20),
            Text('Current Model Value: ${item['returnedQty']}'),
            Text('Log: $_log'),
          ],
        ),
      ),
    );
  }
}
