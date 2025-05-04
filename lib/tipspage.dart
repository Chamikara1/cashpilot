import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TipsPage extends StatefulWidget {
  @override
  _TipsPageState createState() => _TipsPageState();
}

class _TipsPageState extends State<TipsPage> {
  bool isTipsAllowed = false;
  bool isLoading = true;
  bool isTipsLoading = false;
  List<Map<String, dynamic>> userDocuments = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _checkUserTipsStatus();
    _loadUserTips();
  }

  Future<void> _checkUserTipsStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final doc = await _firestore.collection('allowtips').doc('tipsusers').get();
      if (doc.exists) {
        final users = List<String>.from(doc.data()?['users'] ?? []);
        setState(() {
          isTipsAllowed = users.contains(user.uid);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error checking tips status: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadUserTips() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      isTipsLoading = true;
      userDocuments.clear();
    });

    try {
      final querySnapshot = await _firestore
          .collection('ai_analysis')
          .where('userId', isEqualTo: user.uid)
          .orderBy('date', descending: true)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        List<Map<String, dynamic>> documents = [];

        for (var doc in querySnapshot.docs) {
          final date = doc['date'];
          String formattedDateString = '';

          if (date != null) {
            if (date is Timestamp) {
              formattedDateString = DateFormat('yyyy-MM-dd').format(date.toDate());
            } else if (date is String) {
              try {
                final parsedDate = DateTime.parse(date);
                formattedDateString = DateFormat('yyyy-MM-dd').format(parsedDate);
              } catch (e) {
                formattedDateString = date;
              }
            }
          }

          documents.add({
            'date': formattedDateString,
            'analysis': doc['analysis']?.toString() ?? '',
            'tips': [
              doc['tip1']?.toString() ?? '',
              doc['tip2']?.toString() ?? '',
              doc['tip3']?.toString() ?? '',
            ].where((tip) => tip.isNotEmpty).toList().cast<String>(),
            'docId': doc.id, // Store document ID for deletion
          });
        }

        setState(() {
          userDocuments = documents;
        });
      }
    } catch (e) {
      print('Error loading tips: $e');
    } finally {
      setState(() {
        isTipsLoading = false;
      });
    }
  }

  Future<void> _clearAllTips() async {
    final user = _auth.currentUser;
    if (user == null || userDocuments.isEmpty) return;

    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text('Are you sure you want to delete all your Suggestions? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) return;

    setState(() {
      isTipsLoading = true;
    });

    try {
      // Delete all documents from Firestore
      final batch = _firestore.batch();
      for (var doc in userDocuments) {
        if (doc['docId'] != null) {
          batch.delete(_firestore.collection('ai_analysis').doc(doc['docId']));
        }
      }
      await batch.commit();

      // Clear local state
      setState(() {
        userDocuments.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All tips and analysis have been deleted')),
      );
    } catch (e) {
      print('Error deleting tips: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete tips. Please try again.')),
      );
    } finally {
      setState(() {
        isTipsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Suggestions'),
        centerTitle: true,
        actions: [
          if (isTipsAllowed && userDocuments.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline),
              onPressed: _clearAllTips,
              tooltip: 'Clear All',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 4.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Allow Suggestions',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (isLoading)
                      CircularProgressIndicator()
                    else
                      Switch(
                        value: isTipsAllowed,
                        onChanged: (value) async {
                          setState(() {
                            isTipsAllowed = value;
                          });

                          final user = _auth.currentUser;
                          if (user == null) return;

                          try {
                            if (value) {
                              await _firestore
                                  .collection('allowtips')
                                  .doc('tipsusers')
                                  .update({
                                'users': FieldValue.arrayUnion([user.uid])
                              });
                              _loadUserTips();
                            } else {
                              await _firestore
                                  .collection('allowtips')
                                  .doc('tipsusers')
                                  .update({
                                'users': FieldValue.arrayRemove([user.uid])
                              });
                            }
                          } catch (e) {
                            print('Error updating tips preference: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update tips preference')),
                            );
                            setState(() {
                              isTipsAllowed = !value;
                            });
                          }
                        },
                        activeColor: Color(0xFF006FB9),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            if (isTipsAllowed) ...[
              if (isTipsLoading)
                Center(child: CircularProgressIndicator())
              else if (userDocuments.isNotEmpty)
                Column(
                  children: userDocuments.map((document) {
                    return Card(
                      elevation: 4.0,
                      margin: EdgeInsets.only(bottom: 16.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (document['date'] != null && document['date'].isNotEmpty)
                              Text(
                                document['date'],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            SizedBox(height: 16),

                            if (document['analysis'] != null && document['analysis'].isNotEmpty) ...[
                              Text(
                                document['analysis'],
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                              SizedBox(height: 16),
                            ],

                            if (document['tips'] != null && document['tips'].isNotEmpty) ...[
                              Text(
                                'Here are some suggestions for you:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: (document['tips'] as List<String>).map((tip) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4.0, right: 8.0),
                                          child: Icon(Icons.circle, size: 8, color: Colors.grey),
                                        ),
                                        Expanded(
                                          child: Text(
                                            tip,
                                            style: TextStyle(fontSize: 15, height: 1.4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                )
              else
                Card(
                  elevation: 4.0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No analysis or tips available yet. Check back later!',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}