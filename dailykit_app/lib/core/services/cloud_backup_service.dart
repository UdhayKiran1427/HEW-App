import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/local_database_service.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class CloudBackupService {
  static final CloudBackupService _instance = CloudBackupService._internal();
  factory CloudBackupService() => _instance;
  CloudBackupService._internal();

  static const String _backupFileName = 'hew_cloud_backup.json';
  static const String _prefLastBackupTime = 'hew_last_cloud_backup_time';
  static const String _prefLastBackupAccount = 'hew_last_cloud_backup_account';
  static const MethodChannel _pickerChannel = MethodChannel('com.dailykit.dailykit_app/file_picker');

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope,
      drive.DriveApi.driveFileScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;

  Future<void> init() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('Silent sign-in error: $e');
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser;
    } catch (e) {
      debugPrint('Google Sign-in error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
    } catch (e) {
      debugPrint('Google Sign-out error: $e');
    }
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    var user = _currentUser ?? await _googleSignIn.signInSilently();
    user ??= await _googleSignIn.signIn();

    if (user == null) return null;
    _currentUser = user;

    final authHeaders = await user.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    return drive.DriveApi(client);
  }

  // ---------------------------------------------------------------------------
  // 1. BACKUP TO GOOGLE DRIVE (Direct API)
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> backupToGoogleDrive() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      throw Exception('Google Sign-In is required to backup to Google Drive.');
    }

    // 1. Export local SQLite data to JSON
    final backupData = await LocalDatabaseService().exportFullBackup();
    final jsonString = jsonEncode(backupData);
    final bytes = utf8.encode(jsonString);

    // 2. Check if file already exists in Drive appDataFolder
    String? existingFileId;
    try {
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName' and trashed = false",
        $fields: 'files(id, name, modifiedTime)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        existingFileId = fileList.files!.first.id;
      }
    } catch (e) {
      debugPrint('Error searching existing backup in appDataFolder: $e');
    }

    final media = drive.Media(Stream.value(bytes), bytes.length);

    drive.File uploadedFile;
    if (existingFileId != null) {
      final fileMetadata = drive.File();
      uploadedFile = await driveApi.files.update(
        fileMetadata,
        existingFileId,
        uploadMedia: media,
      );
    } else {
      final fileMetadata = drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder']
        ..description = 'HEW App Complete Data Backup';
      uploadedFile = await driveApi.files.create(
        fileMetadata,
        uploadMedia: media,
      );
    }

    // 3. Save timestamp to SharedPreferences
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLastBackupTime, now.toIso8601String());
    if (_currentUser?.email != null) {
      await prefs.setString(_prefLastBackupAccount, _currentUser!.email);
    }

    return {
      'fileId': uploadedFile.id,
      'timestamp': now,
      'summary': backupData['summary'],
      'account': _currentUser?.email ?? 'Google Drive',
    };
  }

  // ---------------------------------------------------------------------------
  // 2. RESTORE FROM GOOGLE DRIVE (Direct API)
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> restoreFromGoogleDrive() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      throw Exception('Google Sign-In is required to restore from Google Drive.');
    }

    // Look in appDataFolder
    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName' and trashed = false",
      $fields: 'files(id, name, modifiedTime, size)',
    );

    if (fileList.files == null || fileList.files!.isEmpty) {
      throw Exception('No backup file found in your Google Drive AppData folder.');
    }

    final backupFile = fileList.files!.first;
    final fileId = backupFile.id!;

    final response = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytesList = <int>[];
    await for (final chunk in response.stream) {
      bytesList.addAll(chunk);
    }

    final jsonString = utf8.decode(bytesList);
    final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

    await LocalDatabaseService().importFullBackup(backupData);

    return {
      'modifiedTime': backupFile.modifiedTime,
      'summary': backupData['summary'] ?? {},
    };
  }

  // ---------------------------------------------------------------------------
  // 3. EXPORT & SHARE FILE TO GOOGLE DRIVE / ANY APP (Instant, zero-config)
  // ---------------------------------------------------------------------------
  Future<void> exportAndShareBackup() async {
    final backupData = await LocalDatabaseService().exportFullBackup();
    final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);

    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now();
    final fileName = 'hew_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
    final filePath = '${tempDir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsString(jsonString);

    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'application/json')],
      subject: 'HEW App Data Backup - $fileName',
      text: 'HEW App Backup (${now.day}/${now.month}/${now.year}). Save to Google Drive or safe storage.',
    );
  }

  // ---------------------------------------------------------------------------
  // 4. RESTORE FROM LOCAL OR PICKED BACKUP FILE (Google Drive or Downloads)
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> restoreFromLocalFile() async {
    final result = await _pickerChannel.invokeMethod<Map>('pickBackupFile');

    if (result == null || result['content'] == null) {
      throw Exception('No file selected.');
    }

    final content = result['content'] as String;
    final fileName = (result['name'] as String?) ?? 'backup.json';
    final backupData = jsonDecode(content) as Map<String, dynamic>;

    if (backupData['app'] != 'HEW' && !backupData.containsKey('habits') && !backupData.containsKey('expenses')) {
      throw Exception('Invalid backup file. Missing HEW application data.');
    }

    await LocalDatabaseService().importFullBackup(backupData);

    return {
      'fileName': fileName,
      'summary': backupData['summary'] ?? {},
    };
  }

  // ---------------------------------------------------------------------------
  // GET LAST BACKUP INFO
  // ---------------------------------------------------------------------------
  Future<Map<String, String?>> getLastBackupInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'time': prefs.getString(_prefLastBackupTime),
      'account': prefs.getString(_prefLastBackupAccount),
    };
  }
}
