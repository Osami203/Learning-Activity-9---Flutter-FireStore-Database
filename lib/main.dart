import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firestore List',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF2962FF)),
      home: const ItemListApp(),
    );
  }
}

class ItemListApp extends StatefulWidget {
  const ItemListApp({super.key});

  @override
  State<ItemListApp> createState() => _ItemListAppState();
}

class Item {
  final String name;
  final DateTime createdAt;

  Item({required this.name, required this.createdAt});

  Map<String, dynamic> toFirestore() {
    return {'item_name': name, 'created_at': Timestamp.fromDate(createdAt)};
  }

  factory Item.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return Item(
      name: data['item_name'] ?? '',
      createdAt: (data['created_at'] as Timestamp).toDate(),
    );
  }
}

class _ItemListAppState extends State<ItemListApp> {
  // Controller for the input field
  final TextEditingController _newItemTextField = TextEditingController();

  // Local list of items (Phase 1: local; Phase 2: Firestore stream replaces this).
  late final CollectionReference<Item> items;

  Widget nameTextField() {
    return Expanded(
      child: TextField(
        controller: _newItemTextField,
        onSubmitted: (_) => _addItem(),
        decoration: const InputDecoration(
          labelText: 'New Item Name',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget addButtonWidget() {
    return FilledButton(onPressed: _addItem, child: const Text('Add'));
  }

  Widget itemInputWidget() {
    return Row(
      children: [
        // ====== Item Name TextField ======
        nameTextField(),
        // ====== Spacer for formating ======
        const SizedBox(width: 12),
        // ====== Add Item Button ======
        addButtonWidget(),
      ],
    );
  }

  // CHANGED: add explicit type for position (int) for safety and readability.
  Widget itemTileWidget(QueryDocumentSnapshot<Item> doc) {
    final item = doc.data(); 
    return ListTile(
      leading: const Icon(Icons.check_box),
      title: Text(item.name), 
      onTap: () => _removeItemAt(doc.id),
    );
  }

  Widget itemListWidget() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot<Item>>(
        stream: items.orderBy('created_at', descending: true).snapshots(),
        builder: (context, asyncSnapshot) {
          // Error handling
          if (asyncSnapshot.hasError) {
            return const Center(child: Text('Error loading items'));
          }
          // Loading state
          if (asyncSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Empty state
          if (!asyncSnapshot.hasData || asyncSnapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No items yet. Add one!'));
          }
          // Display the list
          return ListView.builder(
            itemCount: asyncSnapshot.data!.docs.length,
            itemBuilder: (context, i) {
              final doc = asyncSnapshot.data!.docs[i];
              return Dismissible(
                key: ValueKey(doc.id),
                background: Container(color: Colors.red),
                onDismissed: (_) => _removeItemAt(doc.id),
                child: itemTileWidget(doc),
              );
            },
          );
        },
      ),
    );
  }

  // ACTION: add one item from the TextField to the local list.
  Future<void> _addItem() async {
    final newItem = _newItemTextField.text.trim();
    if (newItem.isEmpty) return;

    await items.add(Item(name: newItem, createdAt: DateTime.now()));
    _newItemTextField.clear(); // clear input field
  }

  // ACTION: remove the item at the given index.
  Future<void> _removeItemAt(String id) async {
    await items.doc(id).delete(); // remove item from list
  }

  // CHANGED: dispose controller to prevent memory leaks.
  @override
  void dispose() {
    _newItemTextField.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    items = FirebaseFirestore.instance
        .collection('ITEMS')
        .withConverter<Item>(
          fromFirestore: (snapshot, _) => Item.fromFirestore(snapshot),
          toFirestore: (item, _) =>
              item.toFirestore(), // This calls the method on Item
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firestore List Demo')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          children: [
            // ====== Item Input  ======
            itemInputWidget(),
            // ====== Spacer for formating ======
            const SizedBox(height: 24),
            itemListWidget(),
          ],
        ),
      ),
    );
  }
}
