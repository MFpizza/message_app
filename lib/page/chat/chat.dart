import 'dart:io';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:image_picker/image_picker.dart';
import 'package:message_app/page/chat/chatSetting.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_core/firebase_core.dart';

//TODO
//TODO 建 subDocument

class ChatPage extends StatefulWidget {
  final String roomId;
  final String roomName;
  final String photoURL;

  final DocumentSnapshot user;

  ChatPage(
      {Key key,
      @required this.user,
      @required this.roomId,
      @required this.roomName,
      @required this.photoURL})
      : super(key: key);

  @override
  _ChatPage createState() => _ChatPage(roomId, roomName, photoURL, user);
}

class _ChatPage extends State<ChatPage> {
  String photoURL;
  String roomID;
  String roomName;
  FirebaseAuth auth;

  DocumentSnapshot user;

  _ChatPage(
      String _roomId, String _roomName, String _url, DocumentSnapshot _data) {
    roomID = _roomId;
    roomName = _roomName;
    photoURL = _url;
    user = _data;
  }

  void initState() {
    super.initState();
    auth = FirebaseAuth.instance;

  }

  final TextEditingController _chatController = TextEditingController();

  Future<void> getImage(picker, _source) async {
    final pickedFile = await picker.getImage(source: _source);
    String name = pickedFile.path.toString().split('/').last;
    File file = File(pickedFile.path);
    // print(pickedFile.runtimeType);

    try {
      EasyLoading.show(status: 'loading...');
      TaskSnapshot snapshot = await firebase_storage.FirebaseStorage.instance
          .ref('message/image/' + name)
          .putFile(file);
      String download = await snapshot.ref.getDownloadURL();

      EasyLoading.dismiss();
      _submitContent(download, 'image');
    } catch (e) {
      print(e);
      // e.g, e.code == 'canceled'
    }

    Navigator.of(context).pop();
  }
  void myBottomSheet(BuildContext context) {
    File _image;
    final picker = ImagePicker();
    // showBottomSheet || showModalBottomSheet
    showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext context) {
          return Container(
              height: 200,
              child: GridView.count(
                crossAxisCount: 3,
                childAspectRatio: 1.0,
                children: <Widget>[
                  InkWell(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Icon(Icons.camera_alt), Text("相機")]),
                    onTap: () => getImage(picker, ImageSource.camera),
                  ),
                  InkWell(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Icon(Icons.photo), Text("相片")]),
                    onTap: () => getImage(picker, ImageSource.gallery),
                  ),
                  InkWell(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Icon(Icons.person), Text("gif")]),
                    onTap: () => getImage(picker, ImageSource.gallery),
                  ),
                  Icon(Icons.airport_shuttle),
                  Icon(Icons.all_inclusive),
                  Icon(Icons.beach_access),
                  Icon(Icons.cake),
                  Icon(Icons.free_breakfast),
                ],

              )
          );
        });
  }


  void _submitContent(String content, String type) async {
    if (content == '') return;
    _chatController.clear(); // 清空controller資料
    // print(roomID);
    await FirebaseFirestore.instance
        .collection('chatRoom')
        .doc(roomID)
        .collection('messages')
        .add({
      'email': user.data()['email'],
      'photoURL': user.data()['photoURL'],
      'userName': user.data()['username'],
      'content': content,
      'time': Timestamp.now(),
      'type': type
    });
    setState(() {});
  }

  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
        appBar: AppBar(
          title: Text(roomName),
          backgroundColor: theme.primaryColorDark,
          actions: [
            IconButton(
                icon: Icon(Icons.settings),
                onPressed: () async {
                  await Navigator.of(context)
                      .push(MaterialPageRoute(builder: (context) {
                    return ChatSetting(
                      roomName: roomName,
                      docId: roomID,
                      photoURL: photoURL,
                      member: [],
                    );
                  }));
                  DocumentSnapshot data = await FirebaseFirestore.instance
                      .collection('chatRoom')
                      .doc(roomID)
                      .get();
                  setState(() {
                    roomName = data.data()['roomName'];
                    photoURL = data.data()['phototURL'];
                  });
                }),
            IconButton(
              icon: Icon(Icons.menu, size: 28),
              onPressed: () async {
                await Navigator.of(context).push(
                    MaterialPageRoute(builder: (context)
                        {
                          return InviteFriend(
                              roomId: roomID,
                              roomName:roomName,
                              photoURL:photoURL,
                              user:user,
                          );
                        }
                    ));
              },

            ),
          ],
        ),
        body: InkWell(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Container(
              color: theme.primaryColor.blend(theme.backgroundColor, 70),
              child: Column(
                children: [
                  Expanded(
                      child: StreamBuilder(
                          stream: FirebaseFirestore.instance
                              .collection('chatRoom')
                              .doc(roomID)
                              .collection('messages')
                              .orderBy("time", descending: true)
                              .snapshots(),
                          builder:
                              (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                            if (!snapshot.hasData) {
                              return Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            // print();
                            final int commentCount = snapshot.data.docs.length;
                            if (commentCount > 0) {
                              return ListView.builder(
                                padding: EdgeInsets.all(8.0),
                                reverse: true,
                                // 加入reverse，讓它反轉
                                itemBuilder: (context, index) {
                                  final QueryDocumentSnapshot document =
                                      snapshot.data.docs[index];
                                  return HandleMessage(
                                    document: document,
                                    auth: auth,
                                  );
                                },
                                itemCount: commentCount,
                              );
                            }
                            return Center(
                              child: Text("no messages"),
                            );
                          })),
                  SafeArea(
                      child: Row(children: [
                    IconButton(
                        icon: Icon(Icons.menu),
                        onPressed: () => myBottomSheet(context)),
                    Flexible(
                        child: TextField(
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.all(16.0),
                        border: OutlineInputBorder(),
                        hintText: '輸入文字',
                      ),
                      controller: _chatController,
                      // onSubmitted: _submitText, // 綁定事件給_submitText這個Function
                    )),
                    IconButton(
                        icon: Icon(Icons.send),
                        onPressed: () =>
                            _submitContent(_chatController.text, 'text'))
                  ])),
                ],
              )),
        ));
  }
}


