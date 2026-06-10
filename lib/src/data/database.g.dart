// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PeersTable extends Peers with TableInfo<$PeersTable, Peer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nicknameMeta = const VerificationMeta(
    'nickname',
  );
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
    'nickname',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _identityPublicKeyMeta = const VerificationMeta(
    'identityPublicKey',
  );
  @override
  late final GeneratedColumn<Uint8List> identityPublicKey =
      GeneratedColumn<Uint8List>(
        'identity_public_key',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _boxPublicKeyMeta = const VerificationMeta(
    'boxPublicKey',
  );
  @override
  late final GeneratedColumn<Uint8List> boxPublicKey =
      GeneratedColumn<Uint8List>(
        'box_public_key',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastSeenMsMeta = const VerificationMeta(
    'lastSeenMs',
  );
  @override
  late final GeneratedColumn<int> lastSeenMs = GeneratedColumn<int>(
    'last_seen_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    nickname,
    identityPublicKey,
    boxPublicKey,
    lastSeenMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'peers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Peer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('nickname')) {
      context.handle(
        _nicknameMeta,
        nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta),
      );
    }
    if (data.containsKey('identity_public_key')) {
      context.handle(
        _identityPublicKeyMeta,
        identityPublicKey.isAcceptableOrUnknown(
          data['identity_public_key']!,
          _identityPublicKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_identityPublicKeyMeta);
    }
    if (data.containsKey('box_public_key')) {
      context.handle(
        _boxPublicKeyMeta,
        boxPublicKey.isAcceptableOrUnknown(
          data['box_public_key']!,
          _boxPublicKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_boxPublicKeyMeta);
    }
    if (data.containsKey('last_seen_ms')) {
      context.handle(
        _lastSeenMsMeta,
        lastSeenMs.isAcceptableOrUnknown(
          data['last_seen_ms']!,
          _lastSeenMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Peer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Peer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      nickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nickname'],
      ),
      identityPublicKey: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}identity_public_key'],
      )!,
      boxPublicKey: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}box_public_key'],
      )!,
      lastSeenMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_ms'],
      ),
    );
  }

  @override
  $PeersTable createAlias(String alias) {
    return $PeersTable(attachedDatabase, alias);
  }
}

class Peer extends DataClass implements Insertable<Peer> {
  final String id;

  /// The name the peer announced for themselves (via an `announceName`
  /// envelope), or null until they announce one.
  final String? displayName;

  /// A local nickname the user set for this peer, overriding [displayName].
  /// Never leaves the device.
  final String? nickname;
  final Uint8List identityPublicKey;
  final Uint8List boxPublicKey;
  final int? lastSeenMs;
  const Peer({
    required this.id,
    this.displayName,
    this.nickname,
    required this.identityPublicKey,
    required this.boxPublicKey,
    this.lastSeenMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || nickname != null) {
      map['nickname'] = Variable<String>(nickname);
    }
    map['identity_public_key'] = Variable<Uint8List>(identityPublicKey);
    map['box_public_key'] = Variable<Uint8List>(boxPublicKey);
    if (!nullToAbsent || lastSeenMs != null) {
      map['last_seen_ms'] = Variable<int>(lastSeenMs);
    }
    return map;
  }

