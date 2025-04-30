import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<String>> getCategories() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final doc = await _firestore.collection('category').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        return List<String>.from(doc.data()!['categories'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }
}

class Favorite {
  final String id;
  final String userId;
  final String name;
  final String category;
  final String type; // Added type field

  Favorite({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.type, // Added type parameter
  });

  factory Favorite.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Favorite(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      type: data['type'] ?? '', // Extract type from Firestore
    );
  }
}

class FavoritePage extends StatefulWidget {
  @override
  _FavoritePageState createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CategoryService _categoryService = CategoryService();
  List<Favorite> favorites = [];
  bool _isLoading = true;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final querySnapshot = await _firestore
          .collection('favorites')
          .where('userId', isEqualTo: user.uid)
          .get();

      setState(() {
        favorites = querySnapshot.docs
            .map((doc) => Favorite.fromFirestore(doc))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading favorites: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addFavorite(String name, String category, String type) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('favorites').add({
        'userId': user.uid,
        'name': name,
        'category': category,
        'type': type, // Store the type in Firestore
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _loadFavorites();
    } catch (e) {
      print('Error adding favorite: $e');
    }
  }

  Future<void> _deleteFavorite(String id) async {
    try {
      await _firestore.collection('favorites').doc(id).delete();
      await _loadFavorites();
    } catch (e) {
      print('Error deleting favorite: $e');
    }
  }

  void _showAddFavoriteDialog() async {
    final TextEditingController nameController = TextEditingController();
    final categories = await _categoryService.getCategories();
    String selectedType = 'Income'; // Default to Income
    bool showCategoryDropdown = false; // Initially hidden for Income

    // Ensure we have at least the basic categories
    if (!categories.contains('Income')) categories.add('Income');
    if (!categories.contains('Expense')) categories.add('Expense');
    if (!categories.contains('Other')) categories.add('Other');

    // Sort the middle categories
    categories.sort((a, b) => a.compareTo(b));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add New Favorite'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: 'Reference'),
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Income', 'Expense'].map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedType = newValue!;
                          showCategoryDropdown = newValue == 'Expense';
                          if (!showCategoryDropdown) {
                            _selectedCategory = null;
                          }
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    if (showCategoryDropdown)
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: categories.where((c) => c != 'Income').map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCategory = newValue;
                          });
                        },
                        validator: (value) =>
                        value == null ? 'Please select a category' : null,
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _selectedCategory = null;
                    Navigator.pop(context);
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty &&
                        (selectedType == 'Income' ||
                            (selectedType == 'Expense' && _selectedCategory != null))) {
                      Navigator.pop(context);
                      await _addFavorite(
                        nameController.text,
                        selectedType == 'Income' ? 'Income' : _selectedCategory!,
                        selectedType, // Pass the type to _addFavorite
                      );
                      setState(() {
                        _selectedCategory = null;
                      });
                    }
                  },
                  child: Text('ADD'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditFavoriteDialog(Favorite favorite) {
    final TextEditingController amountController = TextEditingController();
    final DateTime currentDate = DateTime.now();
    DateTime selectedDate = currentDate;
    final TextEditingController dateController = TextEditingController(
      text: currentDate.toLocal().toString().split(' ')[0],
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Center(child: Text(favorite.name)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type: ${favorite.type}'),
              SizedBox(height: 10),
              Text('Category: ${favorite.category}'),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Date',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (picked != null && picked != selectedDate) {
                          selectedDate = picked;
                          dateController.text = picked.toLocal().toString().split(' ')[0];
                        }
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              TextField(
                controller: amountController,
                decoration: InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (amountController.text.isNotEmpty) {
                  try {
                    final double amount = double.parse(amountController.text);
                    final user = _auth.currentUser;
                    if (user == null) return;

                    // Create transaction in Firestore
                    await _firestore.collection('transactions').add({
                      'userId': user.uid,
                      'amount': amount,
                      'category': favorite.category,
                      'description': favorite.name,
                      'type': favorite.type,
                      'date': Timestamp.fromDate(selectedDate),
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Transaction added successfully'),
                        backgroundColor: Colors.black,
                      ),
                    );
                  } catch (e) {
                    print('Error creating transaction: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to add transaction: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
                Navigator.pop(context);
              },
              child: Text('ADD'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(String id) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this favorite?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteFavorite(id);
              },
              child: Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Favorites'),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _showAddFavoriteDialog,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Color(0xFF006FB9),
                  ),
                  child: Text('ADD'),
                ),
              ],
            ),
            SizedBox(height: 10),
            if (favorites.isEmpty)
              Center(child: Text('No favorites added yet')),
            ...favorites.map((favorite) {
              return GestureDetector(
                onTap: () => _showEditFavoriteDialog(favorite),
                child: FavoriteCard(
                  favorite.name,
                  favorite.category,
                  favorite.type, // Pass the type to FavoriteCard
                  onDelete: () => _showDeleteConfirmation(favorite.id),
                ),
              );
            }).toList(),
          ],
        ),
      ),
      // Bottom navigation bar has been removed
    );
  }
}

class FavoriteCard extends StatelessWidget {
  final String name;
  final String category;
  final String type; // Added type field
  final VoidCallback onDelete;

  FavoriteCard(this.name, this.category, this.type, {required this.onDelete}); // Updated constructor

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4.0,
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        contentPadding: EdgeInsets.all(16.0),
        title: Text(
          name,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type: $type', // Display the type
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'Category: $category',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        ),
      ),
    );
  }
}