import 'dart:async';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

class NFCService {
  /// Lee el token JWT del chip NFC
  Future<String?> readNFCToken() async {
    // Verificar disponibilidad de NFC
    bool isAvailable = await NfcManager.instance.isAvailable();

    if (!isAvailable) {
      throw Exception('NFC no disponible en este dispositivo');
    }

    final completer = Completer<String?>();

    // Iniciar sesión NFC - Solo ISO 14443 (NTAG215)
    await NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443},
      noPlatformSoundsAndroid: true,
      onDiscovered: (NfcTag tag) async {
        try {
          // Leer NDEF del tag (Android)
          final ndef = NdefAndroid.from(tag);

          if (ndef == null) {
            throw Exception('Chip NFC no contiene datos NDEF');
          }

          // Intentar leer del caché primero
          var ndefMessage = ndef.cachedNdefMessage;

          // Si no hay mensaje en caché, leer del chip
          if (ndefMessage == null) {
            ndefMessage = await ndef.getNdefMessage();
          }

          if (ndefMessage == null || ndefMessage.records.isEmpty) {
            throw Exception('Chip NFC vacío');
          }

          // Extraer el token JWT del primer record
          final record = ndefMessage.records.first;

          // Para Text Record NDEF, el formato es:
          // Byte 0: Status byte (bit 7: UTF-8 o UTF-16, bits 0-5: longitud código idioma)
          // Bytes 1-N: Código de idioma (ej: "en")
          // Bytes N+1...: Texto real

          String token;
          if (record.payload.isNotEmpty) {
            final statusByte = record.payload[0];
            final languageCodeLength = statusByte & 0x3F; // Últimos 6 bits

            // Saltar status byte + código de idioma
            final textStartIndex = 1 + languageCodeLength;

            if (record.payload.length > textStartIndex) {
              token = String.fromCharCodes(record.payload.skip(textStartIndex));
            } else {
              // Fallback: intentar leer todo excepto los primeros 3 bytes
              token = String.fromCharCodes(record.payload.skip(3));
            }
          } else {
            throw Exception('Record vacío');
          }

          // Detener sesión
          await NfcManager.instance.stopSession(
            alertMessageIos: 'Chip leído correctamente',
          );
          completer.complete(token);
        } catch (e) {
          await NfcManager.instance.stopSession(
            errorMessageIos: 'Error: ${e.toString()}',
          );
          completer.completeError(e);
        }
      },
    );

    // Esperar resultado con timeout de 60 segundos
    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        NfcManager.instance.stopSession(
          errorMessageIos: 'Tiempo de espera agotado',
        );
        throw Exception('No se detectó ningún chip NFC');
      },
    );
  }
}
