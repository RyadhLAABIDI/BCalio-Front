import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../main.dart';

//it wokred
void showSimpleNotification({
  required String senderName,
  required String messageContent,
  required String conversationId,
}) async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'message_channel', // Unique channel ID
    'Messages', // Channel name
    description: 'Notifications for new messages',
    importance: Importance.max,
    playSound: true,
  );

  var androidPlatformChannelSpecifics = AndroidNotificationDetails(
    channel.id,
    channel.name,
    channelDescription: channel.description,
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'New Message Notification',
  );

  var platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  // Show the notification
  // await flutterLocalNotificationsPlugin.show(
  //   0, // Notification ID
  //   senderName, // Title
  //   messageContent, // Body
  //   platformChannelSpecifics,
  //   payload: conversationId,
  // );
}