class InviteFriend extends StatefulWidget{
  final String roomId;
  final String roomName;
  final String photoURL;
  final String friendEmail;
  final DocumentSnapshot user;

  InviteFriend(
      {Key key,
        @required this.user,
        @required this.roomId,
        @required this.roomName,
        @required this.photoURL,
        @required this.friendEmail})
       : super(key: key);
  @override
  _InviteFriend createState() => _InviteFriend(roomId, roomName, photoURL, user,friendEmail);
}
class _InviteFriend extends State<InviteFriend> {
  String photoURL;
  String roomID;
  String roomName;
  String friendEmail;
  FirebaseAuth auth;
  bool _newValue = false;
  bool _newValue1;
  bool _newValue2 = true;
  DocumentSnapshot user;
  List friend;
  Map<String, bool> friend_number= {};
  int count = 0; // 只需要做一次就好
  CollectionReference users;

  void initFirebase() async {
    await Firebase.initializeApp().whenComplete(() {
      print("initial completed");
    });
    users = FirebaseFirestore.instance.collection('users');
  }
  void initState() {
    initFirebase();
    super.initState();
  }



  _InviteFriend(String _roomId, String _roomName, String _url,
      DocumentSnapshot _data, String _friendEmail) {
    roomID = _roomId;
    roomName = _roomName;
    photoURL = _url;
    user = _data;
    friendEmail = _friendEmail;
  }


