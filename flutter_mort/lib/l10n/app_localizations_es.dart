// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class MortLocalizationsEs extends MortLocalizations {
  MortLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'MORT';

  @override
  String get sessionProtected => 'Sesion protegida';

  @override
  String get offlineTitle => 'MORT esta sin conexion';

  @override
  String get offlineSessionPreserved =>
      'MORT no eliminara la sesion guardada cuando la red no este disponible.';

  @override
  String get reconnectAndRetry =>
      'Vuelve a conectarte e intenta otra vez la comprobacion segura de la cuenta.';

  @override
  String get retryAccountCheck => 'Reintentar comprobacion de cuenta';

  @override
  String get configurationRequired => 'Configuracion necesaria';

  @override
  String get secureStartupFailed => 'MORT no puede iniciar de forma segura';

  @override
  String get publicBackendConfigurationInvalid =>
      'La configuracion publica del servidor falta o no es valida.';

  @override
  String get installConfiguredBuild =>
      'Instala una version de MORT configurada correctamente e intenta de nuevo.';

  @override
  String get refreshingSession => 'Actualizando tu sesion...';

  @override
  String get restoringSession => 'Restaurando tu sesion...';

  @override
  String get startingSecurely => 'Iniciando MORT de forma segura...';

  @override
  String get secureStartup => 'Inicio seguro';

  @override
  String get checkingDevice =>
      'Comprobando este dispositivo antes de abrir tu cuenta.';

  @override
  String secureJobPinEntry(int digits) {
    return 'Entrada segura del PIN de trabajo de $digits digitos';
  }

  @override
  String pinDigitsEntered(int entered, int total) {
    return '$entered de $total digitos ingresados';
  }

  @override
  String get deleteLastPinDigit => 'Borrar el ultimo digito del PIN';

  @override
  String pinDigit(String digit) {
    return 'Digito $digit del PIN';
  }
}
