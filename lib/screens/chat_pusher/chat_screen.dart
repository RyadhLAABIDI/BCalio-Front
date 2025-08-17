// import 'dart:convert';
// import 'package:bcalio/controllers/user_controller.dart';
// import 'package:bcalio/models/true_user_model.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
// import 'package:dio/dio.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

// class ChatScreen extends StatefulWidget {
//   final String currentUserId;
//   final User recipientUser;

//   const ChatScreen({
//     Key? key,
//     required this.currentUserId,
//     required this.recipientUser,
//   }) : super(key: key);

//   @override
//   _ChatScreenState createState() => _ChatScreenState();
// }

// class _ChatScreenState extends State<ChatScreen> {
//   final PusherChannelsFlutter pusher = PusherChannelsFlutter.getInstance();
//   final TextEditingController _messageController = TextEditingController();
//   final List<Map<String, dynamic>> _messages = [];
//   late String _channelName;
//   bool _isConnected = false;
//   bool _isSubscribed = false;

//   // WebRTC variables
//   RTCPeerConnection? _peerConnection;
//   final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
//   final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
//   bool _isCalling = false;
//   bool _isInCall = false;
//   bool _isVideoCall = false;
//   MediaStream? _localStream;
//   bool _localRendererInitialized = false;
//   bool _remoteRendererInitialized = false;

//   @override
//   void initState() {
//     super.initState();
//     _channelName =
//         _generateChannelName(widget.currentUserId, widget.recipientUser.id);
//     debugPrint('Channel name: $_channelName');
//     _initRenderers();
//     _initPusher();
//   }

//   Future<void> _initRenderers() async {
//     try {
//       await _localRenderer.initialize();
//       await _remoteRenderer.initialize();
//       setState(() {
//         _localRendererInitialized = true;
//         _remoteRendererInitialized = true;
//       });
//       debugPrint('Renderers initialized successfully');
//     } catch (e) {
//       debugPrint('Error initializing renderers: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to initialize video renderers: $e')),
//       );
//     }
//   }

// /*************  ✨ Windsurf Command ⭐  *************/
//   /// Initializes Pusher with client events enabled and subscribes to the channel.
//   ///
//   /// Listens for the following events:
//   ///
//   /// - `client-message`: Adds the message to the list of messages and updates the UI.
//   /// - `client-signal`: Handles the signal by calling `_handleSignal`.
//   ///
//   /// Displays error messages if there are any errors during initialization or subscription.
//   ///
// /*******  1542e57b-ed8d-4189-9835-301e8ab28b85  *******/  Future<void> _initPusher() async {
//     try {
//       // Initialize Pusher with client events enabled
//       await pusher.init(
//         apiKey: 'bc00b5f6fa3dc2dbbb91',
//         cluster: 'eu',
//         // enableClientEvents: true, // Enable client events for signaling
//         onAuthorizer: (channelName, socketId, options) async {
//           final auth = await getPusherToken(channelName, socketId);
//           debugPrint('Pusher auth token: $auth');
//           if (auth == null) {
//             debugPrint('Failed to get Pusher auth token');
//             return {};
//           }
//           return {'auth': auth};
//         },
//         onEvent: (PusherEvent event) {
//           debugPrint('Event received: ${event.eventName}, data: ${event.data}');
//           if (event.eventName == 'client-message' && event.data != null) {
//             try {
//               final data = jsonDecode(event.data!);
//               setState(() {
//                 _messages.add({
//                   'senderId': data['senderId'],
//                   'content': data['content'],
//                   'timestamp': DateTime.now(),
//                 });
//               });
//             } catch (e) {
//               debugPrint('Error parsing message: $e');
//             }
//           } else if (event.eventName == 'client-signal' && event.data != null) {
//             _handleSignal(event.data!);
//           }
//         },
//         onError: (String message, int? code, dynamic e) {
//           debugPrint('Pusher error: $message, code: $code, exception: $e');
//           setState(() {
//             _isConnected = false;
//             _isSubscribed = false;
//           });
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Pusher error: $message')),
//           );
//         },
//         onConnectionStateChange: (String? currentState, String? previousState) {
//           debugPrint('Pusher connection state: $currentState');
//           setState(() {
//             _isConnected = currentState == 'CONNECTED';
//           });
//         },
//       );

//       // Connect to Pusher
//       await pusher.connect();

//       // Subscribe to channel
//       await pusher.subscribe(
//         channelName: _channelName,
//         onSubscriptionSucceeded: (data) {
//           debugPrint('Subscribed to channel $_channelName');
//           setState(() {
//             _isSubscribed = true;
//           });
//         },
//         onSubscriptionError: (String message, dynamic e) {
//           debugPrint('Subscription error: $message, exception: $e');
//           setState(() {
//             _isSubscribed = false;
//           });
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Failed to subscribe to channel: $message')),
//           );
//         },
//       );
//     } catch (e) {
//       debugPrint('Pusher init error: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to initialize Pusher: $e')),
//       );
//     }
//   }

//   Future<void> _initWebRTC() async {
//     try {
//       // Initialize renderers if not already done
//       if (!_localRendererInitialized) {
//         await _localRenderer.initialize();
//         setState(() {
//           _localRendererInitialized = true;
//         });
//       }
//       if (!_remoteRendererInitialized) {
//         await _remoteRenderer.initialize();
//         setState(() {
//           _remoteRendererInitialized = true;
//         });
//       }

