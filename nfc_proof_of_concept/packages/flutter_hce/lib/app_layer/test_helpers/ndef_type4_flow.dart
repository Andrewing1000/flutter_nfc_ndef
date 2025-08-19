import 'dart:typed_data';

import '../../hce_manager.dart';
import '../utils/apdu_command_parser.dart';


class NdefType4ReaderFlow {
  final Uint8List aid;
  final int chunkSize;
  NdefType4ReaderFlow({required this.aid, this.chunkSize = 240});

  Future<Uint8List> readAll() async {
    final hce = FlutterHceManager.instance;

    final selectAID = ApduCommandParser.selectByName(applicationId: aid);
    await hce.processApdu(selectAID.toBytes());

    final selectCc = ApduCommandParser.selectCapabilityContainer();
    await hce.processApdu(selectCc.toBytes());

    final readCc = ApduCommandParser.readCapabilityContainer();
    await hce.processApdu(readCc.toBytes());

    final selectNdef = ApduCommandParser.selectNdefFile();
    await hce.processApdu(selectNdef.toBytes());

    final readLen = ApduCommandParser.readNdefLength();
    final lenResp = await hce.processApdu(readLen.toBytes());
    final respBytes = lenResp.buffer;
    if (respBytes.length < 4) {
      throw Exception('Unexpected length reading NLEN');
    }
    final nlen = (respBytes[0] << 8) + respBytes[1];

    final result = BytesBuilder();
    result.add([respBytes[0], respBytes[1]]);
    int offset = 2;
    while (offset < nlen + 2) {
      final remaining = (nlen + 2) - offset;
      final toRead = remaining > chunkSize ? chunkSize : remaining;
      final readChunk =
          ApduCommandParser.readChunk(offset: offset, chunkSize: toRead);
      final chunkResp = await hce.processApdu(readChunk.toBytes());
      final raw = chunkResp.buffer;
      // strip SW 0x9000
      final data = raw.sublist(0, raw.length - 2);
      result.add(data);
      offset += toRead;
    }

    return result.toBytes();
  }
}
