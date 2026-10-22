import 'package:mprs_android/model/notification_item.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Local inbox — survives logout; shipment rows are never overwritten on sync.
class NotificationDB {
  static final NotificationDB instance = NotificationDB._internal();
  static Database? _db;

  NotificationDB._internal();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'notification.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notifications (
            id TEXT PRIMARY KEY,
            notificationId TEXT,
            notificationTempId TEXT,
            messageHeader TEXT,
            messageBody TEXT,
            link TEXT,
            scheduledDate TEXT,
            scheduledTime TEXT,
            isActive INTEGER,
            isApproved INTEGER,
            status TEXT,
            createdBy TEXT,
            lastUpdatedBy TEXT,
            createdAt TEXT,
            updatedAt TEXT,
            targetUsers TEXT,
            ownerAccountId TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE notifications ADD COLUMN targetUsers TEXT',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE notifications ADD COLUMN ownerAccountId TEXT',
          );
        }
      },
    );
  }

  /// Insert or replace (admin / server rows).
  Future<void> insert(NotificationItem item) async {
    final db = await database;
    await db.insert(
      'notifications',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Keep the first arrival time — do not replace an existing row.
  Future<bool> insertIfAbsent(NotificationItem item) async {
    if (item.id.isEmpty) return false;
    if (await existsById(item.id)) return false;
    await insert(item);
    return true;
  }

  /// FCM / admin push — stable key on [notificationId], else [id].
  Future<bool> upsertInboxItem(NotificationItem item) async {
    if (item.id.isEmpty && item.notificationId.isEmpty) return false;

    final keys = <String>{
      if (item.notificationId.isNotEmpty) item.notificationId,
      if (item.id.isNotEmpty) item.id,
    };

    NotificationItem? existing;
    for (final key in keys) {
      existing = await getById(key);
      if (existing != null) break;
    }

    if (existing != null) {
      final merged = NotificationItem(
        id: existing.id,
        notificationId: item.notificationId.isNotEmpty
            ? item.notificationId
            : existing.notificationId,
        notificationTempId: item.notificationTempId.isNotEmpty
            ? item.notificationTempId
            : existing.notificationTempId,
        messageHeader: item.messageHeader.isNotEmpty
            ? item.messageHeader
            : existing.messageHeader,
        messageBody:
            item.messageBody.isNotEmpty ? item.messageBody : existing.messageBody,
        link: item.link.isNotEmpty ? item.link : existing.link,
        scheduledDate: item.scheduledDate,
        scheduledTime: item.scheduledTime,
        targetUsers: item.targetUsers ?? existing.targetUsers,
        isActive: item.isActive,
        isApproved: item.isApproved || existing.isApproved,
        status: item.status.isNotEmpty ? item.status : existing.status,
        createdBy: item.createdBy ?? existing.createdBy,
        lastUpdatedBy: item.lastUpdatedBy,
        createdAt: existing.createdAt,
        updatedAt: item.updatedAt.isAfter(existing.updatedAt)
            ? item.updatedAt
            : existing.updatedAt,
        ownerAccountId: item.ownerAccountId ?? existing.ownerAccountId,
      );
      await insert(merged);
      return false;
    }

    final rowId = item.notificationId.isNotEmpty ? item.notificationId : item.id;
    final toSave = item.notificationId.isNotEmpty && item.id != rowId
        ? NotificationItem(
            id: rowId,
            notificationId: item.notificationId,
            notificationTempId: item.notificationTempId,
            messageHeader: item.messageHeader,
            messageBody: item.messageBody,
            link: item.link,
            scheduledDate: item.scheduledDate,
            scheduledTime: item.scheduledTime,
            targetUsers: item.targetUsers,
            isActive: item.isActive,
            isApproved: item.isApproved,
            status: item.status,
            createdBy: item.createdBy,
            createdByName: item.createdByName,
            lastUpdatedBy: item.lastUpdatedBy,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
            ownerAccountId: item.ownerAccountId,
          )
        : item;
    await insert(toSave);
    return true;
  }

  Future<List<NotificationItem>> getAll() async {
    final db = await database;
    final result = await db.query(
      'notifications',
      orderBy: 'createdAt DESC',
    );

    final items = <NotificationItem>[];
    for (final row in result) {
      try {
        items.add(NotificationItem.fromMap(row));
      } catch (_) {
        // Skip corrupt row so the inbox tab still loads.
      }
    }
    return items;
  }

  /// Server/API rows only — never overwrite shipment inbox cards.
  Future<void> upsertServerItems(List<NotificationItem> items) async {
    for (final item in items) {
      if (item.isShipmentAlert) continue;
      final key = item.notificationId.isNotEmpty ? item.notificationId : item.id;
      if (key.isEmpty) {
        await insertIfAbsent(item);
        continue;
      }
      final existing = await getById(key);
      if (existing != null) {
        final merged = NotificationItem(
          id: existing.id,
          notificationId: item.notificationId.isNotEmpty
              ? item.notificationId
              : existing.notificationId,
          notificationTempId: item.notificationTempId,
          messageHeader: item.messageHeader.isNotEmpty
              ? item.messageHeader
              : existing.messageHeader,
          messageBody:
              item.messageBody.isNotEmpty ? item.messageBody : existing.messageBody,
          link: item.link.isNotEmpty ? item.link : existing.link,
          scheduledDate: item.scheduledDate,
          scheduledTime: item.scheduledTime,
          targetUsers: item.targetUsers ?? existing.targetUsers,
          isActive: item.isActive,
          isApproved: item.isApproved,
          status: item.status.isNotEmpty ? item.status : existing.status,
          createdBy: item.createdBy ?? existing.createdBy,
          lastUpdatedBy: item.lastUpdatedBy,
          createdAt: existing.createdAt,
          updatedAt: item.updatedAt.isAfter(existing.updatedAt)
              ? item.updatedAt
              : existing.updatedAt,
        );
        await insert(merged);
      } else {
        await insertIfAbsent(item);
      }
    }
  }

  Future<NotificationItem?> getById(String id) async {
    if (id.isEmpty) return null;
    final db = await database;
    final rows = await db.query(
      'notifications',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return NotificationItem.fromMap(rows.first);
  }

  Future<bool> existsById(String id) async {
    if (id.isEmpty) return false;
    final db = await database;
    final rows = await db.query(
      'notifications',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Step keys already in inbox for this order (`shipment_{orderId}_{step}`).
  Future<Set<String>> getShipmentStepKeysForOrder(String orderId) async {
    if (orderId.isEmpty) return {};
    final prefix = 'shipment_${orderId}_';
    final all = await getAll();
    final keys = <String>{};
    for (final item in all) {
      if (!item.id.startsWith(prefix)) continue;
      final stepKey = item.id.substring(prefix.length);
      if (stepKey.isNotEmpty) keys.add(stepKey);
    }
    return keys;
  }
}
