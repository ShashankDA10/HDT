import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../services/n8n_service.dart';
import '../services/health_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

class VoiceReportScreen extends StatefulWidget {
  const VoiceReportScreen({super.key});

  @override
  State<VoiceReportScreen> createState() => _VoiceReportScreenState();
}

class _VoiceReportScreenState extends State<VoiceReportScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final N8nService _n8nService = N8nService();
  final HealthApiService _apiService = HealthApiService();
  
  bool _isListening = false;
  String _transcript = '';
  bool _isProcessing = false;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (kDebugMode) {
            print('Speech status: $status');
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('Speech error: $error');
          }
          setState(() {
            _isListening = false;
          });
        },
      );
      
      if (mounted) {
        setState(() {
          _hasPermission = available;
        });
      }
    }
  }

  void _startListening() async {
    if (!_hasPermission) {
      await _checkPermissions();
      return;
    }

    setState(() {
      _isListening = true;
      _transcript = '';
    });

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _transcript = result.recognizedWords;
        });
      },
      listenFor: const Duration(seconds: 300), // 5 minutes max
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: 'en_US',
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  Future<void> _generateReport() async {
    if (_transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please record some audio first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Send transcript to n8n for AI structuring
      final structuredData = await _n8nService.structureMedicalReport(_transcript);
      
      // Send to backend
      await _apiService.createVoiceReport(
        transcript: _transcript,
        structuredData: structuredData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Voice Report'),
            Text(
              'Speak naturally. We will structure it.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.6),
                  ),
            ),
          ],
        ),
      ),
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 10),
              child: child,
            ),
          );
        },
        child: Column(
          children: [
          // Recording status
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isListening
                  ? AppColors.danger.withOpacity(0.18)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.outline),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _isListening
                  ? Row(
                      key: const ValueKey('recording'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Recording...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Tap to Record',
                      key: ValueKey('idle'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
            ),
          ),
          
          // Record button
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _isListening ? _stopListening : _startListening,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 200),
                      scale: _isListening ? 1.05 : 1.0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening 
                              ? AppColors.danger 
                              : AppColors.accentBlue,
                          boxShadow: [
                            BoxShadow(
                              color: (_isListening ? AppColors.danger : AppColors.accentBlue)
                                  .withOpacity(0.5),
                              blurRadius: _isListening ? 34 : 28,
                              spreadRadius: _isListening ? 12 : 8,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening ? Icons.stop : Icons.mic,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (!_hasPermission)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Microphone permission required',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Transcript display
          if (_transcript.isNotEmpty)
            Container(
              height: 200,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transcript:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        _transcript,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Generate button
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.transparent,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing || _transcript.isEmpty 
                    ? null 
                    : _generateReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                ),
                child: _isProcessing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Processing...'),
                        ],
                      )
                    : const Text(
                        'Generate Report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
