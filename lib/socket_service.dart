import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_service.dart';

class SocketService {
  static io.Socket? _socket;

  static io.Socket get socket => _socket!;
  static bool get isConnected => _socket?.connected ?? false;

  // Sunucudaki Socket.IO gateway'e baglan
  static Future<void> connect() async {
    // Zaten socket nesnesi varsa: bağlı değilse tekrar bağlanmayı dene, yeni nesne OLUŞTURMA
    if (_socket != null) {
      if (!_socket!.connected) {
        _socket!.connect();
      }
      return;
    }

    final token = await ApiService.getToken();
    if (token == null) return;

    _socket = io.io(
      'https://mobildiafon.com',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .build(),
    );

    _socket!.onConnect((_) => print('Socket baglandi'));
    _socket!.onDisconnect((_) => print('Socket koptu'));
    _socket!.onConnectError((e) => print('Socket hata: $e'));
    _socket!.onReconnect((_) => print('Socket yeniden baglandi'));

    _socket!.connect();
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  static void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  static void off(String event) {
    _socket?.off(event);
  }

  static void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }
}