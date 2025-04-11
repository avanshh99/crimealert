import 'package:flutter/material.dart';
import 'signup.dart';
import 'package:crime_alert/views/home/home_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  String _displayText = '';
  final String _fullText = 'CrimeWatch';
  int _charIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 60.0,
      ),
    ]).animate(_controller);

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animateText();
      }
    });
  }

void _animateText() {
  if (_charIndex < _fullText.length) {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _displayText = _fullText.substring(0, _charIndex + 1);
          _charIndex++;
        });
        _animateText();  // Call itself recursively with delay
      }
    });
  } else {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) =>  Dashboard()),
        );
      }
    });
  }
}


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'images/background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.red.withOpacity(0.9), // Mild Red
                    Colors.black.withOpacity(0.9), // Mild Black
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Image.asset(
              '/images/splash_top_left.png',
              width: 200,
              height: 220,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Image.asset(
              '/images/splash_bottom_right.png',
              width: 200,
              height: 220,
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _bounceAnimation,
                  child: Image.asset(
                    'images/logo.png',
                    width: 400,
                    height: 250,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _displayText,
                  style: const TextStyle(
                    fontFamily: 'Comic Sans MS',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(2, 2),
                        blurRadius: 3,
                      ),
                    ],
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
