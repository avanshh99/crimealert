// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'add_post_screen.dart';
// import 'package:intl/intl.dart';

// class PostFeedScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Post Feed'),
//         backgroundColor: Colors.red,
//       ),
//       body: StreamBuilder<QuerySnapshot>(
//         stream: FirebaseFirestore.instance
//             .collection('posts')
//             .orderBy('dateCreated', descending: true)
//             .snapshots(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           }
//           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//             return Center(child: Text("No posts found"));
//           }

//           var posts = snapshot.data!.docs;

//           return ListView.builder(
//             itemCount: posts.length,
//             itemBuilder: (context, index) {
//               var data = posts[index].data() as Map<String, dynamic>;

//               return Card(
//                 margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                 child: Padding(
//                   padding: EdgeInsets.all(10),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // User info
//                       ListTile(
//                         leading: CircleAvatar(
//                           backgroundImage: NetworkImage(data['avatar'] ?? ""),
//                         ),
//                         title: Text(
//                           data['firstName'] != null
//                               ? "${data['firstName']} (me)"
//                               : "Unknown User",
//                           style: TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                       ),
//                       SizedBox(height: 5),
//                       Text(data['title'],
//                           style: TextStyle(
//                               fontSize: 18, fontWeight: FontWeight.bold)),
//                       SizedBox(height: 5),
//                       Text(data['content']),
//                       SizedBox(height: 5),

//                       // Post image
//                       if (data['media'] != null && data['media'].isNotEmpty)
//                         Image.network(data['media'][0],
//                             height: 200, fit: BoxFit.cover),

//                       // Comment and Like section
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text("${data['countComment']} comments"),
//                           IconButton(
//                             icon: Icon(Icons.comment),
//                             onPressed: () {
//                               // Navigate to comments screen
//                             },
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),

//       // Floating Button to Add Post
//       floatingActionButton: FloatingActionButton(
//         backgroundColor: Colors.red,
//         child: Icon(Icons.add),
//         onPressed: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(builder: (context) => AddPostScreen()),
//           );
//         },
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_post_screen.dart';
import 'package:intl/intl.dart';

class PostFeedScreen extends StatefulWidget {
  @override
  _PostFeedScreenState createState() => _PostFeedScreenState();
}

class _PostFeedScreenState extends State<PostFeedScreen> {
  bool _showOnlyMyPosts = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    print("Current User ID: ${_currentUser?.uid}");
  }

  Stream<QuerySnapshot> _getPostsStream() {
    if (_showOnlyMyPosts) {
      if (_currentUser == null) {
        // Return an empty stream if no user is logged in
        return FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: 'non-existent-id')
            .snapshots();
      }
      return FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: _currentUser!.uid)
          .orderBy('dateCreated', descending: true)
          .snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection('posts')
          .orderBy('dateCreated', descending: true)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Post Feed'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: Icon(
              _showOnlyMyPosts ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showOnlyMyPosts = !_showOnlyMyPosts;
              });
            },
            tooltip: _showOnlyMyPosts ? 'Show all posts' : 'Show only my posts',
          ),
          IconButton(
            icon: Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddPostScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getPostsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print("STREAM ERROR: ${snapshot.error}");
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                _showOnlyMyPosts
                    ? _currentUser == null
                        ? 'Please login to see your posts'
                        : "You haven't created any posts yet"
                    : "No posts found",
              ),
            );
          }

          var posts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              var post = posts[index];
              var data = post.data() as Map<String, dynamic>;
              bool isCurrentUser =
                  _currentUser != null && data['userId'] == _currentUser!.uid;

              String formattedDate = "Unknown Date";
              if (data['dateCreated'] != null) {
                var timestamp = data['dateCreated'];
                if (timestamp is Timestamp) {
                  formattedDate = DateFormat('MMM d, yyyy – h:mm a')
                      .format(timestamp.toDate());
                }
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(data['userId'])
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return _buildPostSkeleton();
                  }

                  String userImage = 'assets/images/default_avatar.png';
                  String userName = "Unknown User";

                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    var userData =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    userImage = userData['imageURL'] ?? userImage;
                    userName =
                        "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}"
                            .trim();
                    if (userName.isEmpty) userName = "Unknown User";
                  }

                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundImage: userImage.startsWith('http')
                                  ? NetworkImage(userImage)
                                  : AssetImage(userImage) as ImageProvider,
                            ),
                            title: Row(
                              children: [
                                Text(userName,
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                if (isCurrentUser)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Text("(You)",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                          fontStyle: FontStyle.italic,
                                        )),
                                  ),
                              ],
                            ),
                            subtitle: Text(formattedDate),
                          ),
                          SizedBox(height: 5),
                          Text(data['title'] ?? "Untitled",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 5),
                          Text(data['content'] ?? ""),
                          if (data['media'] != null &&
                              data['media'].isNotEmpty &&
                              data['media'][0].isNotEmpty)
                            Container(
                              height: 200,
                              width: double.infinity,
                              child: Image.network(
                                data['media'][0],
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  (loadingProgress
                                                          .expectedTotalBytes ??
                                                      1)
                                              : null,
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (data['location'] != null &&
                              data['location'].isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text("Location: ${data['location']}",
                                  style: TextStyle(color: Colors.grey[600])),
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("${data['countComment'] ?? 0} comments"),
                              IconButton(
                                icon: Icon(Icons.comment),
                                onPressed: () {},
                              ),
                            ],
                          ),
                          if (isCurrentUser)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () {},
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    bool? confirm = await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text("Delete Post"),
                                        content: Text(
                                            "Are you sure you want to delete this post?"),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: Text("Cancel"),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: Text("Delete"),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      try {
                                        await post.reference.delete();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text("Post deleted")));
                                      } catch (error) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(
                                                    "Delete failed: $error")));
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPostSkeleton() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(backgroundColor: Colors.grey[300]),
              title: Container(
                width: 100,
                height: 16,
                color: Colors.grey[300],
              ),
              subtitle: Container(
                width: 150,
                height: 14,
                color: Colors.grey[300],
              ),
            ),
            SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 16,
              color: Colors.grey[300],
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 14,
              color: Colors.grey[300],
            ),
            SizedBox(height: 20),
            Container(
              height: 200,
              color: Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }
}