//       // Enhanced ICE servers configuration
//       final configuration = {
//         "iceServers": [
//           {"urls": "stun:stun.l.google.com:19302"},
//           {"urls": "stun:stun1.l.google.com:19302"},
//           {"urls": "stun:stun2.l.google.com:19302"},
//           {"urls": "stun:stun3.l.google.com:19302"},
//           {"urls": "stun:stun4.l.google.com:19302"},
//           // Add TURN server if available
//           // {
//           //   "urls": "turn:your-turn-server.com:3478",
//           //   "username": "your-username",
//           //   "credential": "your-credential"
//           // }
//         ],
//         "iceTransportPolicy": "all",
//         "bundlePolicy": "max-bundle",
//         "rtcpMuxPolicy": "require",
//         "sdpSemantics": "unified-plan"
//       };

//       // Create peer connection
//       _peerConnection = await createPeerConnection(configuration);

//       // Handle ICE candidates
//       _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) async {
//         if (candidate.candidate?.isNotEmpty ?? false) {
//           debugPrint('ICE Candidate: ${candidate.candidate}');
//           await _sendSignal({
//             'type': 'candidate',
//             'candidate': {
//               'sdpMLineIndex': candidate.sdpMLineIndex,
//               'sdpMid': candidate.sdpMid,
//               'candidate': candidate.candidate,
//             },
//             'senderId': widget.currentUserId,
//           });
//         }
//       };

//       // Handle incoming tracks
//       _peerConnection?.onTrack = (RTCTrackEvent event) {
//         debugPrint(
//             'Track received: ${event.track.kind}, stream: ${event.streams.isNotEmpty ? event.streams[0].id : 'none'}');
//         if (event.streams.isNotEmpty) {
//           _remoteRenderer.srcObject = event.streams[0];
//           debugPrint('Remote renderer set with stream: ${event.streams[0].id}');
//           setState(() => _isInCall = true);
//         }
//       };

//       // Monitor ICE connection state
//       _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
//         debugPrint('ICE Connection State: $state');
//         if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
//             state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
//           _endCall();
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Call disconnected')),
//           );
//         }
//       };

//       // Debug states
//       _peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
//         debugPrint('ICE Gathering State: $state');
//       };

//       _peerConnection?.onSignalingState = (RTCSignalingState state) {
//         debugPrint('Signaling State: $state');
//       };

//       debugPrint('WebRTC initialized successfully');
//     } catch (e) {
//       debugPrint('WebRTC initialization error: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to initialize WebRTC: $e')),
//       );
//       rethrow;
//     }
//   }

//   String _generateChannelName(String userId1, String userId2) {
//     final sortedIds = [userId1, userId2]..sort();
//     return 'private-chat-${sortedIds[0]}-${sortedIds[1]}';
//   }

//   Future<String?> getPusherToken(String channelName, String socketId) async {
//     try {
//       final token = await Get.find<UserController>().getToken();
//       var headers = {
//         'Content-Type': 'application/json',
//         'Authorization': 'Bearer $token'
//       };
//       var data = json.encode({
//         "socket_id": socketId,
//         "channel_name": channelName,
//       });

//       var dio = Dio();
//       var response = await dio.post(
//         'https://pusher.b-callio.com/pusher/auth',
//         data: data,
//         options: Options(headers: headers),
//       );

//       if (response.statusCode == 200) {
//         debugPrint('Pusher auth response: ${response.data}');
//         // Ensure the auth field is extracted correctly
//         final auth = response.data['auth'] as String?;

//         return auth;
//       } else {
//         debugPrint('Pusher auth failed: ${response.statusMessage}');
//         return null;
//       }
//     } catch (e) {
//       debugPrint('Pusher auth error: $e');
//       return null;
//     }
//   }

//   Future<void> _startCall(bool isVideo) async {
//     try {
//       if (!_isConnected || !_isSubscribed) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Chat service not ready')),
//         );
//         return;
//       }

//       if (_peerConnection == null) await _initWebRTC();

//       setState(() {
//         _isCalling = true;
//         _isVideoCall = isVideo;
//       });

//       // Media constraints
//       final mediaConstraints = {
//         'audio': {
//           'echoCancellation': true,
//           'noiseSuppression': true,
//           'autoGainControl': true,
//           'channelCount': 1,
//         },
//         'video': isVideo
//             ? {
//                 'width': {'ideal': 1280},
//                 'height': {'ideal': 720},
//                 'frameRate': {'ideal': 30},
//                 'facingMode': 'user',
//               }
//             : false
//       };

//       try {
//         _localStream =
//             await rtc.navigator.mediaDevices.getUserMedia(mediaConstraints);
//         _localRenderer.srcObject = _localStream;
//         debugPrint('Local stream initialized: ${_localStream?.id}');

//         for (final track in _localStream!.getTracks()) {
//           await _peerConnection?.addTrack(track, _localStream!);
//           debugPrint('Added ${track.kind} track: ${track.id}');
//         }

