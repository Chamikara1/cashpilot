import 'package:computing_group/analyticspage.dart';
import 'package:computing_group/morepage.dart';
import 'package:computing_group/transactionpage.dart';
import 'package:flutter/material.dart';

// Example Favorite model (you can extend it with more fields)
class Favorite {
  final String name;
  final String category;

  Favorite({required this.name, required this.category});
}

class FavoritePage extends StatefulWidget {
  @override
  _FavoritePageState createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  List<String> selectedCategories = [];

  // Sample data for favorites
  List<Favorite> favorites = [
    Favorite(name: 'Starbucks', category: 'Food'),
    Favorite(name: 'Cinema', category: 'Entertainment'),
    Favorite(name: 'Uber', category: 'Transport'),
  ];

  // Function to handle adding a new favorite
  void _addFavorite() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController categoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add New Favorite'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Reference'),
              ),
              TextField(
                controller: categoryController,
                decoration: InputDecoration(labelText: 'Category'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Add the new favorite if the fields are not empty
                if (nameController.text.isNotEmpty &&
                    categoryController.text.isNotEmpty) {
                  setState(() {
                    favorites.add(Favorite(
                      name: nameController.text,
                      category: categoryController.text,
                    ));
                  });
                  Navigator.of(context).pop(); // Close the dialog
                  print('Favorite added');
                } else {
                  // You can show a message if the fields are empty
                  print('Please fill in both fields');
                }
              },
              child: Text('ADD'),
            ),
          ],
        );
      },
    );
  }

  void _editFavorite(Favorite favorite) {
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Center(child: Text(favorite.name)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display category
              Text('Category: ${favorite.category}'),
              SizedBox(height: 10),
              // Display the current date (only the date, no time)
              Text('Date: ${DateTime.now().toLocal().toString().split(' ')[0]}'),
              SizedBox(height: 10),
              // Input field for amount
              TextField(
                controller: amountController,
                decoration: InputDecoration(labelText: 'Amount'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Handle the adding logic here
                if (amountController.text.isNotEmpty) {
                  print('Amount added: ${amountController.text}');
                } else {
                  print('Please enter an amount');
                }
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('ADD'),
            ),
          ],
        );
      },
    );
  }

  // Function to delete a favorite with confirmation
  void _deleteFavorite(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this favorite?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  favorites.removeAt(index);
                });
                Navigator.of(context).pop(); // Close the dialog
                print('Favorite deleted');
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Add button aligned to the right
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _addFavorite,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white, backgroundColor: Color(0xFF006FB9), // Text color set to white
                  ),
                  child: Text('ADD'),
                ),
              ],
            ),

            // Favorites Cards
            SizedBox(height: 10),
            if (favorites.isEmpty)
              Center(child: Text('No favorites added yet')),
            ...favorites.map((favorite) {
              int index = favorites.indexOf(favorite);
              return GestureDetector(
                onTap: () => _editFavorite(favorite),
                child: FavoriteCard(
                  favorite.name,
                  favorite.category,
                  onDelete: () => _deleteFavorite(index),
                ),
              );
            }).toList(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color(0xFF006FB9),
        elevation: 10,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
        onTap: (index) {
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AnalyticsPage()),
            );
            print("Analytics Clicked");
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TransactionPage()),
            );
            print("Transactions Clicked");
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MorePage()),
            );
            print("More Clicked");
          }
        },
      ),
    );
  }
}

class FavoriteCard extends StatelessWidget {
  final String name;
  final String category;
  final VoidCallback onDelete;

  FavoriteCard(this.name, this.category, {required this.onDelete});

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
        subtitle: Text(
          category,
          style: TextStyle(fontSize: 14),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete, // Handle delete action
        ),
      ),
    );
  }
}