  PeersCompanion toCompanion(bool nullToAbsent) {
    return PeersCompanion(
      id: Value(id),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      nickname: nickname == null && nullToAbsent
          ? const Value.absent()
          : Value(nickname),
      identityPublicKey: Value(identityPublicKey),
      boxPublicKey: Value(boxPublicKey),
      lastSeenMs: lastSeenMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenMs),
    );
  }

  factory Peer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Peer(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      nickname: serializer.fromJson<String?>(json['nickname']),
      identityPublicKey: serializer.fromJson<Uint8List>(
        json['identityPublicKey'],
      ),
      boxPublicKey: serializer.fromJson<Uint8List>(json['boxPublicKey']),
      lastSeenMs: serializer.fromJson<int?>(json['lastSeenMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String?>(displayName),
      'nickname': serializer.toJson<String?>(nickname),
      'identityPublicKey': serializer.toJson<Uint8List>(identityPublicKey),
      'boxPublicKey': serializer.toJson<Uint8List>(boxPublicKey),
      'lastSeenMs': serializer.toJson<int?>(lastSeenMs),
    };
  }

  Peer copyWith({
    String? id,
    Value<String?> displayName = const Value.absent(),
    Value<String?> nickname = const Value.absent(),
    Uint8List? identityPublicKey,
    Uint8List? boxPublicKey,
    Value<int?> lastSeenMs = const Value.absent(),
  }) => Peer(
    id: id ?? this.id,
    displayName: displayName.present ? displayName.value : this.displayName,
    nickname: nickname.present ? nickname.value : this.nickname,
    identityPublicKey: identityPublicKey ?? this.identityPublicKey,
    boxPublicKey: boxPublicKey ?? this.boxPublicKey,
    lastSeenMs: lastSeenMs.present ? lastSeenMs.value : this.lastSeenMs,
  );
  Peer copyWithCompanion(PeersCompanion data) {
    return Peer(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      identityPublicKey: data.identityPublicKey.present
          ? data.identityPublicKey.value
          : this.identityPublicKey,
      boxPublicKey: data.boxPublicKey.present
          ? data.boxPublicKey.value
          : this.boxPublicKey,
      lastSeenMs: data.lastSeenMs.present
          ? data.lastSeenMs.value
          : this.lastSeenMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Peer(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('nickname: $nickname, ')
          ..write('identityPublicKey: $identityPublicKey, ')
          ..write('boxPublicKey: $boxPublicKey, ')
          ..write('lastSeenMs: $lastSeenMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    nickname,
    $driftBlobEquality.hash(identityPublicKey),
    $driftBlobEquality.hash(boxPublicKey),
    lastSeenMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Peer &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.nickname == this.nickname &&
          $driftBlobEquality.equals(
            other.identityPublicKey,
            this.identityPublicKey,
          ) &&
          $driftBlobEquality.equals(other.boxPublicKey, this.boxPublicKey) &&
          other.lastSeenMs == this.lastSeenMs);
}

class PeersCompanion extends UpdateCompanion<Peer> {
  final Value<String> id;
  final Value<String?> displayName;
  final Value<String?> nickname;
  final Value<Uint8List> identityPublicKey;
  final Value<Uint8List> boxPublicKey;
  final Value<int?> lastSeenMs;
  final Value<int> rowid;
  const PeersCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.nickname = const Value.absent(),
    this.identityPublicKey = const Value.absent(),
    this.boxPublicKey = const Value.absent(),
    this.lastSeenMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PeersCompanion.insert({
    required String id,
    this.displayName = const Value.absent(),
    this.nickname = const Value.absent(),
    required Uint8List identityPublicKey,
    required Uint8List boxPublicKey,
    this.lastSeenMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       identityPublicKey = Value(identityPublicKey),
       boxPublicKey = Value(boxPublicKey);
  static Insertable<Peer> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? nickname,
    Expression<Uint8List>? identityPublicKey,
    Expression<Uint8List>? boxPublicKey,
    Expression<int>? lastSeenMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (nickname != null) 'nickname': nickname,
      if (identityPublicKey != null) 'identity_public_key': identityPublicKey,
      if (boxPublicKey != null) 'box_public_key': boxPublicKey,
      if (lastSeenMs != null) 'last_seen_ms': lastSeenMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeersCompanion copyWith({
    Value<String>? id,
    Value<String?>? displayName,
    Value<String?>? nickname,
    Value<Uint8List>? identityPublicKey,
    Value<Uint8List>? boxPublicKey,
    Value<int?>? lastSeenMs,
    Value<int>? rowid,
  }) {
    return PeersCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      nickname: nickname ?? this.nickname,
      identityPublicKey: identityPublicKey ?? this.identityPublicKey,
      boxPublicKey: boxPublicKey ?? this.boxPublicKey,
      lastSeenMs: lastSeenMs ?? this.lastSeenMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (identityPublicKey.present) {
      map['identity_public_key'] = Variable<Uint8List>(identityPublicKey.value);
    }
    if (boxPublicKey.present) {
      map['box_public_key'] = Variable<Uint8List>(boxPublicKey.value);
    }
    if (lastSeenMs.present) {
      map['last_seen_ms'] = Variable<int>(lastSeenMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeersCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('nickname: $nickname, ')
          ..write('identityPublicKey: $identityPublicKey, ')
          ..write('boxPublicKey: $boxPublicKey, ')
          ..write('lastSeenMs: $lastSeenMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES peers (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<MessageDirection, int> direction =
      GeneratedColumn<int>(
        'direction',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<MessageDirection>($MessagesTable.$converterdirection);
  @override
  late final GeneratedColumnWithTypeConverter<MessageKind, int> kind =
      GeneratedColumn<int>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<MessageKind>($MessagesTable.$converterkind);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMsMeta = const VerificationMeta(
    'timestampMs',
  );
  @override
  late final GeneratedColumn<int> timestampMs = GeneratedColumn<int>(
    'timestamp_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MessageDeliveryState, int> state =
      GeneratedColumn<int>(
        'state',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<MessageDeliveryState>($MessagesTable.$converterstate);
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaBytesMeta = const VerificationMeta(
    'mediaBytes',
  );
  @override
  late final GeneratedColumn<Uint8List> mediaBytes = GeneratedColumn<Uint8List>(
    'media_bytes',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyToMessageIdMeta = const VerificationMeta(
    'replyToMessageId',
  );
  @override
  late final GeneratedColumn<String> replyToMessageId = GeneratedColumn<String>(
    'reply_to_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _envelopeMeta = const VerificationMeta(
    'envelope',
  );
  @override
  late final GeneratedColumn<Uint8List> envelope = GeneratedColumn<Uint8List>(
    'envelope',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    messageId,
    peerId,
    direction,
    kind,
    body,
    timestampMs,
    state,
    createdAtMs,
    mediaBytes,
    replyToMessageId,
    envelope,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('timestamp_ms')) {
      context.handle(
        _timestampMsMeta,
        timestampMs.isAcceptableOrUnknown(
          data['timestamp_ms']!,
          _timestampMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timestampMsMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('media_bytes')) {
      context.handle(
        _mediaBytesMeta,
        mediaBytes.isAcceptableOrUnknown(data['media_bytes']!, _mediaBytesMeta),
      );
    }
    if (data.containsKey('reply_to_message_id')) {
      context.handle(
        _replyToMessageIdMeta,
        replyToMessageId.isAcceptableOrUnknown(
          data['reply_to_message_id']!,
          _replyToMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('envelope')) {
      context.handle(
        _envelopeMeta,
        envelope.isAcceptableOrUnknown(data['envelope']!, _envelopeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      )!,
      direction: $MessagesTable.$converterdirection.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}direction'],
        )!,
      ),
      kind: $MessagesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}kind'],
        )!,
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      timestampMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp_ms'],
      )!,
      state: $MessagesTable.$converterstate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}state'],
        )!,
      ),
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      mediaBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}media_bytes'],
      ),
      replyToMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_message_id'],
      ),
      envelope: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}envelope'],
      ),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MessageDirection, int, int> $converterdirection =
      const EnumIndexConverter<MessageDirection>(MessageDirection.values);
  static JsonTypeConverter2<MessageKind, int, int> $converterkind =
      const EnumIndexConverter<MessageKind>(MessageKind.values);
  static JsonTypeConverter2<MessageDeliveryState, int, int> $converterstate =
      const EnumIndexConverter<MessageDeliveryState>(
        MessageDeliveryState.values,
      );
}

class Message extends DataClass implements Insertable<Message> {
  final String messageId;
  final String peerId;
  final MessageDirection direction;

  /// Whether this row is a text or an image message.
  final MessageKind kind;
  final String body;
  final int timestampMs;
  final MessageDeliveryState state;
  final int createdAtMs;

  /// The (compressed) image bytes for an image message, stored encrypted at
  /// rest with the rest of the DB. Null for text messages.
  final Uint8List? mediaBytes;

  /// The messageId this message is a reply to, or null. Resolved against the
  /// messages table to render the quoted snippet.
  final String? replyToMessageId;

  /// The sealed envelope bytes for an outbound message, kept so the outbox can
  /// re-send the *identical* bytes (same message_id) on reconnect — which is
  /// what preserves dedup + ACK matching. Null for inbound messages.
  final Uint8List? envelope;
  const Message({
    required this.messageId,
    required this.peerId,
    required this.direction,
    required this.kind,
    required this.body,
    required this.timestampMs,
    required this.state,
    required this.createdAtMs,
    this.mediaBytes,
    this.replyToMessageId,
    this.envelope,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['peer_id'] = Variable<String>(peerId);
    {
      map['direction'] = Variable<int>(
        $MessagesTable.$converterdirection.toSql(direction),
      );
    }
    {
      map['kind'] = Variable<int>($MessagesTable.$converterkind.toSql(kind));
    }
    map['body'] = Variable<String>(body);
    map['timestamp_ms'] = Variable<int>(timestampMs);
    {
      map['state'] = Variable<int>($MessagesTable.$converterstate.toSql(state));
    }
    map['created_at_ms'] = Variable<int>(createdAtMs);
    if (!nullToAbsent || mediaBytes != null) {
      map['media_bytes'] = Variable<Uint8List>(mediaBytes);
    }
    if (!nullToAbsent || replyToMessageId != null) {
      map['reply_to_message_id'] = Variable<String>(replyToMessageId);
    }
    if (!nullToAbsent || envelope != null) {
      map['envelope'] = Variable<Uint8List>(envelope);
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      messageId: Value(messageId),
      peerId: Value(peerId),
      direction: Value(direction),
      kind: Value(kind),
      body: Value(body),
      timestampMs: Value(timestampMs),
      state: Value(state),
      createdAtMs: Value(createdAtMs),
      mediaBytes: mediaBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaBytes),
      replyToMessageId: replyToMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToMessageId),
      envelope: envelope == null && nullToAbsent
          ? const Value.absent()
          : Value(envelope),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      messageId: serializer.fromJson<String>(json['messageId']),
      peerId: serializer.fromJson<String>(json['peerId']),
      direction: $MessagesTable.$converterdirection.fromJson(
        serializer.fromJson<int>(json['direction']),
      ),
      kind: $MessagesTable.$converterkind.fromJson(
        serializer.fromJson<int>(json['kind']),
      ),
      body: serializer.fromJson<String>(json['body']),
      timestampMs: serializer.fromJson<int>(json['timestampMs']),
      state: $MessagesTable.$converterstate.fromJson(
        serializer.fromJson<int>(json['state']),
      ),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      mediaBytes: serializer.fromJson<Uint8List?>(json['mediaBytes']),
      replyToMessageId: serializer.fromJson<String?>(json['replyToMessageId']),
      envelope: serializer.fromJson<Uint8List?>(json['envelope']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'peerId': serializer.toJson<String>(peerId),
      'direction': serializer.toJson<int>(
        $MessagesTable.$converterdirection.toJson(direction),
      ),
      'kind': serializer.toJson<int>(
        $MessagesTable.$converterkind.toJson(kind),
      ),
      'body': serializer.toJson<String>(body),
      'timestampMs': serializer.toJson<int>(timestampMs),
      'state': serializer.toJson<int>(
        $MessagesTable.$converterstate.toJson(state),
      ),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'mediaBytes': serializer.toJson<Uint8List?>(mediaBytes),
      'replyToMessageId': serializer.toJson<String?>(replyToMessageId),
      'envelope': serializer.toJson<Uint8List?>(envelope),
    };
  }

  Message copyWith({
    String? messageId,
    String? peerId,
    MessageDirection? direction,
    MessageKind? kind,
    String? body,
    int? timestampMs,
    MessageDeliveryState? state,
    int? createdAtMs,
    Value<Uint8List?> mediaBytes = const Value.absent(),
    Value<String?> replyToMessageId = const Value.absent(),
    Value<Uint8List?> envelope = const Value.absent(),
  }) => Message(
    messageId: messageId ?? this.messageId,
    peerId: peerId ?? this.peerId,
    direction: direction ?? this.direction,
    kind: kind ?? this.kind,
    body: body ?? this.body,
    timestampMs: timestampMs ?? this.timestampMs,
    state: state ?? this.state,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    mediaBytes: mediaBytes.present ? mediaBytes.value : this.mediaBytes,
    replyToMessageId: replyToMessageId.present
        ? replyToMessageId.value
        : this.replyToMessageId,
    envelope: envelope.present ? envelope.value : this.envelope,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      direction: data.direction.present ? data.direction.value : this.direction,
      kind: data.kind.present ? data.kind.value : this.kind,
      body: data.body.present ? data.body.value : this.body,
      timestampMs: data.timestampMs.present
          ? data.timestampMs.value
          : this.timestampMs,
      state: data.state.present ? data.state.value : this.state,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      mediaBytes: data.mediaBytes.present
          ? data.mediaBytes.value
          : this.mediaBytes,
      replyToMessageId: data.replyToMessageId.present
          ? data.replyToMessageId.value
          : this.replyToMessageId,
      envelope: data.envelope.present ? data.envelope.value : this.envelope,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('messageId: $messageId, ')
          ..write('peerId: $peerId, ')
          ..write('direction: $direction, ')
          ..write('kind: $kind, ')
          ..write('body: $body, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('state: $state, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('mediaBytes: $mediaBytes, ')
          ..write('replyToMessageId: $replyToMessageId, ')
          ..write('envelope: $envelope')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    messageId,
    peerId,
    direction,
    kind,
    body,
    timestampMs,
    state,
    createdAtMs,
    $driftBlobEquality.hash(mediaBytes),
    replyToMessageId,
    $driftBlobEquality.hash(envelope),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.messageId == this.messageId &&
          other.peerId == this.peerId &&
          other.direction == this.direction &&
          other.kind == this.kind &&
          other.body == this.body &&
          other.timestampMs == this.timestampMs &&
          other.state == this.state &&
          other.createdAtMs == this.createdAtMs &&
          $driftBlobEquality.equals(other.mediaBytes, this.mediaBytes) &&
          other.replyToMessageId == this.replyToMessageId &&
          $driftBlobEquality.equals(other.envelope, this.envelope));
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> messageId;
  final Value<String> peerId;
  final Value<MessageDirection> direction;
  final Value<MessageKind> kind;
  final Value<String> body;
  final Value<int> timestampMs;
  final Value<MessageDeliveryState> state;
  final Value<int> createdAtMs;
  final Value<Uint8List?> mediaBytes;
  final Value<String?> replyToMessageId;
  final Value<Uint8List?> envelope;
  final Value<int> rowid;
  const MessagesCompanion({
    this.messageId = const Value.absent(),
    this.peerId = const Value.absent(),
    this.direction = const Value.absent(),
    this.kind = const Value.absent(),
    this.body = const Value.absent(),
    this.timestampMs = const Value.absent(),
    this.state = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.mediaBytes = const Value.absent(),
    this.replyToMessageId = const Value.absent(),
    this.envelope = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String messageId,
    required String peerId,
    required MessageDirection direction,
    this.kind = const Value.absent(),
    required String body,
    required int timestampMs,
    required MessageDeliveryState state,
    required int createdAtMs,
    this.mediaBytes = const Value.absent(),
    this.replyToMessageId = const Value.absent(),
    this.envelope = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       peerId = Value(peerId),
       direction = Value(direction),
       body = Value(body),
       timestampMs = Value(timestampMs),
       state = Value(state),
       createdAtMs = Value(createdAtMs);
  static Insertable<Message> custom({
    Expression<String>? messageId,
    Expression<String>? peerId,
    Expression<int>? direction,
    Expression<int>? kind,
    Expression<String>? body,
    Expression<int>? timestampMs,
    Expression<int>? state,
    Expression<int>? createdAtMs,
    Expression<Uint8List>? mediaBytes,
    Expression<String>? replyToMessageId,
    Expression<Uint8List>? envelope,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (peerId != null) 'peer_id': peerId,
      if (direction != null) 'direction': direction,
      if (kind != null) 'kind': kind,
      if (body != null) 'body': body,
      if (timestampMs != null) 'timestamp_ms': timestampMs,
      if (state != null) 'state': state,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (mediaBytes != null) 'media_bytes': mediaBytes,
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      if (envelope != null) 'envelope': envelope,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? messageId,
    Value<String>? peerId,
    Value<MessageDirection>? direction,
    Value<MessageKind>? kind,
    Value<String>? body,
    Value<int>? timestampMs,
    Value<MessageDeliveryState>? state,
    Value<int>? createdAtMs,
    Value<Uint8List?>? mediaBytes,
    Value<String?>? replyToMessageId,
    Value<Uint8List?>? envelope,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      messageId: messageId ?? this.messageId,
      peerId: peerId ?? this.peerId,
      direction: direction ?? this.direction,
      kind: kind ?? this.kind,
      body: body ?? this.body,
      timestampMs: timestampMs ?? this.timestampMs,
      state: state ?? this.state,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      mediaBytes: mediaBytes ?? this.mediaBytes,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      envelope: envelope ?? this.envelope,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (direction.present) {
      map['direction'] = Variable<int>(
        $MessagesTable.$converterdirection.toSql(direction.value),
      );
    }
    if (kind.present) {
      map['kind'] = Variable<int>(
        $MessagesTable.$converterkind.toSql(kind.value),
      );
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (timestampMs.present) {
      map['timestamp_ms'] = Variable<int>(timestampMs.value);
    }
    if (state.present) {
      map['state'] = Variable<int>(
        $MessagesTable.$converterstate.toSql(state.value),
      );
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (mediaBytes.present) {
      map['media_bytes'] = Variable<Uint8List>(mediaBytes.value);
    }
    if (replyToMessageId.present) {
      map['reply_to_message_id'] = Variable<String>(replyToMessageId.value);
    }
    if (envelope.present) {
      map['envelope'] = Variable<Uint8List>(envelope.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('messageId: $messageId, ')
          ..write('peerId: $peerId, ')
          ..write('direction: $direction, ')
          ..write('kind: $kind, ')
          ..write('body: $body, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('state: $state, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('mediaBytes: $mediaBytes, ')
          ..write('replyToMessageId: $replyToMessageId, ')
          ..write('envelope: $envelope, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReactionsTable extends Reactions
    with TableInfo<$ReactionsTable, Reaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromMeMeta = const VerificationMeta('fromMe');
  @override
  late final GeneratedColumn<bool> fromMe = GeneratedColumn<bool>(
    'from_me',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("from_me" IN (0, 1))',
    ),
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    messageId,
    peerId,
    fromMe,
    emoji,
    createdAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('from_me')) {
      context.handle(
        _fromMeMeta,
        fromMe.isAcceptableOrUnknown(data['from_me']!, _fromMeMeta),
      );
    } else if (isInserting) {
      context.missing(_fromMeMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    } else if (isInserting) {
      context.missing(_emojiMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId, fromMe};
  @override
  Reaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reaction(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      )!,
      fromMe: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}from_me'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
    );
  }

  @override
  $ReactionsTable createAlias(String alias) {
    return $ReactionsTable(attachedDatabase, alias);
  }
}

class Reaction extends DataClass implements Insertable<Reaction> {
  final String messageId;
  final String peerId;
  final bool fromMe;
  final String emoji;
  final int createdAtMs;
  const Reaction({
    required this.messageId,
    required this.peerId,
    required this.fromMe,
    required this.emoji,
    required this.createdAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['peer_id'] = Variable<String>(peerId);
    map['from_me'] = Variable<bool>(fromMe);
    map['emoji'] = Variable<String>(emoji);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  ReactionsCompanion toCompanion(bool nullToAbsent) {
    return ReactionsCompanion(
      messageId: Value(messageId),
      peerId: Value(peerId),
      fromMe: Value(fromMe),
      emoji: Value(emoji),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory Reaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reaction(
      messageId: serializer.fromJson<String>(json['messageId']),
      peerId: serializer.fromJson<String>(json['peerId']),
      fromMe: serializer.fromJson<bool>(json['fromMe']),
      emoji: serializer.fromJson<String>(json['emoji']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'peerId': serializer.toJson<String>(peerId),
      'fromMe': serializer.toJson<bool>(fromMe),
      'emoji': serializer.toJson<String>(emoji),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  Reaction copyWith({
    String? messageId,
    String? peerId,
    bool? fromMe,
    String? emoji,
    int? createdAtMs,
  }) => Reaction(
    messageId: messageId ?? this.messageId,
    peerId: peerId ?? this.peerId,
    fromMe: fromMe ?? this.fromMe,
    emoji: emoji ?? this.emoji,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );
  Reaction copyWithCompanion(ReactionsCompanion data) {
    return Reaction(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      fromMe: data.fromMe.present ? data.fromMe.value : this.fromMe,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reaction(')
          ..write('messageId: $messageId, ')
          ..write('peerId: $peerId, ')
          ..write('fromMe: $fromMe, ')
          ..write('emoji: $emoji, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(messageId, peerId, fromMe, emoji, createdAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reaction &&
          other.messageId == this.messageId &&
          other.peerId == this.peerId &&
          other.fromMe == this.fromMe &&
          other.emoji == this.emoji &&
          other.createdAtMs == this.createdAtMs);
}

class ReactionsCompanion extends UpdateCompanion<Reaction> {
  final Value<String> messageId;
  final Value<String> peerId;
  final Value<bool> fromMe;
  final Value<String> emoji;
  final Value<int> createdAtMs;
  final Value<int> rowid;
  const ReactionsCompanion({
    this.messageId = const Value.absent(),
    this.peerId = const Value.absent(),
    this.fromMe = const Value.absent(),
    this.emoji = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReactionsCompanion.insert({
    required String messageId,
    required String peerId,
    required bool fromMe,
    required String emoji,
    required int createdAtMs,
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       peerId = Value(peerId),
       fromMe = Value(fromMe),
       emoji = Value(emoji),
       createdAtMs = Value(createdAtMs);
  static Insertable<Reaction> custom({
    Expression<String>? messageId,
    Expression<String>? peerId,
    Expression<bool>? fromMe,
    Expression<String>? emoji,
    Expression<int>? createdAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (peerId != null) 'peer_id': peerId,
      if (fromMe != null) 'from_me': fromMe,
      if (emoji != null) 'emoji': emoji,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReactionsCompanion copyWith({
    Value<String>? messageId,
    Value<String>? peerId,
    Value<bool>? fromMe,
    Value<String>? emoji,
    Value<int>? createdAtMs,
    Value<int>? rowid,
  }) {
    return ReactionsCompanion(
      messageId: messageId ?? this.messageId,
      peerId: peerId ?? this.peerId,
      fromMe: fromMe ?? this.fromMe,
      emoji: emoji ?? this.emoji,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (fromMe.present) {
      map['from_me'] = Variable<bool>(fromMe.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReactionsCompanion(')
          ..write('messageId: $messageId, ')
          ..write('peerId: $peerId, ')
          ..write('fromMe: $fromMe, ')
          ..write('emoji: $emoji, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PeersTable peers = $PeersTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $ReactionsTable reactions = $ReactionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    peers,
    messages,
    settings,
    reactions,
  ];
}

typedef $$PeersTableCreateCompanionBuilder =
    PeersCompanion Function({
      required String id,
      Value<String?> displayName,
      Value<String?> nickname,
      required Uint8List identityPublicKey,
      required Uint8List boxPublicKey,
      Value<int?> lastSeenMs,
      Value<int> rowid,
    });
typedef $$PeersTableUpdateCompanionBuilder =
    PeersCompanion Function({
      Value<String> id,
      Value<String?> displayName,
      Value<String?> nickname,
      Value<Uint8List> identityPublicKey,
      Value<Uint8List> boxPublicKey,
      Value<int?> lastSeenMs,
      Value<int> rowid,
    });

final class $$PeersTableReferences
    extends BaseReferences<_$AppDatabase, $PeersTable, Peer> {
  $$PeersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MessagesTable, List<Message>> _messagesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.messages,
    aliasName: $_aliasNameGenerator(db.peers.id, db.messages.peerId),
  );

  $$MessagesTableProcessedTableManager get messagesRefs {
    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.peerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PeersTableFilterComposer extends Composer<_$AppDatabase, $PeersTable> {
  $$PeersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get identityPublicKey => $composableBuilder(
    column: $table.identityPublicKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get boxPublicKey => $composableBuilder(
    column: $table.boxPublicKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeenMs => $composableBuilder(
    column: $table.lastSeenMs,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> messagesRefs(
    Expression<bool> Function($$MessagesTableFilterComposer f) f,
  ) {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.peerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PeersTableOrderingComposer
    extends Composer<_$AppDatabase, $PeersTable> {
  $$PeersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get identityPublicKey => $composableBuilder(
    column: $table.identityPublicKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get boxPublicKey => $composableBuilder(
    column: $table.boxPublicKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeenMs => $composableBuilder(
    column: $table.lastSeenMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeersTable> {
  $$PeersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<Uint8List> get identityPublicKey => $composableBuilder(
    column: $table.identityPublicKey,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get boxPublicKey => $composableBuilder(
    column: $table.boxPublicKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSeenMs => $composableBuilder(
    column: $table.lastSeenMs,
    builder: (column) => column,
  );

  Expression<T> messagesRefs<T extends Object>(
    Expression<T> Function($$MessagesTableAnnotationComposer a) f,
  ) {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.peerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PeersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeersTable,
          Peer,
          $$PeersTableFilterComposer,
          $$PeersTableOrderingComposer,
          $$PeersTableAnnotationComposer,
          $$PeersTableCreateCompanionBuilder,
          $$PeersTableUpdateCompanionBuilder,
          (Peer, $$PeersTableReferences),
          Peer,
          PrefetchHooks Function({bool messagesRefs})
        > {
  $$PeersTableTableManager(_$AppDatabase db, $PeersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> nickname = const Value.absent(),
                Value<Uint8List> identityPublicKey = const Value.absent(),
                Value<Uint8List> boxPublicKey = const Value.absent(),
                Value<int?> lastSeenMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeersCompanion(
                id: id,
                displayName: displayName,
                nickname: nickname,
                identityPublicKey: identityPublicKey,
                boxPublicKey: boxPublicKey,
                lastSeenMs: lastSeenMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> displayName = const Value.absent(),
                Value<String?> nickname = const Value.absent(),
                required Uint8List identityPublicKey,
                required Uint8List boxPublicKey,
                Value<int?> lastSeenMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeersCompanion.insert(
                id: id,
                displayName: displayName,
                nickname: nickname,
                identityPublicKey: identityPublicKey,
                boxPublicKey: boxPublicKey,
                lastSeenMs: lastSeenMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PeersTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({messagesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (messagesRefs) db.messages],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (messagesRefs)
                    await $_getPrefetchedData<Peer, $PeersTable, Message>(
                      currentTable: table,
                      referencedTable: $$PeersTableReferences
                          ._messagesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PeersTableReferences(db, table, p0).messagesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.peerId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PeersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeersTable,
      Peer,
      $$PeersTableFilterComposer,
      $$PeersTableOrderingComposer,
      $$PeersTableAnnotationComposer,
      $$PeersTableCreateCompanionBuilder,
      $$PeersTableUpdateCompanionBuilder,
      (Peer, $$PeersTableReferences),
      Peer,
      PrefetchHooks Function({bool messagesRefs})
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      required String messageId,
      required String peerId,
      required MessageDirection direction,
      Value<MessageKind> kind,
      required String body,
      required int timestampMs,
      required MessageDeliveryState state,
      required int createdAtMs,
      Value<Uint8List?> mediaBytes,
      Value<String?> replyToMessageId,
      Value<Uint8List?> envelope,
      Value<int> rowid,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> messageId,
      Value<String> peerId,
      Value<MessageDirection> direction,
      Value<MessageKind> kind,
      Value<String> body,
      Value<int> timestampMs,
      Value<MessageDeliveryState> state,
      Value<int> createdAtMs,
      Value<Uint8List?> mediaBytes,
      Value<String?> replyToMessageId,
      Value<Uint8List?> envelope,
      Value<int> rowid,
    });

final class $$MessagesTableReferences
    extends BaseReferences<_$AppDatabase, $MessagesTable, Message> {
  $$MessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PeersTable _peerIdTable(_$AppDatabase db) => db.peers.createAlias(
    $_aliasNameGenerator(db.messages.peerId, db.peers.id),
  );

  $$PeersTableProcessedTableManager get peerId {
    final $_column = $_itemColumn<String>('peer_id')!;

    final manager = $$PeersTableTableManager(
      $_db,
      $_db.peers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_peerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MessageDirection, MessageDirection, int>
  get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<MessageKind, MessageKind, int> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    MessageDeliveryState,
    MessageDeliveryState,
    int
  >
  get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get mediaBytes => $composableBuilder(
    column: $table.mediaBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToMessageId => $composableBuilder(
    column: $table.replyToMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get envelope => $composableBuilder(
    column: $table.envelope,
    builder: (column) => ColumnFilters(column),
  );

  $$PeersTableFilterComposer get peerId {
    final $$PeersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.peerId,
      referencedTable: $db.peers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeersTableFilterComposer(
            $db: $db,
            $table: $db.peers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get mediaBytes => $composableBuilder(
    column: $table.mediaBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToMessageId => $composableBuilder(
    column: $table.replyToMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get envelope => $composableBuilder(
    column: $table.envelope,
    builder: (column) => ColumnOrderings(column),
  );

  $$PeersTableOrderingComposer get peerId {
    final $$PeersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.peerId,
      referencedTable: $db.peers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeersTableOrderingComposer(
            $db: $db,
            $table: $db.peers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MessageDirection, int> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MessageKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<MessageDeliveryState, int> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get mediaBytes => $composableBuilder(
    column: $table.mediaBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get replyToMessageId => $composableBuilder(
    column: $table.replyToMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get envelope =>
      $composableBuilder(column: $table.envelope, builder: (column) => column);

  $$PeersTableAnnotationComposer get peerId {
    final $$PeersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.peerId,
      referencedTable: $db.peers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeersTableAnnotationComposer(
            $db: $db,
            $table: $db.peers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, $$MessagesTableReferences),
          Message,
          PrefetchHooks Function({bool peerId})
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> peerId = const Value.absent(),
                Value<MessageDirection> direction = const Value.absent(),
                Value<MessageKind> kind = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> timestampMs = const Value.absent(),
                Value<MessageDeliveryState> state = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<Uint8List?> mediaBytes = const Value.absent(),
                Value<String?> replyToMessageId = const Value.absent(),
                Value<Uint8List?> envelope = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                messageId: messageId,
                peerId: peerId,
                direction: direction,
                kind: kind,
                body: body,
                timestampMs: timestampMs,
                state: state,
                createdAtMs: createdAtMs,
                mediaBytes: mediaBytes,
                replyToMessageId: replyToMessageId,
                envelope: envelope,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String peerId,
                required MessageDirection direction,
                Value<MessageKind> kind = const Value.absent(),
                required String body,
                required int timestampMs,
                required MessageDeliveryState state,
                required int createdAtMs,
                Value<Uint8List?> mediaBytes = const Value.absent(),
                Value<String?> replyToMessageId = const Value.absent(),
                Value<Uint8List?> envelope = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                messageId: messageId,
                peerId: peerId,
                direction: direction,
                kind: kind,
                body: body,
                timestampMs: timestampMs,
                state: state,
                createdAtMs: createdAtMs,
                mediaBytes: mediaBytes,
                replyToMessageId: replyToMessageId,
                envelope: envelope,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({peerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (peerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.peerId,
                                referencedTable: $$MessagesTableReferences
                                    ._peerIdTable(db),
                                referencedColumn: $$MessagesTableReferences
                                    ._peerIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, $$MessagesTableReferences),
      Message,
      PrefetchHooks Function({bool peerId})
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$ReactionsTableCreateCompanionBuilder =
    ReactionsCompanion Function({
      required String messageId,
      required String peerId,
      required bool fromMe,
      required String emoji,
      required int createdAtMs,
      Value<int> rowid,
    });
typedef $$ReactionsTableUpdateCompanionBuilder =
    ReactionsCompanion Function({
      Value<String> messageId,
      Value<String> peerId,
      Value<bool> fromMe,
      Value<String> emoji,
      Value<int> createdAtMs,
      Value<int> rowid,
    });

class $$ReactionsTableFilterComposer
    extends Composer<_$AppDatabase, $ReactionsTable> {
  $$ReactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fromMe => $composableBuilder(
    column: $table.fromMe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReactionsTable> {
  $$ReactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fromMe => $composableBuilder(
    column: $table.fromMe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReactionsTable> {
  $$ReactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<bool> get fromMe =>
      $composableBuilder(column: $table.fromMe, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );
}

class $$ReactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReactionsTable,
          Reaction,
          $$ReactionsTableFilterComposer,
          $$ReactionsTableOrderingComposer,
          $$ReactionsTableAnnotationComposer,
          $$ReactionsTableCreateCompanionBuilder,
          $$ReactionsTableUpdateCompanionBuilder,
          (Reaction, BaseReferences<_$AppDatabase, $ReactionsTable, Reaction>),
          Reaction,
          PrefetchHooks Function()
        > {
  $$ReactionsTableTableManager(_$AppDatabase db, $ReactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> peerId = const Value.absent(),
                Value<bool> fromMe = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReactionsCompanion(
                messageId: messageId,
                peerId: peerId,
                fromMe: fromMe,
                emoji: emoji,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String peerId,
                required bool fromMe,
                required String emoji,
                required int createdAtMs,
                Value<int> rowid = const Value.absent(),
              }) => ReactionsCompanion.insert(
                messageId: messageId,
                peerId: peerId,
                fromMe: fromMe,
                emoji: emoji,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReactionsTable,
      Reaction,
      $$ReactionsTableFilterComposer,
      $$ReactionsTableOrderingComposer,
      $$ReactionsTableAnnotationComposer,
      $$ReactionsTableCreateCompanionBuilder,
      $$ReactionsTableUpdateCompanionBuilder,
      (Reaction, BaseReferences<_$AppDatabase, $ReactionsTable, Reaction>),
      Reaction,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PeersTableTableManager get peers =>
      $$PeersTableTableManager(_db, _db.peers);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$ReactionsTableTableManager get reactions =>
      $$ReactionsTableTableManager(_db, _db.reactions);
}
