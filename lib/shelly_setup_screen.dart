import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';

/// SHELLY KURULUM SIHIRBAZI
/// Shelly web arayuzune hic girmeden, cihazi MobilDiafon altyapisina baglar:
///   1. Bilgiler: bina secimi, kapi adi, KAPI TIPI (role suresi), bina WiFi
///   2. AP'ye baglan: kullanici telefonu Shelly'nin kendi WiFi'sine baglar
///   3. Yapilandir: 192.168.33.1/rpc uzerinden ayarlar yazilir
///        - Shelly.GetDeviceInfo  -> deviceId (MQTT prefix)
///        - Switch.SetConfig      -> auto_off: N sn (MOMENTARY - KRITIK!)
///        - Mqtt.SetConfig        -> bizim broker (ssl_ca: null = TLS kapali)
///        - Cloud.SetConfig       -> Shelly bulutu kapatilir
///        - Wifi.SetConfig        -> bina WiFi'si, cihaz reboot olur
///   4. Kaydet + dogrula: normal internete donunce add-door + verify
///
/// NOTLAR:
/// - Android: 192.168.33.1'e HTTP (cleartext) istegi gerekiyor.
///   Manifest'te usesCleartextTraffic="true" mevcut.
/// - AP'ye baglanma bu surumde manuel: kullanici WiFi ayarlarindan
///   "ShellyXXX-..." agina baglanir, geri gelir. (Programatik baglanma
///   Android'de WifiNetworkSpecifier ile, ya da BLE provisioning ile
///   sonra eklenebilir.)
/// - MQTT kimlik bilgileri backend'den alinir:
///   POST /door/provision-credentials { buildingId }
///   -> { mqttUser, mqttPassword, mqttServer }
/// - Role suresi CIHAZDA saklanir (auto_off_delay). Internet kesilse bile
///   role kendi kendine birakir - guvenlik acisindan kritik.
class ShellySetupScreen extends StatefulWidget {
  const ShellySetupScreen({super.key});

  @override
  State<ShellySetupScreen> createState() => _ShellySetupScreenState();
}

class _ShellySetupScreenState extends State<ShellySetupScreen> {
  static const _shellyIp = 'http://192.168.33.1';
  static const _red = Color(0xFFE63946);

  int _step = 0; // 0: bilgiler, 1: AP baglan, 2: yapilandir, 3: kaydet/sonuc

  // Adim 1 verileri
  List<dynamic> _buildings = [];
  String? _buildingId;
  final _doorNameCtrl = TextEditingController(text: 'Bina Girisi');
  final _ssidCtrl = TextEditingController();
  final _wifiPassCtrl = TextEditingController();
  bool _loadingBuildings = true;

  // Kapi tipi -> role cekme suresi (saniye)
  double _pulseSeconds = 2;
  bool _customPulse = false;
  final _customPulseCtrl = TextEditingController(text: '3');
  // Backend'den alinan MQTT kimlikleri
  String? _mqttServer;
  String? _mqttUser;
  String? _mqttPassword;

  // Adim 3 durumu
  final List<_ProvisionStep> _provisionSteps = [];
  bool _provisioning = false;
  String? _deviceId; // or. shelly1g3-a8032ab12345

