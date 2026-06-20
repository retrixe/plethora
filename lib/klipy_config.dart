import 'package:envied/envied.dart';

part 'klipy_config.g.dart';

@Envied(path: 'tool/klipy.env')
abstract class KlipyConfig {
  @EnviedField(varName: 'KLIPY_APP_KEY', defaultValue: '')
  static const String appKey = _KlipyConfig.appKey;
}
