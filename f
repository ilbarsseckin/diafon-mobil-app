[33mcommit f1690fabacfb3ef672ba9fbc16c12c4d8fcbb598[m
Author: ilbarsseckin <ilbarsseckin@gmail.com>
Date:   Wed Jun 24 08:40:00 2026 +0300

    CallKit kapali-app kapi butonu - buildingId FCM/extra zinciri

[1mdiff --git a/lib/main.dart b/lib/main.dart[m
[1mindex ddab7d0..07f0bc6 100644[m
[1m--- a/lib/main.dart[m
[1m+++ b/lib/main.dart[m
[36m@@ -35,6 +35,7 @@[m [mFuture<void> _firebaseBackgroundHandler(RemoteMessage message) async {[m
       callerName: data['callerName'] ?? 'Bilinmeyen',[m
       callerUserId: data['callerUserId'] ?? '',[m
       callerPhotoUrl: fullPhoto,[m
[32m+[m[32m      buildingId: (data['buildingId'] ?? '').toString(),[m
     );[m
   }[m
 }[m
[36m@@ -400,6 +401,7 @@[m [mclass _HomeScreenState extends State<HomeScreen> {[m
         final callId = (extra['callId'] ?? '').toString();[m
         final callerUserId = (extra['callerUserId'] ?? '').toString();[m
         final callerName = (extra['callerName'] ?? 'Bilinmeyen').toString();[m
[32m+[m[32m        final buildingId = (extra['buildingId'] ?? '').toString();[m
         print('AKTIF CAGRI: callId=$callId callerUserId=$callerUserId');[m
 [m
         if (callId.isNotEmpty && callerUserId.isNotEmpty && mounted) {[m
[36m@@ -412,6 +414,7 @@[m [mclass _HomeScreenState extends State<HomeScreen> {[m
                 peerName: callerName,[m
                 isCaller: false,[m
                 incomingCallId: callId,[m
[32m+[m[32m                buildingId: buildingId.isNotEmpty ? buildingId : null,[m
               ),[m
             ),[m
           );[m
[36m@@ -432,6 +435,7 @@[m [mclass _HomeScreenState extends State<HomeScreen> {[m
         final callId = (extra['callId'] ?? event.callKitParams.id ?? '').toString();[m
         final callerUserId = (extra['callerUserId'] ?? '').toString();[m
         final callerName = (extra['callerName'] ?? 'Bilinmeyen').toString();[m
[32m+[m[32m        final buildingId = (extra['buildingId'] ?? '').toString();[m
         FlutterCallkitIncoming.endCall(callId);[m
         if (mounted) {[m
           Navigator.push([m
[36m@@ -442,6 +446,7 @@[m [mclass _HomeScreenState extends State<HomeScreen> {[m
                 peerName: callerName,[m
                 isCaller: false,[m
                 incomingCallId: callId,[m
[32m+[m[32m                buildingId: buildingId.isNotEmpty ? buildingId : null,[m
               ),[m
             ),[m
           );[m
[36m@@ -483,6 +488,7 @@[m [mclass _HomeScreenState extends State<HomeScreen> {[m
         caller['id'],[m
         callId,[m
         caller['photoUrl']?.toString(),[m
[32m+[m[32m        data['buildingId']?.toString(),[m
       );[m
     });[m
     SocketService.on('call:taken', (data) {[m
[36m@@ -490,7 +496,7 @@[m [mclass _HomeScreenState extends State<HomeScreen> {[m
     });[m
   }[m
 [m
[31m-  void _showIncomingCall(String callerName, String callerId, String callId, [String? photoUrl]) {[m
[32m+[m[32m  void _showIncomingCall(String callerName, String callerId, String callId, [String? photoUrl, String? buildingId]) {[m
     showDialog([m
       context: context,[m
       barrierDismissible: false,[m
[36m@@ -535,6 +541,7 @@[m [mclass _HomeScreenState extends State<HomeScreen> {[m
                     peerName: callerName,[m
                     isCaller: false,[m
                     incomingCallId: callId,[m
[32m+[m[32m                    buildingId: buildingId,[m
                   ),[m
                 ),[m
               );[m
