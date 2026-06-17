import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_service.dart';

class SocketService {
  static io.Socket? _socket;

  static io.Socket get socket => _socket!;
  static bool get isConnected => _socket?.connected ?? false;

  // Sunucudaki Socket.IO gateway'e baglan
  static Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final token = await ApiService.getToken();
    if (token == null) return;

    _socket = io.io(
      'http://128.140.127.151:4000',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableForceNew()
          .build(),
    );

    _socket!.onConnect((_) => print('Socket baglandi'));
    _socket!.onDisconnect((_) => print('Socket koptu'));
    _socket!.onConnectError((e) => print('Socket hata: $e'));

    _socket!.connect();
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  // Olay dinle
  static void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  // Olay dinlemeyi birak
  static void off(String event) {
    _socket?.off(event);
  }

  // Olay gonder
  static void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }
}