// pusher_service.dart
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

class PusherService {
  static final PusherService _instance = PusherService._internal();
  factory PusherService() => _instance;

  late PusherChannelsFlutter pusher;
  Function(String, dynamic)? onEventReceived;

  PusherService._internal();

  Future<void> init() async {
    pusher = PusherChannelsFlutter();
    await pusher.init(
      apiKey: '4da1b71c65296e5a00c9',
      cluster: 'eu',
      onConnectionStateChange: (currentState, previousState) => print(
        'Connection state changed from $previousState to $currentState',
      ),
      onEvent: (event) {
        final data = event.data;
        final eventName = event.eventName;
        if (onEventReceived != null) {
          onEventReceived!(eventName, data);
        }
      },
    );
    await pusher.subscribe(channelName: "private-video-call");
    await pusher.connect();
  }

  Future<void> sendEvent(String eventName, Map<String, dynamic> data) async {
    await pusher.trigger(PusherEvent(
        channelName: "private-video-call", data: data, eventName: eventName));
  }

  void setListener(Function(String, dynamic) listener) {
    onEventReceived = listener;
  }
}