//         final offer = await _peerConnection!.createOffer({
//           'offerToReceiveAudio': true,
//           'offerToReceiveVideo': _isVideoCall,
//         });
//         await _peerConnection!.setLocalDescription(offer);
//         debugPrint('Local description set: ${offer.type}, SDP: ${offer.sdp}');

//         await _sendSignal({
//           'type': 'offer',
//           'description': {
//             'sdp': offer.sdp,
//             'type': offer.type,
//           },
//           'senderId': widget.currentUserId,
//         });
//       } catch (e) {
//         debugPrint('Error getting media or creating offer: $e');
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Failed to access camera/microphone: $e')),
//         );
//         _endCall();
//         rethrow;
//       }
//     } catch (e) {
//       debugPrint('Error starting call: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to start call: $e')),
//       );
//       _endCall();
//     }
//   }

//   Future<void> _handleSignal(String data) async {
//     try {
//       final signal = jsonDecode(data);
//       if (signal['senderId'] == widget.currentUserId) return;

//       debugPrint('Received signal: ${signal['type']}');

//       switch (signal['type']) {
//         case 'offer':
//           await _handleOffer(signal['description']);
//           break;
//         case 'answer':
//           await _handleAnswer(signal['description']);
//           break;
//         case 'candidate':
//           await _handleCandidate(signal['candidate']);
//           break;
//         case 'end-call':
//           _endCall();
//           break;
//         default:
//           debugPrint('Unknown signal type: ${signal['type']}');
//       }
//     } catch (e) {
//       debugPrint('Error handling signal: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to handle signal: $e')),
//       );
//     }
//   }

//   Future<void> _handleOffer(dynamic description) async {
//     try {
//       if (_peerConnection == null) await _initWebRTC();

//       debugPrint('Setting remote description: ${description['sdp']}');
//       await _peerConnection!.setRemoteDescription(
//         RTCSessionDescription(description['sdp'], description['type']),
//       );

//       if (_localStream == null) {
//         final mediaConstraints = {
//           'audio': true,
//           'video': _isVideoCall,
//         };
//         _localStream =
//             await rtc.navigator.mediaDevices.getUserMedia(mediaConstraints);
//         _localRenderer.srcObject = _localStream;
//         debugPrint('Local stream initialized for answer: ${_localStream?.id}');

//         for (final track in _localStream!.getTracks()) {
//           await _peerConnection?.addTrack(track, _localStream!);
//           debugPrint('Added ${track.kind} track for answer: ${track.id}');
//         }
//       }

//       final answer = await _peerConnection!.createAnswer();
//       debugPrint('Created answer: ${answer.sdp}');
//       await _peerConnection!.setLocalDescription(answer);

//       await _sendSignal({
//         'type': 'answer',
//         'description': {
//           'sdp': answer.sdp,
//           'type': answer.type,
//         },
//         'senderId': widget.currentUserId,
//       });

//       setState(() {
//         _isInCall = true;
//         _isCalling = false;
//       });
//     } catch (e) {
//       debugPrint('Error handling offer: $e');
//       _endCall();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to handle offer: $e')),
//       );
//     }
//   }

//   Future<void> _handleAnswer(dynamic description) async {
//     if (_peerConnection == null) return;

//     try {
//       debugPrint(
//           'Setting remote description for answer: ${description['sdp']}');
//       await _peerConnection?.setRemoteDescription(
//         RTCSessionDescription(description['sdp'], description['type']),
//       );

//       setState(() {
//         _isInCall = true;
//         _isCalling = false;
//       });
//     } catch (e) {
//       debugPrint('Error handling answer: $e');
//       _endCall();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to handle answer: $e')),
//       );
//     }
//   }

//   Future<void> _handleCandidate(dynamic candidate) async {
//     if (_peerConnection == null) return;

//     try {
//       await _peerConnection?.addCandidate(
//         RTCIceCandidate(
//           candidate['candidate'],
//           candidate['sdpMid'],
//           candidate['sdpMLineIndex'],
//         ),
//       );
//       debugPrint('Added ICE candidate: ${candidate['candidate']}');
//     } catch (e) {
//       debugPrint('Error handling candidate: $e');
//     }
//   }

//   Future<void> _sendSignal(Map<String, dynamic> signal) async {
//     if (!_isConnected || !_isSubscribed) {
//       debugPrint('Cannot send signal - Pusher not ready');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Connection not ready')),
//       );
//       return;
//     }

//     try {
//       await pusher.trigger(
//         PusherEvent(
//           channelName: _channelName,
//           eventName: 'client-signal',
//           data: jsonEncode(signal),
//         ),
//       );
//       debugPrint('Sent signal: ${signal['type']}');
//     } catch (e) {
//       debugPrint('Error sending signal: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to send signal: $e')),
//       );
//     }
//   }

//   Future<void> _endCall() async {
//     try {
//       if (_peerConnection != null) {
//         await _peerConnection?.close();
//         _peerConnection = null;
//       }

//       if (_localStream != null) {
//         _localStream?.getTracks().forEach((track) => track.stop());
//         _localStream = null;
//       }

//       _localRenderer.srcObject = null;
//       _remoteRenderer.srcObject = null;

//       await _sendSignal({
//         'type': 'end-call',
//         'senderId': widget.currentUserId,
//       });