  @override
  Widget build(BuildContext context) {
    //print(user.data()['friend'][0]['email']);
    //print(user.data());
    //print(roomID);
    //print(roomName);
   // print(photoURL);

    //print(friend.length);
    if(count == 0) {

      friend = user.data()['friend'];
      for (int i = 0; i < friend.length; i++) {
        friend_number.addAll({
          "${friend[i]['username']}": false
        });
        //print(friend_number);
      }
      count++;
    }
    return new Scaffold(
      appBar: new AppBar(title: Text('Demo')),
      body: InkWell(
        onTap: (){
        },
        child: Column(
          children: [
            Expanded(
            child: ListView(
              children: friend_number.keys.map((String key) {
                return new CheckboxListTile(
                  title: Text(key),
                  value: friend_number[key],
                  onChanged: (bool value) {
                    setState(() {
                      friend_number[key] = value;
                      //print(friend_number[key]);
                    });
                  },
                  isThreeLine: false,
                  dense: true,
                  secondary: Icon(Icons.person),
                  selected: true,
                  controlAffinity: ListTileControlAffinity.platform,
                );
              }).toList(),

            ),
            ),
            ElevatedButton(
              child: Text("確認"),
              onPressed: () {
             addfirend();
             //print(users);
             Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),

    );
  }
  void addChatRoom(String _email, String _id, String _roomName) async {

    DocumentSnapshot document1 = await users.doc(_email).get();
    print(document1);
    List<Map<String, dynamic>> list = List.from(document1.data()['chatRoom']);
    var addThing = {
      "roomName": _roomName,
      "roomID": _id,
      "photoUrl": null,
    };
    list.add(addThing);
    try {
      users.doc(_email).update({"chatRoom": list});
    }
    catch(e){
     print('1');
    }
    print('3');
  }

  void createChat(String friendemail) async {
    //print('4');
    CollectionReference chatRoom =
    FirebaseFirestore.instance.collection("chatRoom");
    DocumentSnapshot document = await chatRoom.doc(roomID).get();

    bool notInTheRoom = true;
    for(int i = 0;i<document.data()['member'].length;i++){
      //print(document.data()['member']);
      //print(roomName);
      if(friendemail == document.data()['member'][i]){
        notInTheRoom = false;
      }

      print(document.data()['member'][i]);

    }

    if(notInTheRoom){
      List list =  List.from(document.data()['member']);
      list.add(friendemail);
      chatRoom.doc(roomID).update({'member':list});
      addChatRoom(friendemail, roomID, roomName);
    }
    //TODO 把雙方的聊天室增加這個剛健的聊天室
    //用function才會跑得比較快 同時跑兩個
    //addChatRoom(user.data()['email'], roomID, roomName);

    //TODO 跳轉道 辣個 chatRoom
    //TODO 現有作法 創建後須等待幾秒才會出現
    print('4');
  }

  void addfirend() {
    for (int j = 0; j < friend.length; j++) {
      if (friend_number[friend[j]['username']] == true) {
        //print('1');
        createChat(friend[j]['email']);
      }
    }
  }
}



class MessageBox extends StatelessWidget {
  final String text;
  final bool other;
  final String photoURL;
  final String username;
  final DateTime time;

  MessageBox(
      {Key key, this.text, this.other, this.photoURL, this.username, this.time})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    double clipSize = 60;
    List list = <Widget>[
      Container(
        height: 35,
        alignment: Alignment.bottomCenter,
        child: Text(timeago.format(time),
            // overflow: TextOverflow.ellipsis,
            maxLines: 5,
            style: TextStyle(
              fontSize: 12.0,
            )),
      ),
      Flexible(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: other
                ?
                 theme.colorScheme.secondary : theme.secondaryHeaderColor,
          ),
          padding: EdgeInsets.all(10.0),
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              maxLines: 5,
              style: TextStyle(fontSize: 18.0, color: theme.backgroundColor)),
        ),
      ),
      VerticalDivider(),
      photoURL != null
          ? Container(
              width: clipSize,
              height: clipSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(image: NetworkImage(photoURL))))
          : Container(
              width: clipSize,
              height: clipSize,
              alignment: Alignment.bottomCenter,
              child: CircleAvatar(
                  backgroundColor:
                      other ? theme.colorScheme.secondary : theme.primaryColor,
                  radius: 35,
                  child: Icon(Icons.person,
                      size: 30, color: theme.backgroundColor))),
    ];

