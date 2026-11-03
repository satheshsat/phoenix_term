import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:termius_app/models/host_model.dart';
import 'package:termius_app/services/sftp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SftpItem Tests', () {
    test('formattedSize formats bytes, KB, MB, and GB properly', () {
      final itemDir = SftpItem(
        name: 'testDir',
        path: '/testDir',
        isDirectory: true,
        size: 4096,
        modifiedTime: DateTime.now(),
        permissions: 'rwxr-xr-x',
      );
      expect(itemDir.formattedSize, '--');

      final itemBytes = SftpItem(
        name: 'small.txt',
        path: '/small.txt',
        isDirectory: false,
        size: 512,
        modifiedTime: DateTime.now(),
        permissions: 'rw-r--r--',
      );
      expect(itemBytes.formattedSize, '512 B');

      final itemKb = SftpItem(
        name: 'script.sh',
        path: '/script.sh',
        isDirectory: false,
        size: 2048,
        modifiedTime: DateTime.now(),
        permissions: 'rwxr-xr-x',
      );
      expect(itemKb.formattedSize, '2.0 KB');

      final itemMb = SftpItem(
        name: 'video.mp4',
        path: '/video.mp4',
        isDirectory: false,
        size: 5 * 1024 * 1024,
        modifiedTime: DateTime.now(),
        permissions: 'rw-r--r--',
      );
      expect(itemMb.formattedSize, '5.0 MB');
    });

    test('extension extracts file extension correctly', () {
      final itemSh = SftpItem(
        name: 'deploy.sh',
        path: '/deploy.sh',
        isDirectory: false,
        size: 100,
        modifiedTime: DateTime.now(),
        permissions: 'rwxr-xr-x',
      );
      expect(itemSh.extension, 'sh');

      final itemDir = SftpItem(
        name: 'my.folder',
        path: '/my.folder',
        isDirectory: true,
        size: 4096,
        modifiedTime: DateTime.now(),
        permissions: 'rwxr-xr-x',
      );
      expect(itemDir.extension, '');
    });
  });

  group('SftpService Virtual Filesystem Tests', () {
    final testHost = HostModel(
      id: 'test_host_1',
      alias: 'Test Server',
      hostname: '192.168.1.100',
      username: 'user',
      createdAt: DateTime.now(),
    );

    test('getInitialDirectory returns expected path for simulated host', () async {
      final initialDir = await SftpService.getInitialDirectory(
        host: testHost,
        isSimulated: true,
      );
      expect(initialDir, '/home/user');
    });

    test('listDirectory lists items in simulated /home/user', () async {
      final items = await SftpService.listDirectory(
        remotePath: '/home/user',
        isSimulated: true,
      );
      expect(items, isNotEmpty);
      expect(items.any((i) => i.name == 'deploy.sh'), isTrue);
    });

    test('writeFile and readFile work seamlessly in simulated mode', () async {
      final testPath = '/home/user/test_note.txt';
      final testContent = 'Hello from Phoenix Term SFTP!';
      final testBytes = Uint8List.fromList(utf8.encode(testContent));

      await SftpService.writeFile(
        remotePath: testPath,
        bytes: testBytes,
        isSimulated: true,
      );

      final readBytes = await SftpService.readFile(
        remotePath: testPath,
        isSimulated: true,
      );

      expect(utf8.decode(readBytes), testContent);
    });

    test('createDirectory, rename, and deleteItem work in simulated mode', () async {
      final newDir = '/home/user/temp_folder';
      await SftpService.createDirectory(
        path: newDir,
        isSimulated: true,
      );

      var list = await SftpService.listDirectory(
        remotePath: '/home/user',
        isSimulated: true,
      );
      expect(list.any((i) => i.name == 'temp_folder' && i.isDirectory), isTrue);

      final renamedDir = '/home/user/renamed_folder';
      await SftpService.rename(
        oldPath: newDir,
        newPath: renamedDir,
        isSimulated: true,
      );

      list = await SftpService.listDirectory(
        remotePath: '/home/user',
        isSimulated: true,
      );
      expect(list.any((i) => i.name == 'temp_folder'), isFalse);
      expect(list.any((i) => i.name == 'renamed_folder' && i.isDirectory), isTrue);

      final itemToDelete = list.firstWhere((i) => i.name == 'renamed_folder');
      await SftpService.deleteItem(
        item: itemToDelete,
        isSimulated: true,
      );

      list = await SftpService.listDirectory(
        remotePath: '/home/user',
        isSimulated: true,
      );
      expect(list.any((i) => i.name == 'renamed_folder'), isFalse);
    });
  });
}