//       debugPrint('Call ended successfully');
//     } catch (e) {
//       debugPrint('Error ending call: $e');
//     } finally {
//       setState(() {
//         _isCalling = false;
//         _isInCall = false;
//         _isVideoCall = false;
//       });
//     }
//   }

//   Future<void> _sendMessage() async {
//     final text = _messageController.text.trim();
//     if (text.isEmpty) return;

//     if (!_isConnected || !_isSubscribed) {
//       debugPrint('Cannot send message - Pusher not ready');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Connection not ready. Please wait...')),
//       );
//       return;
//     }

//     final message = {
//       'senderId': widget.currentUserId,
//       'content': text,
//     };

//     try {
//       await pusher.trigger(
//         PusherEvent(
//           channelName: _channelName,
//           eventName: 'client-message',
//           data: jsonEncode(message),
//         ),
//       );

//       setState(() {
//         _messages.add({
//           'senderId': widget.currentUserId,
//           'content': text,
//           'timestamp': DateTime.now(),
//         });
//         _messageController.clear();
//       });
//       debugPrint('Message sent: $text');
//     } catch (e) {
//       debugPrint('Error sending message: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to send message: $e')),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _endCall();
//     if (_localRendererInitialized) _localRenderer.dispose();
//     if (_remoteRendererInitialized) _remoteRenderer.dispose();
//     pusher.unsubscribe(channelName: _channelName);
//     pusher.disconnect();
//     _messageController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Chat with ${widget.recipientUser.name}'),
//         actions: [
//           if (!_isInCall && !_isCalling)
//             IconButton(
//               icon: const Icon(Icons.phone),
//               onPressed: () => _startCall(false),
//             ),
//           if (!_isInCall && !_isCalling)
//             IconButton(
//               icon: const Icon(Icons.videocam),
//               onPressed: () => _startCall(true),
//             ),
//           if (_isInCall || _isCalling)
//             IconButton(
//               icon: const Icon(Icons.call_end, color: Colors.red),
//               onPressed: _endCall,
//             ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           Column(
//             children: [
//               // Connection status indicator
//               if (!_isConnected || !_isSubscribed)
//                 Container(
//                   color: Colors.orange,
//                   padding: const EdgeInsets.all(8),
//                   child: const Text(
//                     'Connecting to chat service...',
//                     style: TextStyle(color: Colors.white),
//                   ),
//                 ),

