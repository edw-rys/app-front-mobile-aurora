/// Centralized Spanish strings for the app
class AppStrings {
  AppStrings._();

  // App
  static const String appName = 'Aurora';
  static const String appVersion = '1.0.0';

  // Auth
  static const String loginTitle = 'Inicia sesión';
  static const String emailLabel = 'Correo electrónico';
  static const String emailHint = 'ejemplo@correo.com';
  static const String passwordLabel = 'Contraseña';
  static const String loginButton = 'Entrar';
  static const String forgotPassword = '¿Olvidaste tu contraseña?';
  static const String logoutOtherDevices = 'Cerrar sesión en otros dispositivos';
  static const String loginError = 'El usuario o contraseña es incorrecta';

  // Home
  static const String noPeriod = 'No tienes periodo activo';
  static const String noPeriodDesc = 'Contacte a gerencia para que se le asigne un periodo de lectura.';
  static const String getPeriod = 'Obtener periodo';
  static const String startWork = 'Iniciar trabajo';
  static const String continueReadings = 'Continuar lecturas';
  static const String sendReadings = 'Enviar lecturas';
  static const String viewMap = 'Ver mapa completo';
  static const String currentPeriod = 'Periodo Actual';
  static const String completed = 'Completado';
  static const String metersReadToday = 'Medidores leídos hoy';
  static const String nearbyZones = 'Zonas próximas';
  static const String viewAll = 'Ver todas';
  static const String readingsComplete = 'Lecturas completas';
  static const String pendingSend = 'Pendiente de enviar';

  // Meters
  static const String todayReadings = 'Lecturas de hoy';
  static const String searchPlaceholder = 'Buscar cliente o medidor...';
  static const String all = 'Todos';
  static const String pending = 'Pendientes';
  static const String read = 'Leídos';
  static const String dailyProgress = 'Progreso diario';
  static const String skipToNext = 'Saltar al siguiente';
  static const String newReading = 'Nueva lectura';
  static const String readingEntered = 'Lectura ingresada';
  static const String meterLabel = 'Medidor';
  static const String previousLabel = 'Ant';

  // Meter Detail
  static const String detailTitle = 'Detalle';
  static const String help = 'Ayuda';
  static const String viewOnMap = 'Ver en mapa';
  static const String previousReading = 'Lectura anterior';
  static const String period = 'Periodo';
  static const String optional = 'Opcional';
  static const String notesPlaceholder = 'Notas sobre este medidor...';
  static const String damagedMeter = 'Medidor dañado';
  static const String impossibleAccess = 'Acceso imposible';
  static const String saveAndNext = 'Guardar y siguiente';
  static const String backToList = 'Volver a la lista';

  // Consumption validation
  static const String negativeConsumption = 'Consumo negativo detectado';
  static const String negativeConsumptionDesc = 'La lectura actual es menor a la anterior. Verifique el valor ingresado.';
  static const String highConsumption = 'Consumo alto detectado';
  static const String highConsumptionDesc = 'El consumo es inusualmente alto. ¿Desea continuar?';

  // Sync
  static const String saving = 'Guardando...';
  static const String savedSuccessfully = 'Guardado exitosamente';
  static const String savedLocally = 'Guardado localmente';
  static const String pendingSync = 'pendientes de sincronizar';
  static const String noConnection = 'Sin conexión a internet';
  static const String sendingReading = 'Enviando lectura';
  static const String of_ = 'de';
  static const String syncComplete = 'Sincronización completada';

  // Profile
  static const String profile = 'Perfil';
  static const String personalData = 'Datos personales';
  static const String changePassword = 'Cambiar contraseña';
  static const String previousPeriods = 'Periodos anteriores';
  static const String notifications = 'Notificaciones';
  static const String exportCSV = 'Exportar CSV';
  static const String logout = 'Cerrar sesión';

  // CSV
  static const String csvHeader = 'CLAVE,L. ACTUAL,LEIDA,CONSUMO,MEDIDOR';

  // Errors
  static const String connectionError = 'Error de conexión';
  static const String unexpectedError = 'Error inesperado';
  static const String retry = 'Reintentar';
  static const String noPeriodAvailable = 'No hay periodo de lectura habilitado';

  // Nav
  static const String navHome = 'Inicio';
  static const String navMap = 'Mapa';
  static const String navHistory = 'Historial';
  static const String navProfile = 'Perfil';
  static const String navList = 'Lista';
  static const String navSync = 'Sincronizar';
}
