import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CategoryPage extends StatefulWidget {
  @override
  _CategoryPageState createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('category').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          categories = List<String>.from(doc.data()!['categories'] ?? []);
        });
      }
    }
  }

  Future<void> _addCategory() async {
    final TextEditingController categoryController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Category'),
        content: TextField(
          controller: categoryController,
          decoration: InputDecoration(labelText: 'Category Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newCategory = categoryController.text.trim();
              if (newCategory.isNotEmpty) {
                final user = _auth.currentUser;
                if (user != null) {
                  final userDoc = _firestore.collection('category').doc(user.uid);

                  await userDoc.set({
                    'userId': user.uid,
                    'categories': FieldValue.arrayUnion([newCategory]),
                  }, SetOptions(merge: true));

                  Navigator.of(context).pop();
                  _loadCategories();
                  print('Category added to Firestore');
                }
              }
            },
            child: Text('ADD'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteCategory(String categoryName) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete "$categoryName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // Cancel
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close the dialog
              final user = _auth.currentUser;
              if (user != null) {
                final userDoc = _firestore.collection('category').doc(user.uid);
                await userDoc.update({
                  'categories': FieldValue.arrayRemove([categoryName]),
                });
                _loadCategories();
                print('Category deleted from Firestore');

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Category "$categoryName" deleted')),
                );
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Categories'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _addCategory,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Color(0xFF006FB9),
                  ),
                  child: Text('ADD'),
                ),
              ],
            ),
            SizedBox(height: 10),
            if (categories.isEmpty)
              Center(child: Text('No categories added yet')),
            ...categories.map((name) => CategoryCard(
              name,
              onDelete: () => _confirmDeleteCategory(name),
            )).toList(),
          ],
        ),
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  final String categoryName;
  final VoidCallback onDelete;

  CategoryCard(this.categoryName, {required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4.0,
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        contentPadding: EdgeInsets.all(16.0),
        title: Text(
          categoryName,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