//               // Video call UI
//               if (_isInCall || _isCalling)
//                 Expanded(
//                   child: Container(
//                     color: Colors.black,
//                     child: Stack(
//                       fit: StackFit.expand,
//                       children: [
//                         if (_remoteRendererInitialized)
//                           RTCVideoView(
//                             _remoteRenderer,
//                             objectFit: RTCVideoViewObjectFit
//                                 .RTCVideoViewObjectFitCover,
//                             mirror: false,
//                           ),
//                         if (_localRendererInitialized)
//                           Positioned(
//                             bottom: 20,
//                             right: 20,
//                             width: 120,
//                             height: 160,
//                             child: ClipRRect(
//                               borderRadius: BorderRadius.circular(8),
//                               child: RTCVideoView(
//                                 _localRenderer,
//                                 objectFit: RTCVideoViewObjectFit
//                                     .RTCVideoViewObjectFitCover,
//                                 mirror: true,
//                               ),
//                             ),
//                           ),
//                         if (_isCalling)
//                           Container(
//                             color: Colors.black54,
//                             child: Center(
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   const CircularProgressIndicator(
//                                     color: Colors.white,
//                                   ),
//                                   const SizedBox(height: 20),
//                                   Text(
//                                     _isVideoCall
//                                         ? 'Starting video call...'
//                                         : 'Calling...',
//                                     style: const TextStyle(
//                                       fontSize: 20,
//                                       color: Colors.white,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                       ],
//                     ),
//                   ),
//                 ),

//               // Chat UI
//               if (!_isInCall && !_isCalling) ...[
//                 Expanded(
//                   child: ListView.builder(
//                     padding: const EdgeInsets.only(bottom: 8),
//                     itemCount: _messages.length,
//                     itemBuilder: (context, index) {
//                       final message = _messages[index];
//                       final isSentByCurrentUser =
//                           message['senderId'] == widget.currentUserId;
//                       return Align(
//                         alignment: isSentByCurrentUser
//                             ? Alignment.centerRight
//                             : Alignment.centerLeft,
//                         child: Container(
//                           margin: const EdgeInsets.symmetric(
//                               vertical: 5, horizontal: 10),
//                           padding: const EdgeInsets.all(12),
//                           decoration: BoxDecoration(
//                             color: isSentByCurrentUser
//                                 ? Theme.of(context)
//                                     .primaryColor
//                                     .withOpacity(0.1)
//                                 : Colors.grey[300],
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: Text(
//                             message['content'],
//                             style: TextStyle(
//                               color: isSentByCurrentUser
//                                   ? Theme.of(context).primaryColor
//                                   : Colors.black,
//                             ),
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//                 Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: Theme.of(context).scaffoldBackgroundColor,
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.1),
//                         blurRadius: 8,
//                         offset: const Offset(0, -2),
//                       ),
//                     ],
//                   ),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: TextField(
//                           controller: _messageController,
//                           decoration: InputDecoration(
//                             hintText: 'Type your message...',
//                             border: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(24),
//                               borderSide: BorderSide.none,
//                             ),
//                             filled: true,
//                             fillColor: Colors.grey[200],
//                             contentPadding: const EdgeInsets.symmetric(
//                               horizontal: 16,
//                               vertical: 12,
//                             ),
//                           ),
//                           minLines: 1,
//                           maxLines: 3,
//                         ),
//                       ),
//                       const SizedBox(width: 8),
//                       CircleAvatar(
//                         backgroundColor: Theme.of(context).primaryColor,
//                         child: IconButton(
//                           icon: const Icon(Icons.send, color: Colors.white),
//                           onPressed: _sendMessage,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ],
//           ),

//           // Call controls overlay
//           if (_isInCall)
//             Positioned(
//               bottom: 20,
//               left: 0,
//               right: 0,
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   CircleAvatar(
//                     radius: 28,
//                     backgroundColor: Colors.white.withOpacity(0.2),
//                     child: IconButton(
//                       icon: const Icon(Icons.mic, size: 28),
//                       color: Colors.white,
//                       onPressed: () {
//                         // Implement mute functionality
//                       },
//                     ),
//                   ),
//                   const SizedBox(width: 20),
//                   CircleAvatar(
//                     radius: 32,
//                     backgroundColor: Colors.red,
//                     child: IconButton(
//                       icon: const Icon(Icons.call_end, size: 32),
//                       color: Colors.white,
//                       onPressed: _endCall,
//                     ),
//                   ),
//                   const SizedBox(width: 20),
//                   if (_isVideoCall)
//                     CircleAvatar(
//                       radius: 28,
//                       backgroundColor: Colors.white.withOpacity(0.2),
//                       child: IconButton(
//                         icon: const Icon(Icons.switch_camera, size: 28),
//                         color: Colors.white,
//                         onPressed: () {
//                           // Implement camera switch functionality
//                         },
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
import 'dart:convert';
import 'package:bcalio/controllers/user_controller.dart';
import 'package:bcalio/models/true_user_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final User recipientUser;

  const ChatScreen({
    Key? key,
    required this.currentUserId,
    required this.recipientUser,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final PusherChannelsFlutter pusher = PusherChannelsFlutter.getInstance();
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  late String _channelName;
  bool _isConnected = false;
  bool _isSubscribed = false;

  // WebRTC variables
  RTCPeerConnection? _peerConnection;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isCalling = false;
  bool _isInCall = false;
  bool _isVideoCall = false;
  MediaStream? _localStream;
  bool _localRendererInitialized = false;
  bool _remoteRendererInitialized = false;
  bool _recipientAvailable = false; // Track recipient's presence

  @override
  void initState() {
    super.initState();
    _channelName =
        _generateChannelName(widget.currentUserId, widget.recipientUser.id);
    debugPrint('Channel name: $_channelName');
    _initRenderers();
    _initPusher();
  }

  Future<void> _initRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      setState(() {
        _localRendererInitialized = true;
        _remoteRendererInitialized = true;
      });
      debugPrint('Renderers initialized successfully');
    } catch (e) {
      debugPrint('Error initializing renderers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize video renderers: $e')),
      );
    }
  }

  Future<void> _initPusher() async {
    try {
      // Initialize Pusher with client events enabled
      await pusher.init(
        apiKey: 'bc00b5f6fa3dc2dbbb91',
        cluster: 'eu',
        onAuthorizer: (channelName, socketId, options) async {
          final auth = await getPusherToken(channelName, socketId);
          debugPrint('Pusher auth token: $auth');
          if (auth == null) {
            debugPrint('Failed to get Pusher auth token');
            return {};
          }
          return {'auth': auth};
        },
        onEvent: (PusherEvent event) {
          debugPrint('Event received: ${event.eventName}, data: ${event.data}');
          if (event.eventName == 'client-message' && event.data != null) {
            try {
              final data = jsonDecode(event.data!);
              setState(() {
                _messages.add({
                  'senderId': data['senderId'],
                  'content': data['content'],
                  'timestamp': DateTime.now(),
                });
              });
            } catch (e) {
              debugPrint('Error parsing message: $e');
            }
          } else if (event.eventName == 'client-signal' && event.data != null) {
            _handleSignal(event.data!);
          } else if (event.eventName == 'client-presence' &&
              event.data != null) {
            try {
              final data = jsonDecode(event.data!);
              setState(() {
                _recipientAvailable = data['userId'] == widget.recipientUser.id;
              });
              debugPrint('Recipient presence: $_recipientAvailable');
            } catch (e) {
              debugPrint('Error parsing presence: $e');
            }
          }
        },
        onError: (String message, int? code, dynamic e) {
          debugPrint('Pusher error: $message, code: $code, exception: $e');
          setState(() {
            _isConnected = false;
            _isSubscribed = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Pusher error: $message')),
          );
        },
        onConnectionStateChange: (String? currentState, String? previousState) {
          debugPrint('Pusher connection state: $currentState');
          setState(() {
            _isConnected = currentState == 'CONNECTED';
          });
        },
      );

      // Enable verbose logging for debugging
      // pusher.setLogLevel(LogLevel.VERBOSE);

      // Connect to Pusher
      await pusher.connect();

      // Subscribe to channel
      await pusher.subscribe(
        channelName: _channelName,
        onSubscriptionSucceeded: (data) {
          debugPrint('Subscribed to channel $_channelName');
          setState(() {
            _isSubscribed = true;
          });
          // Announce presence
          _sendPresence();
        },
        onSubscriptionError: (String message, dynamic e) {
          debugPrint('Subscription error: $message, exception: $e');
          setState(() {
            _isSubscribed = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to subscribe to channel: $message')),
          );
        },
      );
    } catch (e) {
      debugPrint('Pusher init error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize Pusher: $e')),
      );
    }
  }

  Future<void> _sendPresence() async {
    if (!_isConnected || !_isSubscribed) return;
    try {
      await pusher.trigger(
        PusherEvent(
          channelName: _channelName,
          eventName: 'client-presence',
          data: jsonEncode({
            'userId': widget.currentUserId,
          }),
        ),
      );
      debugPrint('Sent presence for user: ${widget.currentUserId}');
    } catch (e) {
      debugPrint('Error sending presence: $e');
    }
  }

  Future<void> _initWebRTC() async {
    try {
      if (!_localRendererInitialized) {
        await _localRenderer.initialize();
        setState(() {
          _localRendererInitialized = true;
        });
      }
      if (!_remoteRendererInitialized) {
        await _remoteRenderer.initialize();
        setState(() {
          _remoteRendererInitialized = true;
        });
      }

      final configuration = {
        "iceServers": [
          {"urls": "stun:stun.l.google.com:19302"},
          {"urls": "stun:stun1.l.google.com:19302"},
          {"urls": "stun:stun2.l.google.com:19302"},
          {"urls": "stun:stun3.l.google.com:19302"},
          {"urls": "stun:stun4.l.google.com:19302"},
        ],
        "iceTransportPolicy": "all",
        "bundlePolicy": "max-bundle",
        "rtcpMuxPolicy": "require",
        "sdpSemantics": "unified-plan"
      };

      _peerConnection = await createPeerConnection(configuration);

      _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) async {
        if (candidate.candidate?.isNotEmpty ?? false) {
          debugPrint('ICE Candidate: ${candidate.candidate}');
          await _sendSignal({
            'type': 'candidate',
            'candidate': {
              'sdpMLineIndex': candidate.sdpMLineIndex,
              'sdpMid': candidate.sdpMid,
              'candidate': candidate.candidate,
            },
            'senderId': widget.currentUserId,
          });
        }
      };

      _peerConnection?.onTrack = (RTCTrackEvent event) {
        debugPrint(
            'Track received: ${event.track.kind}, stream: ${event.streams.isNotEmpty ? event.streams[0].id : 'none'}');
        if (event.streams.isNotEmpty) {
          _remoteRenderer.srcObject = event.streams[0];
          debugPrint('Remote renderer set with stream: ${event.streams[0].id}');
          setState(() => _isInCall = true);
        }
      };

      _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
        debugPrint('ICE Connection State: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          _endCall();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Call disconnected')),
          );
        }
      };

      _peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
        debugPrint('ICE Gathering State: $state');
      };

      _peerConnection?.onSignalingState = (RTCSignalingState state) {
        debugPrint('Signaling State: $state');
      };

      debugPrint('WebRTC initialized successfully');
    } catch (e) {
      debugPrint('WebRTC initialization error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize WebRTC: $e')),
      );
      rethrow;
    }
  }

  String _generateChannelName(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return 'private-chat-${sortedIds[0]}-${sortedIds[1]}';
  }

  Future<String?> getPusherToken(String channelName, String socketId) async {
    try {
      final token = await Get.find<UserController>().getToken();
      var headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      };
      var data = json.encode({
        "socket_id": socketId,
        "channel_name": channelName,
      });

      var dio = Dio();
      var response = await dio.post(
        'https://pusher.b-callio.com/pusher/auth',
        data: data,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        debugPrint('Pusher auth response: ${response.data}');
        final auth = response.data['auth'] as String?;
        if (auth == null || !auth.startsWith('bc00b5f6fa3dc2dbbb91:')) {
          debugPrint('Invalid Pusher auth token format: $auth');
          return null;
        }
        return auth;
      } else {
        debugPrint(
            'Pusher auth failed: ${response.statusCode}, ${response.statusMessage}');
        return null;
      }
    } catch (e) {
      debugPrint('Pusher auth error: $e');
      return null;
    }
  }

  Future<void> _startCall(bool isVideo) async {
    try {
      if (!_isConnected || !_isSubscribed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat service not ready')),
        );
        return;
      }

      if (!_recipientAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Recipient is not available. Notifying them...')),
        );
        await _notifyRecipient(isVideo);
        // Wait briefly to see if recipient joins
        await Future.delayed(const Duration(seconds: 5));
        if (!_recipientAvailable) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Recipient did not join. Please try again later.')),
          );
          return;
        }
      }

      if (_peerConnection == null) await _initWebRTC();

      setState(() {
        _isCalling = true;
        _isVideoCall = isVideo;
      });

      final mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'channelCount': 1,
        },
        'video': isVideo
            ? {
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
                'frameRate': {'ideal': 30},
                'facingMode': 'user',
              }
            : false
      };

      try {
        _localStream =
            await rtc.navigator.mediaDevices.getUserMedia(mediaConstraints);
        _localRenderer.srcObject = _localStream;
        debugPrint('Local stream initialized: ${_localStream?.id}');

        for (final track in _localStream!.getTracks()) {
          await _peerConnection?.addTrack(track, _localStream!);
          debugPrint('Added ${track.kind} track: ${track.id}');
        }

        final offer = await _peerConnection!.createOffer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': _isVideoCall,
        });
        await _peerConnection!.setLocalDescription(offer);
        debugPrint('Local description set: ${offer.type}, SDP: ${offer.sdp}');

        await _sendSignal({
          'type': 'offer',
          'description': {
            'sdp': offer.sdp,
            'type': offer.type,
          },
          'senderId': widget.currentUserId,
        });

        // Timeout if no answer is received
        Future.delayed(const Duration(seconds: 30), () {
          if (_isCalling && !_isInCall) {
            _endCall();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Call timed out. Recipient did not answer.')),
            );
          }
        });
      } catch (e) {
        debugPrint('Error getting media or creating offer: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to access camera/microphone: $e')),
        );
        _endCall();
        rethrow;
      }
    } catch (e) {
      debugPrint('Error starting call: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start call: $e')),
      );
      _endCall();
    }
  }

  Future<void> _notifyRecipient(bool isVideo) async {
    // Placeholder for notifying recipient via push notification or backend
    try {
      final token = await Get.find<UserController>().getToken();
      var headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      var data = json.encode({
        'recipientId': widget.recipientUser.id,
        'callerId': widget.currentUserId,
        'callType': isVideo ? 'video' : 'audio',
        'channelName': _channelName,
      });

      var dio = Dio();
      var response = await dio.post(
        'https://your-backend.com/notify-call', // Replace with your backend endpoint
        data: data,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        debugPrint(
            'Notification sent to recipient: ${widget.recipientUser.id}');
      } else {
        debugPrint('Failed to send notification: ${response.statusMessage}');
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  Future<void> _handleSignal(String data) async {
    try {
      final signal = jsonDecode(data);
      if (signal['senderId'] == widget.currentUserId) return;

      debugPrint('Received signal: ${signal['type']}');

      switch (signal['type']) {
        case 'offer':
          await _handleOffer(signal['description']);
          break;
        case 'answer':
          await _handleAnswer(signal['description']);
          break;
        case 'candidate':
          await _handleCandidate(signal['candidate']);
          break;
        case 'end-call':
          _endCall();
          break;
        default:
          debugPrint('Unknown signal type: ${signal['type']}');
      }
    } catch (e) {
      debugPrint('Error handling signal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to handle signal: $e')),
      );
    }
  }

  Future<void> _handleOffer(dynamic description) async {
    try {
      if (_peerConnection == null) await _initWebRTC();

      debugPrint('Setting remote description: ${description['sdp']}');
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(description['sdp'], description['type']),
      );

      if (_localStream == null) {
        final mediaConstraints = {
          'audio': true,
          'video': _isVideoCall,
        };
        _localStream =
            await rtc.navigator.mediaDevices.getUserMedia(mediaConstraints);
        _localRenderer.srcObject = _localStream;
        debugPrint('Local stream initialized for answer: ${_localStream?.id}');

        for (final track in _localStream!.getTracks()) {
          await _peerConnection?.addTrack(track, _localStream!);
          debugPrint('Added ${track.kind} track for answer: ${track.id}');
        }
      }

      final answer = await _peerConnection!.createAnswer();
      debugPrint('Created answer: ${answer.sdp}');
      await _peerConnection!.setLocalDescription(answer);

      await _sendSignal({
        'type': 'answer',
        'description': {
          'sdp': answer.sdp,
          'type': answer.type,
        },
        'senderId': widget.currentUserId,
      });

      setState(() {
        _isInCall = true;
        _isCalling = false;
      });
    } catch (e) {
      debugPrint('Error handling offer: $e');
      _endCall();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to handle offer: $e')),
      );
    }
  }

  Future<void> _handleAnswer(dynamic description) async {
    if (_peerConnection == null) return;

    try {
      debugPrint(
          'Setting remote description for answer: ${description['sdp']}');
      await _peerConnection?.setRemoteDescription(
        RTCSessionDescription(description['sdp'], description['type']),
      );

      setState(() {
        _isInCall = true;
        _isCalling = false;
      });
    } catch (e) {
      debugPrint('Error handling answer: $e');
      _endCall();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to handle answer: $e')),
      );
    }
  }

  Future<void> _handleCandidate(dynamic candidate) async {
    if (_peerConnection == null) return;

    try {
      await _peerConnection?.addCandidate(
        RTCIceCandidate(
          candidate['candidate'],
          candidate['sdpMid'],
          candidate['sdpMLineIndex'],
        ),
      );
      debugPrint('Added ICE candidate: ${candidate['candidate']}');
    } catch (e) {
      debugPrint('Error handling candidate: $e');
    }
  }

  Future<void> _sendSignal(Map<String, dynamic> signal) async {
    if (!_isConnected || !_isSubscribed) {
      debugPrint('Cannot send signal - Pusher not ready');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection not ready')),
      );
      return;
    }

    try {
      await pusher.trigger(
        PusherEvent(
          channelName: _channelName,
          eventName: 'client-signal',
          data: jsonEncode(signal),
        ),
      );
      debugPrint('Sent signal: ${signal['type']}');
    } catch (e) {
      debugPrint('Error sending signal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send signal: $e')),
      );
    }
  }

  Future<void> _endCall() async {
    try {
      if (_peerConnection != null) {
        await _peerConnection?.close();
        _peerConnection = null;
      }

      if (_localStream != null) {
        _localStream?.getTracks().forEach((track) => track.stop());
        _localStream = null;
      }

      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;

      await _sendSignal({
        'type': 'end-call',
        'senderId': widget.currentUserId,
      });

      debugPrint('Call ended successfully');
    } catch (e) {
      debugPrint('Error ending call: $e');
    } finally {
      setState(() {
        _isCalling = false;
        _isInCall = false;
        _isVideoCall = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (!_isConnected || !_isSubscribed) {
      debugPrint('Cannot send message - Pusher not ready');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection not ready. Please wait...')),
      );
      return;
    }

    final message = {
      'senderId': widget.currentUserId,
      'content': text,
    };

    try {
      await pusher.trigger(
        PusherEvent(
          channelName: _channelName,
          eventName: 'client-message',
          data: jsonEncode(message),
        ),
      );

      setState(() {
        _messages.add({
          'senderId': widget.currentUserId,
          'content': text,
          'timestamp': DateTime.now(),
        });
        _messageController.clear();
      });
      debugPrint('Message sent: $text');
    } catch (e) {
      debugPrint('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  @override
  void dispose() {
    _endCall();
    if (_localRendererInitialized) _localRenderer.dispose();
    if (_remoteRendererInitialized) _remoteRenderer.dispose();

    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Build called===========================${_recipientAvailable}');
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.recipientUser.name}'),
        actions: [
          if (!_isInCall && !_isCalling)
            IconButton(
              icon: const Icon(Icons.phone),
              onPressed: _recipientAvailable ? () => _startCall(false) : null,
              tooltip:
                  _recipientAvailable ? 'Audio Call' : 'Recipient Unavailable',
            ),
          if (!_isInCall && !_isCalling)
            IconButton(
              icon: const Icon(Icons.videocam),
              onPressed: _recipientAvailable ? () => _startCall(true) : null,
              tooltip:
                  _recipientAvailable ? 'Video Call' : 'Recipient Unavailable',
            ),
          if (_isInCall || _isCalling)
            IconButton(
              icon: const Icon(Icons.call_end, color: Colors.red),
              onPressed: _endCall,
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Connection status indicator
              if (!_isConnected || !_isSubscribed)
                Container(
                  color: Colors.orange,
                  padding: const EdgeInsets.all(8),
                  child: const Text(
                    'Connecting to chat service...',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              // Recipient availability indicator
              if (_isConnected && _isSubscribed && !_recipientAvailable)
                Container(
                  color: Colors.grey,
                  padding: const EdgeInsets.all(8),
                  child: const Text(
                    'Recipient is not in the chatroom',
                    style: TextStyle(color: Colors.white),
                  ),
                ),

              // Video call UI
              if (_isInCall || _isCalling)
                Expanded(
                  child: Container(
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_remoteRendererInitialized)
                          RTCVideoView(
                            _remoteRenderer,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                            mirror: false,
                          ),
                        if (_localRendererInitialized)
                          Positioned(
                            bottom: 20,
                            right: 20,
                            width: 120,
                            height: 160,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: RTCVideoView(
                                _localRenderer,
                                objectFit: RTCVideoViewObjectFit
                                    .RTCVideoViewObjectFitCover,
                                mirror: true,
                              ),
                            ),
                          ),
                        if (_isCalling)
                          Container(
                            color: Colors.black54,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    _isVideoCall
                                        ? 'Starting video call...'
                                        : 'Calling...',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // Chat UI
              if (!_isInCall && !_isCalling) ...[
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isSentByCurrentUser =
                          message['senderId'] == widget.currentUserId;
                      return Align(
                        alignment: isSentByCurrentUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 5, horizontal: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSentByCurrentUser
                                ? Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.1)
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            message['content'],
                            style: TextStyle(
                              color: isSentByCurrentUser
                                  ? Theme.of(context).primaryColor
                                  : Colors.black,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type your message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[200],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          minLines: 1,
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // Call controls overlay
          if (_isInCall)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: IconButton(
                      icon: const Icon(Icons.mic, size: 28),
                      color: Colors.white,
                      onPressed: () {
                        // Implement mute functionality
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.red,
                    child: IconButton(
                      icon: const Icon(Icons.call_end, size: 32),
                      color: Colors.white,
                      onPressed: _endCall,
                    ),
                  ),
                  const SizedBox(width: 20),
                  if (_isVideoCall)
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: IconButton(
                        icon: const Icon(Icons.switch_camera, size: 28),
                        color: Colors.white,
                        onPressed: () {
                          // Implement camera switch functionality
                        },
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