    // print(timeago.format(time));
    return Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
            verticalDirection: VerticalDirection.up,
            mainAxisAlignment:
                other ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: other ? list.reversed.toList() : list));
  }
}

class ShortCutChatRoom extends StatefulWidget {
  String name;
  int i;
  String photoURL;

  ShortCutChatRoom({
    this.name,
    this.i,
    this.photoURL,
  });

  _ShortCutChatRoom createState() => _ShortCutChatRoom(name, i, photoURL);
}

class _ShortCutChatRoom extends State<ShortCutChatRoom> {
  int i;
  String roomName;
  String photoURL;

  _ShortCutChatRoom(String _name, int _i, String _url) {
    roomName = _name;
    i = _i;
    photoURL = _url;
  }

  @override
  Widget build(BuildContext context) {
    print(roomName);
    final ThemeData theme = Theme.of(context);
    return ListTile(
      tileColor: theme.colorScheme.secondary,
      leading: Container(
          height: 90,
          width: 90,
          child: CircleAvatar(
              backgroundColor: theme.primaryColor,
              radius: 60,
              child: Icon(
                //TODO 未來支援圖片
                Icons.person,
                size: 45,
                color: theme.secondaryHeaderColor,
              ))),
      title: Text(
        roomName,
        style: TextStyle(fontSize: 30, color: theme.backgroundColor),
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 0.0),
      subtitle: Text(
        "壓著往左滑看看",
        style: TextStyle(color: theme.backgroundColor),
      ),
    );
  }
}

class HandleMessage extends StatelessWidget {
  final QueryDocumentSnapshot document;

  final FirebaseAuth auth;

  HandleMessage({this.document, this.auth});

  @override
  Widget build(BuildContext context) {
    if (document.data()['type'] == "image") {
      return ImageBox(
        username: document.data()['username'],
        time: document.data()['time'].toDate(),
        photoURL: document.data()['photoURL'],
        other:
            document.data()['email'] == auth.currentUser.email ? false : true,
        imageURL: document.data()['content'],
      );
    }
    return MessageBox(
      username: document.data()['username'],
      time: document.data()['time'].toDate(),
      photoURL: document.data()['photoURL'],
      other: document.data()['email'] == auth.currentUser.email ? false : true,
      text: document.data()['content'],
    );
  }
}

class ImageBox extends StatelessWidget {
  final String imageURL;
  final bool other;
  final String photoURL;
  final String username;
  final DateTime time;

  ImageBox(
      {Key key,
      @required this.imageURL,
      @required this.other,
      @required this.photoURL,
      @required this.username,
      @required this.time})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    Image image = Image.network(imageURL, fit: BoxFit.fill);
    double clipSize = 60;
    List list = <Widget>[
      Container(
        alignment: Alignment.bottomCenter,
        child: Text(timeago.format(time),
            // overflow: TextOverflow.ellipsis,
            maxLines: 5,
            style: TextStyle(
              fontSize: 12.0,
            )),
      ),
      Flexible(
        child: Container(
          child: image,
        ),
      ),
      VerticalDivider(),
      photoURL != null
          ? Container(
              width: clipSize,
              height: clipSize,
              alignment: Alignment.bottomCenter,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(image: NetworkImage(photoURL))))
          : Container(
              width: clipSize,
              height: clipSize,
              alignment: Alignment.bottomCenter,
              child: CircleAvatar(
                  backgroundColor:
                      other ? theme.colorScheme.secondary : theme.primaryColor,
                  radius: 35,
                  child: Icon(Icons.person,
                      size: 30, color: theme.backgroundColor))),
    ];

    // print(timeago.format(time));
    return Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
            verticalDirection: VerticalDirection.up,
            mainAxisAlignment:
                other ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: other ? list.reversed.toList() : list));
  }
}
