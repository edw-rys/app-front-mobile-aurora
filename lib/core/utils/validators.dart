/// Validators for the app
class Validators {
  Validators._();

  /// Validate email format
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'El correo es requerido';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  /// Validate password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }
    if (value.length < 4) {
      return 'Mínimo 4 caracteres';
    }
    return null;
  }

  /// Validate reading consumption
  /// Returns: 'negative', 'high', or 'ok'
  static ConsumptionResult validateConsumption(int? currentReading, int? previousReading) {
    if (currentReading == null) {
      return ConsumptionResult.ok;
    }
    final previous = previousReading ?? 0;
    final consumption = currentReading - previous;

    if (consumption < 0) {
      return ConsumptionResult.negative;
    }
    if (consumption > 100) {
      return ConsumptionResult.high;
    }
    return ConsumptionResult.ok;
  }

  /// Validate reading value is a positive number
  static String? validateReadingValue(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Reading is optional
    }
    final parsed = int.tryParse(value);
    if (parsed == null) {
      return 'Ingresa un número válido';
    }
    if (parsed < 0) {
      return 'La lectura no puede ser negativa';
    }
    return null;
  }
}

enum ConsumptionResult { ok, negative, high }
