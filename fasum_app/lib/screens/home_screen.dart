import 'package:fasum_app/screens/sign_in_screen.dart';
import 'package:fasum_app/screens/sign_up_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> signOut(BuildContext context) async{
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const SignInScreen()
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
        IconButton(
          onPressed: (){
            signOut(context);
          }, 
          icon: const Icon(Icons.logout)
          )
        ],
      ),
      body: const Center(
        child: const Text('You have logged in'),
      ),
    );
  }
}