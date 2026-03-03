import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/ac_status.dart';

class AcMqttService {
  MqttServerClient? client;
  AcStatus _status = AcStatus();

  AcStatus get status => _status;

  Future<void> connect() async {
    client = MqttServerClient('thingsboard.what-if.sg', 'flutter_client_${DateTime.now().millisecondsSinceEpoch}');
    client!.port = 1883;
    client!.keepAlivePeriod = 20;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_client_${DateTime.now().millisecondsSinceEpoch}')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client!.connectionMessage = connMessage;

    try {
      await client!.connect('your-device-token');
      _subscribeToTelemetry();
    } catch (e) {
      print('MQTT Connection error: $e');
      client!.disconnect();
    }
  }

  void _subscribeToTelemetry() {
    if (client?.connectionStatus?.state == MqttConnectionState.connected) {
      client!.subscribe('v1/devices/me/telemetry', MqttQos.atLeastOnce);
      client!.updates!.listen((messages) {
        for (var message in messages) {
          final recMess = message.payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          final data = jsonDecode(payload);
          _status = AcStatus.fromJson(data);
        }
      });
    }
  }

  Future<void> sendAcCommand(Map<String, dynamic> params) async {
    if (client?.connectionStatus?.state != MqttConnectionState.connected) {
      print('MQTT not connected');
      return;
    }

    final request = {
      'method': 'acControl',
      'params': params,
    };

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(request));

    client!.publishMessage(
      'v1/devices/me/rpc/request/${DateTime.now().millisecondsSinceEpoch}',
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }
}
