import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MachineStatusPage extends StatefulWidget {
  final String Function(String) translate;

  MachineStatusPage({required this.translate});

  @override
  _MachineStatusPageState createState() => _MachineStatusPageState();
}

class _MachineStatusPageState extends State<MachineStatusPage> {
  List<dynamic> machines = [];
  String? selectedMachineType;
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchMachineStatus();
  }

  Future<void> fetchMachineStatus() async {
    try {
      final response = await http.get(Uri.parse(
          'https://agrix-staging-v1.azurewebsites.net/machines/status'));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        setState(() {
          machines = jsonResponse['data'];
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load machines status');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching data: $e';
      });
    }
  }

  List<String> getMachineTypes() {
    return machines.map((machine) => machine['type'] as String).toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.translate('Machine Status'))),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
          ? Center(child: Text(errorMessage))
          : machines.isEmpty
          ? Center(child: Text(widget.translate('No data available')))
          : Column(
        children: [
          DropdownButton<String>(
            value: selectedMachineType,
            hint: Text(widget.translate('Select Machine Type')),
            items: getMachineTypes().map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                selectedMachineType = newValue;
              });
            },
          ),
          Expanded(
            child: ListView(
              children: machines
                  .where((machine) =>
              selectedMachineType == null ||
                  machine['type'] == selectedMachineType)
                  .map((machine) {
                return ListTile(
                  title: Text(machine['name']),
                  subtitle: Text(
                      'Status: ${machine['status']}'),
                  trailing: Icon(Icons.info),
                  onTap: () {
                    // Handle item tap
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