  // Adim 4 durumu
  bool _saving = false;
  String? _resultMessage;
  bool _resultOk = false;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  @override
  void dispose() {
    _doorNameCtrl.dispose();
    _ssidCtrl.dispose();
    _wifiPassCtrl.dispose();
    _customPulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBuildings() async {
    try {
      final list = await ApiService.myHomes(); // zaten List<dynamic> doner
      setState(() {
        _buildings = list;
        _loadingBuildings = false;
        if (list.length == 1) {
          _buildingId = (list.first['buildingId'] ?? list.first['id'])?.toString();
        }
      });
    } catch (_) {
      setState(() => _loadingBuildings = false);
    }
  }

  // ---------- ADIM 1 -> 2: MQTT kimliklerini backend'den al ----------
  Future<void> _fetchCredentialsAndNext() async {
    if (_buildingId == null || _doorNameCtrl.text.trim().isEmpty || _ssidCtrl.text.trim().isEmpty) {
      _snack('Bina, kapi adi ve WiFi adi zorunlu');
      return;
    }
    if (_customPulse) {
      final v = double.tryParse(_customPulseCtrl.text.replaceAll(',', '.'));
      if (v == null || v < 0.5 || v > 60) {
        _snack('Ozel sure 0.5 ile 60 saniye arasinda olmali');
        return;
      }
      _pulseSeconds = v;
    }
    setState(() => _saving = true);
    try {
      final res = await ApiService.provisionDoorCredentials(_buildingId!);
      if (res['success'] != true) throw Exception(res['message'] ?? 'Kimlik alinamadi');
      _mqttServer = res['mqttServer'];
      _mqttUser = res['mqttUser'];
      _mqttPassword = res['mqttPassword'];
      setState(() => _step = 1);
    } catch (e) {
      _snack('Hata: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  // ---------- ADIM 3: Shelly'ye RPC yaz ----------
  Future<Map<String, dynamic>> _rpc(String method, [Map<String, dynamic>? params]) async {
    final body = jsonEncode({'id': 1, 'method': method, 'params': ?params});
    final resp = await http
        .post(Uri.parse('$_shellyIp/rpc'),
        headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) {
      throw Exception('$method HTTP ${resp.statusCode}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    if (json.containsKey('error')) {
      throw Exception('$method: ${json['error']?['message'] ?? 'RPC hatasi'}');
    }
    return (json['result'] ?? json) as Map<String, dynamic>;
  }

  Future<void> _runProvisioning() async {
    setState(() {
      _provisioning = true;
      _provisionSteps.clear();
    });

    Future<bool> doStep(String title, Future<void> Function() fn) async {
      final s = _ProvisionStep(title);
      setState(() => _provisionSteps.add(s));
      try {
        await fn();
        setState(() => s.state = _StepState.ok);
        return true;
      } catch (e) {
        setState(() {
          s.state = _StepState.fail;
          s.error = e.toString();
        });
        return false;
      }
    }

    // 1) Cihaza ulas + deviceId al
    var ok = await doStep('Cihaza baglaniliyor', () async {
      final info = await _rpc('Shelly.GetDeviceInfo');
      _deviceId = (info['id'] ?? '').toString();
      if (_deviceId == null || _deviceId!.isEmpty) {
        throw Exception('Cihaz kimligi okunamadi');
      }
    });
    if (!ok) return _endProvisioning();

    // 2) MOMENTARY - kapi icin en kritik ayar.
    //    Role secilen sure kadar cekip birakir.
    //    Bu ayar yazilmazsa "Ac" komutu roleyi CEKILI BIRAKIR!
    ok = await doStep('Kapi modu (momentary ${_pulseLabel()})', () async {
      await _rpc('Switch.SetConfig', {
        'id': 0,
        'config': {
          'initial_state': 'off',
          'auto_off': true,
          'auto_off_delay': _pulseSeconds,
          'in_mode': 'detached',
        },
      });
    });
    if (!ok) return _endProvisioning();

    // 3) MQTT -> bizim broker
    ok = await doStep('Sunucu baglantisi (MQTT)', () async {
      await _rpc('Mqtt.SetConfig', {
        'config': {
          'enable': true,
          'ssl_ca': null, // TLS kapali (bizim broker duz MQTT dinliyor)
          'server': _mqttServer,
          'user': _mqttUser,
          'pass': _mqttPassword,
          'topic_prefix': _deviceId, // adapter deviceId/rpc bekliyor
          'rpc_ntf': true,
          'status_ntf': false,
          'enable_control': true,
        },
      });
    });
    if (!ok) return _endProvisioning();

    // 4) Shelly bulutunu kapat (tamamen bizim altyapi)
    await doStep('Shelly bulutu kapatiliyor', () async {
      await _rpc('Cloud.SetConfig', {
        'config': {'enable': false},
      });
    });

    // 5) Bina WiFi'si - EN SONA yazdik cunku cihaz reboot olup AP'yi kapatir
    ok = await doStep('Bina WiFi ayari (cihaz yeniden baslar)', () async {
      await _rpc('Wifi.SetConfig', {
        'config': {
          'sta': {
            'ssid': _ssidCtrl.text.trim(),
            'pass': _wifiPassCtrl.text,
            'enable': true,
          },
          'ap': {'enable': false},
        },
      });
      // Bazi firmware'ler SetConfig sonrasi otomatik reboot etmez:
      try {
        await _rpc('Shelly.Reboot');
      } catch (_) {/* reboot cagrisinda baglanti kopmasi normaldir */}
    });

    _endProvisioning(success: ok);
  }

  void _endProvisioning({bool success = false}) {
    setState(() {
      _provisioning = false;
      if (success) _step = 3;
    });
  }

  // ---------- ADIM 4: kaydet + dogrula ----------
  Future<void> _saveAndVerify() async {
    if (_deviceId == null || _buildingId == null) return;
    setState(() {
      _saving = true;
      _resultMessage = null;
    });
    try {
      // Cihazin binanin WiFi'sine baglanip broker'a ulasmasi icin bekle
      await Future.delayed(const Duration(seconds: 8));

      final add = await ApiService.addDoor(
        buildingId: _buildingId!,
        name: _doorNameCtrl.text.trim(),
        deviceId: _deviceId!,
        adapter: 'shelly',
        mqttUser: _mqttUser, // ACL yazimi icin backend'e gonderiliyor
      );
      if (add['success'] != true) {
        throw Exception(add['message'] ?? 'Kapi kaydedilemedi');
      }

      // Sureyi kapi kaydina da isle (yonetim ekraninda gorunsun)
      final doorId = (add['door']?['id'] ?? '').toString();
      if (doorId.isNotEmpty) {
        try {
          await ApiService.setDoorPulse(doorId, _pulseSeconds);
        } catch (_) {
          // Sure cihaza zaten yazildi; DB kaydi basarisiz olursa kritik degil
        }
      }

      // Backend uzerinden canlilik dogrulamasi (ShellyMqttAdapter.verify)
      final v = await ApiService.verifyDoor(_deviceId!);
      final online = v['ok'] == true || v['online'] == true;
      setState(() {
        _resultOk = true;
        _resultMessage = online
            ? 'Kapi kuruldu ve cihaz cevrimici. Evlerim ekranindan "Kapiyi Ac" ile test edebilirsiniz.'
            : 'Kapi kaydedildi ancak cihaz henuz cevrimici gorunmuyor. Cihazin WiFi\'ye baglanmasi 1-2 dakika surebilir; Evlerim ekranindan tekrar deneyin.';
      });
    } catch (e) {
      setState(() {
        _resultOk = false;
        _resultMessage = 'Hata: $e';
      });
    } finally {
      setState(() => _saving = false);
    }
  }

  String _pulseLabel() {
    if (_pulseSeconds == _pulseSeconds.roundToDouble()) {
      return '${_pulseSeconds.toInt()} sn';
    }
    return '$_pulseSeconds sn';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ============================= UI =============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shelly Kapi Kurulumu')),
      body: SafeArea(
        child: Column(
          children: [
            _stepIndicator(),
            const Divider(height: 1),
            Expanded(
              child: IndexedStack(
                index: _step,
                children: [
                  _stepInfo(),
                  _stepConnectAp(),
                  _stepProvision(),
                  _stepFinish(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepIndicator() {
    const titles = ['Bilgiler', 'Baglan', 'Yapilandir', 'Bitir'];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: List.generate(4, (i) {
          final active = i == _step;
          final done = i < _step;
          return Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: done || active ? _red : Colors.grey.shade300,
                  child: done
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text('${i + 1}',
                      style: TextStyle(
                          fontSize: 13,
                          color: active ? Colors.white : Colors.grey.shade600)),
                ),
                const SizedBox(height: 4),
                Text(titles[i],
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ---- ADIM 1 UI ----
  Widget _stepInfo() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Kapi bilgileri',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_loadingBuildings)
          const Center(child: CircularProgressIndicator())
        else
          DropdownButtonFormField<String>(
            initialValue: _buildingId,
            decoration: const InputDecoration(
                labelText: 'Bina', border: OutlineInputBorder()),
            items: _buildings.map<DropdownMenuItem<String>>((b) {
              final id = (b['buildingId'] ?? b['id']).toString();
              final name =
              (b['buildingName'] ?? b['name'] ?? 'Bina').toString();
              return DropdownMenuItem(value: id, child: Text(name));
            }).toList(),
            onChanged: (v) => setState(() => _buildingId = v),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _doorNameCtrl,
          decoration: const InputDecoration(
              labelText: 'Kapi adi (or. Bina Girisi)',
              border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<double>(
          initialValue: _customPulse ? -1.0 : _pulseSeconds,
          decoration: const InputDecoration(
              labelText: 'Kapi tipi (role suresi)',
              border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 1.0, child: Text('Motor tetikleme (1 sn)')),
            DropdownMenuItem(value: 2.0, child: Text('Kilit dili / buzzer (2 sn)')),
            DropdownMenuItem(value: 5.0, child: Text('Manyetik kilit (5 sn)')),
            DropdownMenuItem(value: 8.0, child: Text('Genis kapi / bahce (8 sn)')),
            DropdownMenuItem(value: -1.0, child: Text('Ozel sure gir...')),
          ],
          onChanged: (v) => setState(() {
            if (v == -1.0) {
              _customPulse = true;
            } else {
              _customPulse = false;
              _pulseSeconds = v ?? 2;
            }
          }),
        ),
        if (_customPulse) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customPulseCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Sure (saniye)',
              hintText: 'or. 3 veya 0.5',
              border: OutlineInputBorder(),
              suffixText: 'sn',
            ),
            onChanged: (t) {
              final v = double.tryParse(t.replaceAll(',', '.'));
              if (v != null && v >= 0.5 && v <= 60) {
                setState(() => _pulseSeconds = v);
              }
            },
          ),
        ],
        const SizedBox(height: 20),
        const Text('Binanin WiFi bilgileri',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          'Shelly cihazi bu aga baglanacak. 2.4 GHz bir ag olmali (Shelly 5 GHz desteklemez).',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ssidCtrl,
          decoration: const InputDecoration(
              labelText: 'WiFi adi (SSID)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _wifiPassCtrl,
          obscureText: true,
          decoration: const InputDecoration(
              labelText: 'WiFi sifresi', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            onPressed: _saving ? null : _fetchCredentialsAndNext,
            child: _saving
                ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : const Text('Devam', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // ---- ADIM 2 UI ----
  Widget _stepConnectAp() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Shelly agina baglanin',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _instruction('1', 'Shelly cihazina enerji verin ve ~1 dakika bekleyin.'),
        _instruction('2',
            'Telefonun WiFi ayarlarini acin ve "Shelly..." ile baslayan aga baglanin (sifresizdir).'),
        _instruction('3',
            '"Internet yok" uyarisi cikarsa "Yine de bagli kal" secin.'),
        _instruction('4', 'Bu ekrana geri donup "Baglandim" butonuna basin.'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Onemli: Mobil veriyi gecici olarak kapatmaniz gerekebilir; bazi telefonlar '
                '"internetsiz" WiFi yerine mobil veriyi kullanir ve cihaza ulasilamaz.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            onPressed: () {
              setState(() => _step = 2);
              _runProvisioning();
            },
            child: const Text('Baglandim, kuruluma basla',
                style: TextStyle(color: Colors.white)),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _step = 0),
          child: const Text('Geri'),
        ),
      ],
    );
  }

  Widget _instruction(String no, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
              radius: 11,
              backgroundColor: _red,
              child: Text(no,
                  style: const TextStyle(fontSize: 12, color: Colors.white))),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14.5))),
        ],
      ),
    );
  }

  // ---- ADIM 3 UI ----
  Widget _stepProvision() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Cihaz yapilandiriliyor',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._provisionSteps.map((s) => ListTile(
          dense: true,
          leading: s.state == _StepState.running
              ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(
              s.state == _StepState.ok
                  ? Icons.check_circle
                  : Icons.error,
              color: s.state == _StepState.ok
                  ? Colors.green
                  : Colors.red),
          title: Text(s.title),
          subtitle: s.error != null
              ? Text(s.error!,
              style: const TextStyle(color: Colors.red, fontSize: 12))
              : null,
        )),
        const SizedBox(height: 16),
        if (!_provisioning &&
            _provisionSteps.any((s) => s.state == _StepState.fail))
          Column(
            children: [
              const Text(
                'Kurulum tamamlanamadi. Telefonun hala Shelly agina bagli oldugundan emin olun.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _red),
                  onPressed: _runProvisioning,
                  child: const Text('Tekrar dene',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _step = 1),
                child: const Text('Geri'),
              ),
            ],
          ),
      ],
    );
  }

  // ---- ADIM 4 UI ----
  Widget _stepFinish() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Son adim: kaydet ve dogrula',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _instruction('1',
            'Telefonunuzu normal internete geri baglayin (Shelly agindan cikin, mobil veriyi acin veya ev WiFi\'nizi secin).'),
        _instruction('2', 'Asagidaki "Kaydet ve dogrula" butonuna basin.'),
        const SizedBox(height: 8),
        if (_deviceId != null)
          Text('Cihaz: $_deviceId   |   Role: ${_pulseLabel()}',
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 20),
        if (_resultMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _resultOk ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_resultMessage!, style: const TextStyle(fontSize: 14)),
          ),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            onPressed: _saving ? null : _saveAndVerify,
            child: _saving
                ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : Text(_resultOk ? 'Tekrar dogrula' : 'Kaydet ve dogrula',
                style: const TextStyle(color: Colors.white)),
          ),
        ),
        if (_resultOk)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Bitti'),
              ),
            ),
          ),
      ],
    );
  }
}

enum _StepState { running, ok, fail }

class _ProvisionStep {
  _ProvisionStep(this.title);
  final String title;
  _StepState state = _StepState.running;
  String? error;
}