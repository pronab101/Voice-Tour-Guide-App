import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:voicetourguide/Message.dart';

class ChatScreen extends StatefulWidget {
  final String monumentName;

  ChatScreen({required this.monumentName});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _userInput = TextEditingController();
  final List<Message> _messages = [];

  // Define the API URL and token
  static const String apiUrl = "https://api-inference.huggingface.co/models/mistralai/Mistral-7B-Instruct-v0.3";
  static const String apiToken = "Bearer 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"; // Replace with your token

  Future<void> sendMessage() async {
    final message = "Give a short one-line response about ${widget.monumentName} Landmark: " + _userInput.text;

    setState(() {
      _messages.add(Message(isUser: true, message: _userInput.text, date: DateTime.now()));
      _userInput.clear();
    });

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Authorization": apiToken,
          "Content-Type": "application/json",
        },
        body: jsonEncode({"inputs": message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Debugging: Print the structure of the response
        print("Response body: ${response.body}");

        String? generatedText;
        if (data is List && data.isNotEmpty && data[0].containsKey("generated_text")) {
          generatedText = data[0]["generated_text"];
        } else {
          generatedText = "No response available.";
        }

        setState(() {
          _messages.add(Message(
            isUser: false,
            message: generatedText!,
            date: DateTime.now(),
          ));
        });
      } else {
        // Log error and response body
        print("Error: ${response.statusCode}");
        print("Body: ${response.body}");

        setState(() {
          _messages.add(Message(
            isUser: false,
            message: "Error: Unable to fetch a response (${response.statusCode}).",
            date: DateTime.now(),
          ));
        });
      }
    } catch (e) {
      print("Exception: $e");
      setState(() {
        _messages.add(Message(
          isUser: false,
          message: "Error: An exception occurred.",
          date: DateTime.now(),
        ));
      });
    }
  }


  Widget buildMessageBubble(Message message) {
    bool isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isUser ? Colors.deepPurple[300] : Colors.grey[200],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.message,
              style: TextStyle(color: isUser ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                DateFormat('HH:mm').format(message.date),
                style: TextStyle(
                  fontSize: 10,
                  color: isUser ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple[50],
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('AI Tour Guide', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return buildMessageBubble(message);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _userInput,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Enter your message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: sendMessage,
                  child: const CircleAvatar(
                    backgroundColor: Colors.deepPurple,
                    child: Icon(Icons.send, color: Colors.white),
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
