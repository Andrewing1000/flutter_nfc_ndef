import 'package:flutter/material.dart';
import 'package:flutter_hce/hce_utils.dart';
import 'hce_service_simple.dart';

/// Simplified UI that only handles JSON transmission
class JsonHceWidget extends StatefulWidget {
  const JsonHceWidget({Key? key}) : super(key: key);

  @override
  State<JsonHceWidget> createState() => _JsonHceWidgetState();
}

class _JsonHceWidgetState extends State<JsonHceWidget> {
  final HceService _hceService = HceService();
  bool _isHceActive = false;
  NfcState _nfcState = NfcState.unknown;
  List<String> _logs = [];

  // JSON data controllers
  final TextEditingController _nameController =
      TextEditingController(text: 'Flutter HCE Demo');
  final TextEditingController _messageController =
      TextEditingController(text: 'Hello from NFC!');
  final TextEditingController _userIdController =
      TextEditingController(text: '12345');

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _hceService.initialize();

    // Listen to streams
    _hceService.hceStatusStream.listen((isActive) {
      if (mounted) {
        setState(() {
          _isHceActive = isActive;
        });
      }
    });

    _hceService.nfcStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _nfcState = state;
        });
      }
    });

    _hceService.logStream.listen((log) {
      if (mounted) {
        setState(() {
          _logs.add(log);
          // Keep only last 50 logs
          if (_logs.length > 50) {
            _logs.removeAt(0);
          }
        });
      }
    });

    setState(() {
      _isHceActive = _hceService.isHceActive;
      _nfcState = _hceService.nfcState;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('JSON NFC HCE Demo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Status Section
          _buildStatusSection(),

          // JSON Data Input Section
          _buildJsonInputSection(),

          // Control Buttons
          _buildControlSection(),

          // Logs Section
          Expanded(child: _buildLogsSection()),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NFC Status:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getNfcStateColor(_nfcState),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _nfcState.description,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'HCE Status:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isHceActive ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isHceActive ? 'Active' : 'Inactive',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJsonInputSection() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'JSON Data to Transmit',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'App Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.apps),
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _messageController,
            decoration: InputDecoration(
              labelText: 'Message',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.message),
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _userIdController,
            decoration: InputDecoration(
              labelText: 'User ID',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildControlSection() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _nfcState == NfcState.enabled ? _startJsonHce : null,
                  icon: Icon(Icons.nfc),
                  label: Text('Start JSON HCE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isHceActive ? _stopHce : null,
                  icon: Icon(Icons.stop),
                  label: Text('Stop HCE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _checkNfcState,
              icon: Icon(Icons.refresh),
              label: Text('Check NFC State'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsSection() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaction Logs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _logs.clear();
                  });
                },
                icon: Icon(Icons.clear_all),
                tooltip: 'Clear logs',
              ),
            ],
          ),
          SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Text(
                      _logs[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
                reverse: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Control methods
  Future<void> _startJsonHce() async {
    final jsonData = {
      'app_name': _nameController.text.trim(),
      'message': _messageController.text.trim(),
      'user_id': int.tryParse(_userIdController.text.trim()) ?? 0,
      'timestamp': DateTime.now().toIso8601String(),
      'version': '1.0.0',
      'session_data': {
        'token': 'abc123xyz',
        'permissions': ['read', 'write', 'nfc'],
        'expires_at': DateTime.now().add(Duration(hours: 1)).toIso8601String(),
      }
    };

    await _hceService.startJsonHce(jsonData: jsonData);
  }

  Future<void> _stopHce() async {
    await _hceService.stopHce();
  }

  Future<void> _checkNfcState() async {
    await _hceService.checkNfcState();
  }

  Color _getNfcStateColor(NfcState state) {
    switch (state) {
      case NfcState.enabled:
        return Colors.green;
      case NfcState.disabled:
        return Colors.red;
      case NfcState.notSupported:
        return Colors.orange;
      case NfcState.unknown:
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    _userIdController.dispose();
    _hceService.dispose();
    super.dispose();
  }
}
