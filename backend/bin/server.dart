// Developed by Codesoftwares
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:crypto/crypto.dart';
import 'package:dbcrypt/dbcrypt.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

final env = Platform.environment;
final secret = SecretKey(env['TOKEN_SIGNING_SECRET'] ?? (throw 'TOKEN_SIGNING_SECRET missing'));
late Connection db;

// ---- Logging: one JSON line per event. Never log bodies, passwords, phones, messages or screenshots.
void log(String level, String msg, [Map<String, Object?> extra = const {}]) =>
    stdout.writeln(jsonEncode({'ts': DateTime.now().toUtc().toIso8601String(), 'level': level, 'msg': msg, ...extra}));

final _rnd = Random.secure();
String _rid() => List.generate(8, (_) => _rnd.nextInt(16).toRadixString(16)).join();

Middleware logging() => (inner) => (req) async {
      final id = _rid(), sw = Stopwatch()..start();
      try {
        final res = await inner(req.change(context: {'rid': id}));
        log('info', 'request', {'rid': id, 'method': req.method, 'path': '/${req.url.path}', 'status': res.statusCode, 'ms': sw.elapsedMilliseconds});
        return res.change(headers: {'x-request-id': id});
      } on FormatException {
        return _json({'error': 'Invalid request.'}, 400);
      } on _Http catch (e) {
        log('warn', 'request', {'rid': id, 'method': req.method, 'path': '/${req.url.path}', 'status': e.code, 'ms': sw.elapsedMilliseconds});
        return _json({'error': e.msg}, e.code);
      } catch (e, st) {
        log('error', 'unhandled', {'rid': id, 'path': '/${req.url.path}', 'error': e.runtimeType.toString(), 'stack': st.toString().split('\n').take(4).join(' | ')});
        return _json({'error': 'Something went wrong. Please try again.'}, 500);
      }
    };

// Basic per-IP rate limit for auth routes.
final _hits = <String, List<DateTime>>{};
Middleware rateLimit(String prefix, int max, Duration window) => (inner) => (req) {
      if (req.url.path.startsWith(prefix)) {
        final ip = (req.headers['x-forwarded-for'] ?? 'local').split(',').first.trim();
        final now = DateTime.now(), l = (_hits['$prefix$ip'] ??= [])..removeWhere((t) => now.difference(t) > window);
        if (l.length >= max) throw _Http(429, 'Too many attempts. Try again in a few minutes.');
        l.add(now);
      }
      return inner(req);
    };

/// CORS for the web build. Allowed origins come from CORS_ORIGINS (comma separated, e.g. https://www.your-domain.com).
/// Outside production, http://localhost and http://127.0.0.1 (any port) are allowed too, for `flutter run -d chrome`.
Middleware cors() {
  final allowed = (env['CORS_ORIGINS'] ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  final dev = env['APP_ENV'] != 'production', local = RegExp(r'^https?://(localhost|127\.0\.0\.1)(:\d+)?$');
  return (inner) => (req) async {
        final origin = req.headers['origin'];
        final ok = origin != null && (allowed.contains(origin) || (dev && local.hasMatch(origin)));
        final h = <String, String>{if (ok) ...{'access-control-allow-origin': origin!, 'vary': 'Origin'}};
        if (req.method == 'OPTIONS') {
          return Response(204, headers: {...h, if (ok) ...{'access-control-allow-methods': 'GET,POST,PUT,DELETE,OPTIONS', 'access-control-allow-headers': 'authorization,content-type', 'access-control-max-age': '86400'}});
        }
        return (await inner(req)).change(headers: h);
      };
}

Middleware securityHeaders() => (inner) => (req) async => (await inner(req)).change(headers: {
      'x-content-type-options': 'nosniff', 'cache-control': 'no-store', 'strict-transport-security': 'max-age=31536000'});

class _Http implements Exception { final int code; final String msg; _Http(this.code, this.msg); }
Response _json(Object o, [int code = 200]) => Response(code, body: jsonEncode(o), headers: {'content-type': 'application/json'});
Future<Map<String, dynamic>> _body(Request r) async {
  try { return jsonDecode(await r.readAsString()) as Map<String, dynamic>; } catch (_) { throw _Http(400, 'Invalid request body.'); }
}

// ---- Auth
String _uid(Request r) {
  final h = r.headers['authorization'] ?? '';
  if (!h.startsWith('Bearer ')) throw _Http(401, 'Please sign in.');
  try { return JWT.verify(h.substring(7), secret).payload['sub'] as String; } catch (_) { throw _Http(401, 'Session expired. Please sign in again.'); }
}
const _uuidKeys = {'i', 'u', 'me', 'f', 't', 'uid', 'a'};
Future<Result> q(String sql, [Map<String, Object?> p = const {}]) => db.execute(Sql.named(sql), parameters: {
      for (final e in p.entries) e.key: (_uuidKeys.contains(e.key) && e.value is String) ? TypedValue(Type.uuid, e.value) : e.value});
Future<void> _requireApproved(String uid) async {
  final r = await q('SELECT status FROM users WHERE id=@i', {'i': uid});
  if (r.isEmpty || r.first[0] != 'approved') throw _Http(403, 'Your profile is awaiting admin approval.');
}

// ---- Security questions (3 chosen at sign-up; answers stored only as bcrypt hashes of the normalised text)
const _secQuestions = {
  'pet': 'What was the name of your first pet?',
  'school': 'What was the name of your first school?',
  'city': 'In which town or city were you born?',
  'mother': "What is your mother's maiden name?",
  'friend': 'What was the name of your childhood best friend?',
  'teacher': 'What was the name of your favourite teacher?',
  'food': 'What is your favourite food?',
  'street': 'What street did you grow up on?',
  'book': 'What is the title of your favourite book or film?',
  'festival': 'What is your favourite festival?',
};
String _norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

List<(String, String)> _parseSecurity(dynamic raw) {
  if (raw is! List || raw.length != 3) throw _Http(400, 'Choose 3 security questions and answer all of them.');
  final out = <(String, String)>[], seen = <String>{};
  for (final e in raw) {
    final id = e is Map ? e['q'] : null, a = e is Map ? _norm('${e['a'] ?? ''}') : '';
    if (id is! String || !_secQuestions.containsKey(id) || !seen.add(id)) throw _Http(400, 'Choose 3 different security questions.');
    if (a.length < 2) throw _Http(400, 'Each security answer must be at least 2 characters.');
    out.add((id, a));
  }
  return out;
}

Future<void> _saveSecurity(String uid, List<(String, String)> sec) async {
  for (var i = 0; i < sec.length; i++) {
    await q('INSERT INTO security_answers(user_id,slot,question_id,answer_hash) VALUES(@u,@s,@qid,@h)',
        {'u': uid, 's': i + 1, 'qid': sec[i].$1, 'h': DBCrypt().hashpw(sec[i].$2, DBCrypt().gensalt())});
  }
}

/// Creates a user and its 3 security answers together (the user row is removed again if saving the answers fails).
Future<String> _createUser(String email, String pw, List<(String, String)> sec, {String role = 'member', String status = 'pending'}) async {
  final hash = DBCrypt().hashpw(pw, DBCrypt().gensalt());
  final String uid;
  try {
    final res = await q('INSERT INTO users(email,password_hash,role,status) VALUES(@e,@h,@ro,@st) RETURNING id::text', {'e': email, 'h': hash, 'ro': role, 'st': status});
    uid = res.first[0] as String;
  } on UniqueViolationException {
    throw _Http(409, 'This email is already registered.');
  }
  try {
    await _saveSecurity(uid, sec);
  } catch (_) {
    await q('DELETE FROM users WHERE id=@u', {'u': uid});
    rethrow;
  }
  return uid;
}

Future<Response> register(Request r) async {
  final b = await _body(r);
  if (b['confirm_second_marriage'] != true) throw _Http(400, 'This service is only for second marriages. Please confirm to continue.');
  final email = (b['email'] as String? ?? '').trim().toLowerCase(), pw = b['password'] as String? ?? '';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) throw _Http(400, 'Enter a valid email address.');
  if (pw.length < 8) throw _Http(400, 'Password must be at least 8 characters.');
  final sec = _parseSecurity(b['security']);
  final uid = await _createUser(email, pw, sec);
  log('info', 'user_registered', {'user': uid});
  return _json({'message': 'Registered. Complete your profile to continue.'}, 201);
}

Future<Response> login(Request r) async {
  final b = await _body(r);
  final res = await q('SELECT id,password_hash,role,status,status_reason FROM users WHERE email=@e', {'e': (b['email'] as String? ?? '').trim().toLowerCase()});
  if (res.isEmpty || !DBCrypt().checkpw(b['password'] as String? ?? '', res.first[1] as String)) {
    log('warn', 'login_failed');
    throw _Http(401, 'Email or password is incorrect.');
  }
  final row = res.first;
  if (row[3] == 'suspended') throw _Http(403, row[4] == null ? 'This account is suspended.' : 'This account is suspended: ${row[4]}');
  final token = JWT({'sub': row[0].toString(), 'role': row[2]}).sign(secret, expiresIn: const Duration(hours: 12));
  log('info', 'login_ok', {'user': row[0].toString()});
  return _json({'token': token, 'status': row[3], 'role': row[2]});
}

// ---- Profile
const _fields = ['name','age','gender','location','address','education','occupation','marital_status','marriage_details','has_children','children_info','family_details',
  'pref_age_min','pref_age_max','pref_location','pref_education','pref_occupation','pref_marital_status','photos_private',
  'phone','whatsapp','contact_email','show_phone','show_whatsapp','show_email'];

String _s(dynamic v) => (v is String ? v : '').trim();
String? _opt(dynamic v) { final t = _s(v); return t.isEmpty ? null : t; }
final _phoneRe = RegExp(r'^\+?[0-9]{10,15}$');
final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

Future<Response> putProfile(Request r) async {
  final uid = _uid(r), b = await _body(r);
  final name = _s(b['name']), loc = _s(b['location']), addr = _s(b['address']), edu = _s(b['education']), occ = _s(b['occupation']),
      md = _s(b['marriage_details']), age = b['age'], children = b['has_children'] == true, childInfo = _opt(b['children_info']);
  if (name.length < 2 || name.length > 80) throw _Http(400, 'Enter your full name.');
  if (age is! int || age < 18 || age > 80) throw _Http(400, 'Age must be between 18 and 80.');
  if (!['male', 'female'].contains(b['gender'])) throw _Http(400, 'Select your gender.');
  if (!['divorced', 'widowed', 'legally_separated'].contains(b['marital_status'])) throw _Http(400, 'Select a marital status.');
  if (md.length < 10 || md.length > 600) throw _Http(400, 'Write a few lines about your marriage details (at least 10 characters).');
  if (loc.length < 2 || loc.length > 80) throw _Http(400, 'Enter your city or town.');
  if (addr.length < 8 || addr.length > 300) throw _Http(400, 'Enter your full address.');
  if (edu.length < 2 || occ.length < 2) throw _Http(400, 'Education and occupation are required.');
  if (children && (childInfo == null || childInfo.length < 2)) throw _Http(400, 'Tell us about your children (ages, who they live with).');
  final phone = _s(b['phone']).replaceAll(RegExp(r'[\s\-]'), ''), wa = _s(b['whatsapp']).replaceAll(RegExp(r'[\s\-]'), ''), ce = _s(b['contact_email']).toLowerCase();
  if (!_phoneRe.hasMatch(phone)) throw _Http(400, 'Enter a valid mobile number (10 to 15 digits).');
  if (wa.isNotEmpty && !_phoneRe.hasMatch(wa)) throw _Http(400, 'Enter a valid WhatsApp number (10 to 15 digits).');
  if (ce.isNotEmpty && !_emailRe.hasMatch(ce)) throw _Http(400, 'Enter a valid contact email.');
  final pmin = b['pref_age_min'], pmax = b['pref_age_max'];
  if ((pmin != null && (pmin is! int || pmin < 18 || pmin > 80)) || (pmax != null && (pmax is! int || pmax < 18 || pmax > 80)) || (pmin is int && pmax is int && pmin > pmax)) {
    throw _Http(400, 'Check the preferred age range (18 to 80, from must not be more than to).');
  }
  final pm = b['pref_marital_status'];
  if (pm != null && !['divorced', 'widowed', 'legally_separated'].contains(pm)) throw _Http(400, 'Invalid preferred marital status.');
  final p = <String, Object?>{
    'name': name, 'age': age, 'gender': b['gender'], 'location': loc, 'address': addr, 'education': edu, 'occupation': occ,
    'marital_status': b['marital_status'], 'marriage_details': md, 'has_children': children, 'children_info': children ? childInfo : null,
    'family_details': _opt(b['family_details']), 'pref_age_min': pmin, 'pref_age_max': pmax, 'pref_location': _opt(b['pref_location']),
    'pref_education': _opt(b['pref_education']), 'pref_occupation': _opt(b['pref_occupation']), 'pref_marital_status': pm,
    'photos_private': b['photos_private'] != false, 'phone': phone, 'whatsapp': wa.isEmpty ? null : wa, 'contact_email': ce.isEmpty ? null : ce,
    'show_phone': b['show_phone'] == true, 'show_whatsapp': b['show_whatsapp'] == true, 'show_email': b['show_email'] == true,
  };
  assert(_fields.every(p.containsKey));
  p['uid'] = uid;
  await q('''INSERT INTO profiles(user_id,${_fields.join(',')}) VALUES(@uid,${_fields.map((f) => '@$f').join(',')})
    ON CONFLICT (user_id) DO UPDATE SET ${_fields.map((f) => '$f=@$f').join(',')}, updated_at=now()''', p);
  await q("UPDATE users SET status='pending' WHERE id=@u AND status='rejected'", {'u': uid}); // edited after rejection: ask the admin again
  log('info', 'profile_saved', {'user': uid});
  return _json({'message': 'Profile saved.'});
}

Future<Response> getProfile(Request r) async {
  final res = await q('SELECT row_to_json(p) FROM profiles p WHERE user_id=@u', {'u': _uid(r)});
  return res.isEmpty ? _json({'profile': null}) : _json({'profile': res.first[0]});
}

/// Deletes the member's profile details and photos (the login account stays).
Future<Response> deleteProfile(Request r) async {
  final uid = _uid(r);
  final keys = await q('SELECT storage_key FROM photos WHERE user_id=@u', {'u': uid});
  await q('DELETE FROM photos WHERE user_id=@u', {'u': uid});
  await q('DELETE FROM profiles WHERE user_id=@u', {'u': uid});
  await q('DELETE FROM contact_requests WHERE to_user=@u', {'u': uid}); // contact consents end with the profile
  for (final k in keys) {
    final f = File('${mediaDir.path}/${k[0]}');
    if (f.existsSync()) f.deleteSync();
  }
  log('info', 'profile_deleted', {'user': uid});
  return _json({'message': 'Your profile details and photos were deleted.'});
}

// ---- Another member's profile. Contact details are returned only when the owner made them public or accepted this member's request.
Future<Response> memberProfile(Request r, String id) async {
  final uid = _uid(r), self = uid == id;
  final me = await q('SELECT role,status FROM users WHERE id=@u', {'u': uid});
  final admin = me.isNotEmpty && me.first[0] == 'admin' && me.first[1] != 'suspended';
  if (!self && !admin) {
    await _requireApproved(uid);
    final bl = await q('SELECT 1 FROM blocks WHERE (blocker=@u AND blocked=@t) OR (blocker=@t AND blocked=@u)', {'u': uid, 't': id});
    if (bl.isNotEmpty) throw _Http(404, 'Profile not found.');
  }
  final res = await q('SELECT row_to_json(p), u.status FROM profiles p JOIN users u ON u.id=p.user_id WHERE p.user_id=@i', {'i': id});
  if (res.isEmpty || (!self && !admin && res.first[1] != 'approved')) throw _Http(404, 'Profile not found.');
  final p = Map<String, dynamic>.from(res.first[0] as Map), full = self || admin;
  if (!full) await q('INSERT INTO profile_views(viewer,viewed) VALUES(@u,@i) ON CONFLICT DO NOTHING', {'u': uid, 'i': id}); // counted once per viewer per day for the admin reports
  final cr = await q('SELECT status FROM contact_requests WHERE from_user=@u AND to_user=@i', {'u': uid, 'i': id});
  final crStatus = cr.isEmpty ? null : cr.first[0] as String;
  final it = await q('SELECT id::text, status, (to_user=@u) FROM interests WHERE (from_user=@u AND to_user=@i) OR (from_user=@i AND to_user=@u)', {'u': uid, 'i': id});
  final canSeePhotos = full || p['photos_private'] != true || (it.isNotEmpty && it.first[1] == 'accepted');
  final photos = await q('SELECT id::text FROM photos WHERE user_id=@i ORDER BY created_at', {'i': id});
  final contact = <String, String>{}, hidden = <String>[];
  for (final f in const [('phone', 'show_phone'), ('whatsapp', 'show_whatsapp'), ('contact_email', 'show_email')]) {
    final v = p[f.$1] as String?;
    if (v == null || v.isEmpty) continue;
    if (full || p[f.$2] == true || crStatus == 'accepted') { contact[f.$1] = v; } else { hidden.add(f.$1); }
  }
  final out = {...p}..remove('phone')..remove('whatsapp')..remove('contact_email');
  if (!full) { out..remove('address')..remove('show_phone')..remove('show_whatsapp')..remove('show_email'); }
  return _json({'profile': out, 'photos': canSeePhotos ? photos.map((x) => x[0]).toList() : <Object?>[], 'photos_locked': !canSeePhotos && photos.isNotEmpty,
    'contact': contact, 'contact_hidden': hidden, 'contact_request': crStatus,
    'interest': it.isEmpty ? null : {'id': it.first[0], 'status': it.first[1], 'received': it.first[2]}, 'is_self': self});
}

// ---- Contact requests (private phone / WhatsApp / email are shown only after the owner accepts)
Future<Response> requestContact(Request r, String target) async {
  final uid = _uid(r); await _requireApproved(uid);
  if (uid == target) throw _Http(400, 'This is your own profile.');
  final bl = await q('SELECT 1 FROM blocks WHERE (blocker=@u AND blocked=@t) OR (blocker=@t AND blocked=@u)', {'u': uid, 't': target});
  if (bl.isNotEmpty) throw _Http(403, 'You cannot send a request to this member.');
  final t = await q("SELECT 1 FROM profiles p JOIN users u ON u.id=p.user_id WHERE p.user_id=@t AND u.status='approved'", {'t': target});
  if (t.isEmpty) throw _Http(404, 'Profile not found.');
  final ex = await q('SELECT status FROM contact_requests WHERE from_user=@u AND to_user=@t', {'u': uid, 't': target});
  if (ex.isNotEmpty) {
    final s = ex.first[0];
    throw _Http(409, s == 'pending' ? 'Your request is already waiting for a reply.' : s == 'accepted' ? 'This member already shared their contact details with you.' : 'This member did not accept your request.');
  }
  final res = await q('INSERT INTO contact_requests(from_user,to_user) VALUES(@u,@t) RETURNING id', {'u': uid, 't': target});
  await q("INSERT INTO notifications(user_id,kind,ref_id) VALUES(@t,'contact_request',@i)", {'t': target, 'i': res.first[0]});
  log('info', 'contact_requested', {'from': uid, 'to': target});
  return _json({'message': 'Request sent. You will see their contact details if they accept.'}, 201);
}

Future<Response> contactRequestsIncoming(Request r) async {
  final res = await q('''SELECT c.id::text AS id, c.status, o.user_id::text AS member_id, o.name, o.age, o.location,
      (SELECT id::text FROM photos WHERE user_id=o.user_id ORDER BY created_at LIMIT 1) AS photo_id
    FROM contact_requests c JOIN profiles o ON o.user_id=c.from_user
    WHERE c.to_user=@u AND NOT EXISTS (SELECT 1 FROM blocks b WHERE (b.blocker=@u AND b.blocked=o.user_id) OR (b.blocker=o.user_id AND b.blocked=@u))
    ORDER BY c.created_at DESC LIMIT 100''', {'u': _uid(r)});
  return _json({'items': res.map((x) => x.toColumnMap()).toList()});
}

Future<Response> respondContact(Request r, String id) async {
  final uid = _uid(r), accept = (await _body(r))['accept'] == true;
  final res = await q("UPDATE contact_requests SET status=@s, responded_at=now() WHERE id=@i AND to_user=@u AND status IN ('pending','accepted') RETURNING from_user::text",
      {'s': accept ? 'accepted' : 'declined', 'i': id, 'u': uid});
  if (res.isEmpty) throw _Http(404, 'Request not found.');
  if (accept) await q("INSERT INTO notifications(user_id,kind,ref_id) VALUES(@f,'contact_accepted',@i)", {'f': res.first[0], 'i': id});
  log('info', 'contact_request_answered', {'user': uid, 'accepted': accept});
  return _json({'message': accept ? 'Your contact details are now visible to this member.' : 'This member can no longer see your private contact details.'});
}

// ---- Search (approved members only, opposite visibility rules; phone never returned here)
Future<Response> search(Request r) async {
  final uid = _uid(r); await _requireApproved(uid);
  final p = r.url.queryParameters;
  final res = await q('''SELECT p.user_id::text AS user_id,p.name,p.age,p.gender,p.location,p.education,p.occupation,p.marital_status,p.has_children,
      (SELECT id::text FROM photos WHERE user_id=p.user_id ORDER BY created_at LIMIT 1) AS photo_id
    FROM profiles p JOIN users u ON u.id=p.user_id
    WHERE u.status='approved' AND u.matched_at IS NULL AND p.user_id<>@me
      AND (@g::text IS NULL OR p.gender=@g) AND (@amin::int IS NULL OR p.age>=@amin) AND (@amax::int IS NULL OR p.age<=@amax)
      AND (@loc::text IS NULL OR p.location ILIKE '%'||@loc||'%') AND (@ms::text IS NULL OR p.marital_status=@ms)
      AND NOT EXISTS (SELECT 1 FROM blocks b WHERE (b.blocker=@me AND b.blocked=p.user_id) OR (b.blocker=p.user_id AND b.blocked=@me))
    ORDER BY p.updated_at DESC LIMIT 30 OFFSET @off''',
      {'me': uid, 'g': p['gender'], 'amin': int.tryParse(p['age_min'] ?? ''), 'amax': int.tryParse(p['age_max'] ?? ''),
       'loc': p['location'], 'ms': p['marital_status'], 'off': (int.tryParse(p['page'] ?? '0') ?? 0) * 30});
  return _json({'results': res.map((x) => x.toColumnMap()).toList()});
}

// ---- Public search: no login. Approved members only; first name, no photo, no contact details, no ids, capped to 100 results.
Future<Response> publicSearch(Request r) async {
  final p = r.url.queryParameters, page = (int.tryParse(p['page'] ?? '0') ?? 0).clamp(0, 4).toInt();
  final res = await q('''SELECT split_part(p.name,' ',1) AS name,p.age,p.gender,p.location,p.education,p.occupation,p.marital_status,p.has_children
    FROM profiles p JOIN users u ON u.id=p.user_id
    WHERE u.status='approved' AND u.role='member' AND u.matched_at IS NULL
      AND (@g::text IS NULL OR p.gender=@g) AND (@amin::int IS NULL OR p.age>=@amin) AND (@amax::int IS NULL OR p.age<=@amax)
      AND (@loc::text IS NULL OR p.location ILIKE '%'||@loc||'%') AND (@ms::text IS NULL OR p.marital_status=@ms)
    ORDER BY p.updated_at DESC LIMIT 20 OFFSET @off''',
      {'g': p['gender'], 'amin': int.tryParse(p['age_min'] ?? ''), 'amax': int.tryParse(p['age_max'] ?? ''),
       'loc': p['location'], 'ms': p['marital_status'], 'off': page * 20});
  return _json({'results': res.map((x) => x.toColumnMap()).toList()});
}

// ---- Interests, consent, shortlist
Future<Response> sendInterest(Request r, String target) async {
  final uid = _uid(r); await _requireApproved(uid);
  final bl = await q('SELECT 1 FROM blocks WHERE (blocker=@u AND blocked=@t) OR (blocker=@t AND blocked=@u)', {'u': uid, 't': target});
  if (bl.isNotEmpty) throw _Http(403, 'You cannot send interest to this member.');
  try {
    final res = await q('INSERT INTO interests(from_user,to_user) VALUES(@f,@t) RETURNING id', {'f': uid, 't': target});
    await q("INSERT INTO notifications(user_id,kind,ref_id) VALUES(@t,'interest_received',@i)", {'t': target, 'i': res.first[0]});
    log('info', 'interest_sent', {'from': uid, 'to': target});
    return _json({'message': 'Interest sent.'}, 201);
  } on UniqueViolationException { throw _Http(409, 'You have already sent interest to this member.');
  } on ServerException { throw _Http(400, 'Could not send interest.'); }
}

Future<Response> respond(Request r, String id) async {
  final uid = _uid(r), accept = (await _body(r))['accept'] == true;
  final res = await q("UPDATE interests SET status=@s, responded_at=now() WHERE id=@i AND to_user=@u AND status='sent' RETURNING from_user",
      {'s': accept ? 'accepted' : 'rejected', 'i': id, 'u': uid});
  if (res.isEmpty) throw _Http(404, 'Interest request not found.');
  if (accept) await q("INSERT INTO notifications(user_id,kind,ref_id) VALUES(@f,'interest_accepted',@i)", {'f': res.first[0], 'i': id});
  log('info', 'interest_response', {'user': uid, 'accepted': accept});
  return _json({'message': accept ? 'Interest accepted.' : 'Interest declined.'});
}

/// Phone is revealed only when BOTH sides consented on an accepted interest.
Future<Response> consentPhone(Request r, String id) async {
  final uid = _uid(r);
  await q('''UPDATE interests SET phone_consent_from = phone_consent_from OR from_user=@u,
             phone_consent_to = phone_consent_to OR to_user=@u WHERE id=@i AND status='accepted' AND (from_user=@u OR to_user=@u)''', {'u': uid, 'i': id});
  final res = await q('''SELECT p.phone FROM interests i JOIN profiles p ON p.user_id = CASE WHEN i.from_user=@u THEN i.to_user ELSE i.from_user END
     WHERE i.id=@i AND i.phone_consent_from AND i.phone_consent_to''', {'u': uid, 'i': id});
  return _json({'phone': res.isEmpty ? null : res.first[0], 'message': res.isEmpty ? 'Waiting for the other member to agree.' : 'Phone number shared.'});
}

Future<Response> shortlist(Request r, String target, bool add) async {
  final uid = _uid(r);
  await q(add ? 'INSERT INTO shortlists VALUES(@u,@t) ON CONFLICT DO NOTHING' : 'DELETE FROM shortlists WHERE user_id=@u AND target_id=@t', {'u': uid, 't': target});
  return _json({'message': add ? 'Added to shortlist.' : 'Removed from shortlist.'});
}

// ---- Private media (stored outside any public path; served only through authorised endpoints)
final mediaDir = Directory(env['MEDIA_DIR'] ?? 'media')..createSync(recursive: true);

Future<String> _saveImage(Request r, [Map<String, dynamic>? body]) async {
  if ((int.tryParse(r.headers['content-length'] ?? '') ?? 0) > 3 * 1024 * 1024) throw _Http(413, 'Image is too large. Maximum 2 MB.');
  final b = body ?? await _body(r);
  List<int> bytes;
  try { bytes = base64Decode(b['data'] as String); } catch (_) { throw _Http(400, 'Invalid image.'); }
  if (bytes.length > 2 * 1024 * 1024) throw _Http(413, 'Image is too large. Maximum 2 MB.');
  final isJpg = bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  final isPng = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
  if (!isJpg && !isPng) throw _Http(400, 'Only JPG or PNG images are allowed.');
  final key = '${_rid()}${_rid()}${_rid()}.${isPng ? 'png' : 'jpg'}';
  await File('${mediaDir.path}/$key').writeAsBytes(bytes);
  return key;
}

Response _file(String key) {
  final f = File('${mediaDir.path}/$key');
  if (!f.existsSync()) throw _Http(404, 'File not found.');
  return Response.ok(f.openRead(), headers: {'content-type': key.endsWith('png') ? 'image/png' : 'image/jpeg'});
}

Future<Response> listPhotos(Request r) async {
  final res = await q('SELECT id::text AS id FROM photos WHERE user_id=@u ORDER BY created_at', {'u': _uid(r)});
  return _json({'photos': res.map((x) => x.toColumnMap()).toList()});
}

Future<Response> addPhoto(Request r) async {
  final uid = _uid(r);
  final c = await q('SELECT count(*) FROM photos WHERE user_id=@u', {'u': uid});
  if ((c.first[0] as int) >= 6) throw _Http(400, 'You can upload up to 6 photos.');
  final key = await _saveImage(r);
  await q('INSERT INTO photos(user_id,storage_key) VALUES(@u,@k)', {'u': uid, 'k': key});
  log('info', 'photo_added', {'user': uid});
  return _json({'message': 'Photo added.'}, 201);
}

Future<Response> deletePhoto(Request r, String id) async {
  final res = await q('DELETE FROM photos WHERE id=@i AND user_id=@u RETURNING storage_key', {'i': id, 'u': _uid(r)});
  if (res.isEmpty) throw _Http(404, 'Photo not found.');
  final f = File('${mediaDir.path}/${res.first[0]}');
  if (f.existsSync()) f.deleteSync();
  return _json({'message': 'Photo removed.'});
}

Future<Response> replacePhoto(Request r, String id) async {
  final uid = _uid(r);
  final old = await q('SELECT storage_key FROM photos WHERE id=@i AND user_id=@u', {'i': id, 'u': uid});
  if (old.isEmpty) throw _Http(404, 'Photo not found.');
  final key = await _saveImage(r);
  await q('UPDATE photos SET storage_key=@k WHERE id=@i', {'k': key, 'i': id});
  final f = File('${mediaDir.path}/${old.first[0]}');
  if (f.existsSync()) f.deleteSync();
  log('info', 'photo_replaced', {'user': uid});
  return _json({'message': 'Photo replaced.'});
}

/// Owner and admin always. Other members must be approved, not blocked, and the owner must allow it (public photos, or an accepted interest).
Future<Response> getPhoto(Request r, String id) async {
  final uid = _uid(r);
  final res = await q('''SELECT ph.storage_key FROM photos ph JOIN profiles p ON p.user_id=ph.user_id WHERE ph.id=@i AND (
      ph.user_id=@u
      OR EXISTS(SELECT 1 FROM users a WHERE a.id=@u AND a.role='admin' AND a.status<>'suspended')
      OR (EXISTS(SELECT 1 FROM users m WHERE m.id=@u AND m.role='member' AND m.status='approved')
          AND NOT EXISTS(SELECT 1 FROM blocks b WHERE (b.blocker=@u AND b.blocked=ph.user_id) OR (b.blocker=ph.user_id AND b.blocked=@u))
          AND (NOT p.photos_private
               OR EXISTS(SELECT 1 FROM interests x WHERE x.status='accepted' AND
                  ((x.from_user=@u AND x.to_user=ph.user_id) OR (x.to_user=@u AND x.from_user=ph.user_id))))))''', {'i': id, 'u': uid});
  if (res.isEmpty) throw _Http(404, 'Photo not available.');
  return _file(res.first[0] as String);
}

// ---- Inbox, shortlist, notifications
Future<Response> inbox(Request r) async {
  final res = await q('''SELECT i.id::text AS id, i.status, (i.to_user=@u) AS received, (i.phone_consent_from AND i.phone_consent_to) AS phone_shared,
      o.user_id::text AS member_id, o.name, o.age, o.location,
      (SELECT id::text FROM photos WHERE user_id=o.user_id ORDER BY created_at LIMIT 1) AS photo_id
    FROM interests i JOIN profiles o ON o.user_id = CASE WHEN i.to_user=@u THEN i.from_user ELSE i.to_user END
    WHERE (i.to_user=@u OR i.from_user=@u) AND NOT EXISTS (SELECT 1 FROM blocks b WHERE (b.blocker=@u AND b.blocked=o.user_id) OR (b.blocker=o.user_id AND b.blocked=@u)) ORDER BY i.created_at DESC LIMIT 100''', {'u': _uid(r)});
  return _json({'items': res.map((x) => x.toColumnMap()).toList()});
}

Future<Response> myShortlist(Request r) async {
  final res = await q('''SELECT p.user_id::text AS user_id, p.name, p.age, p.location, p.marital_status, p.occupation,
      (SELECT id::text FROM photos WHERE user_id=p.user_id ORDER BY created_at LIMIT 1) AS photo_id
    FROM shortlists s JOIN profiles p ON p.user_id=s.target_id WHERE s.user_id=@u AND NOT EXISTS (SELECT 1 FROM blocks b WHERE (b.blocker=@u AND b.blocked=p.user_id) OR (b.blocker=p.user_id AND b.blocked=@u))''', {'u': _uid(r)});
  return _json({'items': res.map((x) => x.toColumnMap()).toList()});
}

Future<Response> notifications(Request r) async {
  final uid = _uid(r);
  final res = await q('SELECT id::text AS id, kind, read, created_at::text AS created_at FROM notifications WHERE user_id=@u ORDER BY created_at DESC LIMIT 50', {'u': uid});
  await q('UPDATE notifications SET read=true WHERE user_id=@u AND NOT read', {'u': uid});
  return _json({'items': res.map((x) => x.toColumnMap()).toList()});
}

// ---- Payments (UPI QR + screenshot, verified by an admin)
Future<Response> addPayment(Request r) async {
  final uid = _uid(r), b = await _body(r), amt = b['amount_rupees'], ref = _opt(b['txn_ref']);
  if (amt != null && (amt is! int || amt < 1 || amt > 100000)) throw _Http(400, 'Amount must be between 1 and 100000 rupees.');
  if (ref != null && ref.length > 40) throw _Http(400, 'The transaction ID is too long.');
  final key = await _saveImage(r, b);
  await q('INSERT INTO payments(user_id,screenshot_key,amount_paise,txn_ref) VALUES(@u,@k,@amt,@ref)', {'u': uid, 'k': key, 'amt': amt == null ? null : amt * 100, 'ref': ref});
  log('info', 'payment_uploaded', {'user': uid});
  return _json({'message': 'Screenshot uploaded. We will verify it shortly.'}, 201);
}

Future<Response> myPayments(Request r) async {
  final res = await q('SELECT id::text AS id, status, method, amount_paise, created_at::text AS created_at FROM payments WHERE user_id=@u AND status<>\'created\' ORDER BY created_at DESC', {'u': _uid(r)});
  return _json({'items': res.map((x) => x.toColumnMap()).toList()});
}

// ---- Payment details set by the admin (UPI ID, payee name, amount, QR image) + Razorpay online payments
bool get _rzpOn => (env['RAZORPAY_KEY_ID'] ?? '').isNotEmpty && (env['RAZORPAY_KEY_SECRET'] ?? '').isNotEmpty;
final _upiRe = RegExp(r'^[A-Za-z0-9._\-]{2,}@[A-Za-z][A-Za-z0-9]{1,}$');

Future<Response> paymentInfo(Request r) async {
  _uid(r);
  final x = (await q('SELECT upi_id,payee_name,amount_rupees,(qr_key IS NOT NULL),extract(epoch FROM updated_at)::bigint FROM payment_settings WHERE id=1')).first;
  return _json({'upi_id': x[0], 'payee_name': x[1], 'amount_rupees': x[2], 'has_qr': x[3] == true, 'version': x[4],
    'razorpay': _rzpOn && x[2] != null, 'razorpay_key_id': _rzpOn ? env['RAZORPAY_KEY_ID'] : null});
}

Future<Response> paymentQr(Request r) async {
  _uid(r);
  final res = await q('SELECT qr_key FROM payment_settings WHERE id=1');
  if (res.first[0] == null) throw _Http(404, 'The QR code has not been added yet.');
  return _file(res.first[0] as String);
}

/// Donations need no login: the website shows the admin's UPI ID and QR code. Nothing else from the settings is exposed.
Future<Response> publicDonate(Request r) async {
  final x = (await q('SELECT upi_id,payee_name,(qr_key IS NOT NULL),extract(epoch FROM updated_at)::bigint FROM payment_settings WHERE id=1')).first;
  return _json({'upi_id': x[0], 'payee_name': x[1], 'has_qr': x[2] == true, 'version': x[3]});
}

Future<Response> publicDonateQr(Request r) async {
  final res = await q('SELECT qr_key FROM payment_settings WHERE id=1');
  if (res.first[0] == null) throw _Http(404, 'The QR code has not been added yet.');
  return _file(res.first[0] as String);
}

Future<Response> adminSavePaymentSettings(Request r) async {
  final admin = await _admin(r), b = await _body(r);
  final upi = (b['upi_id'] as String? ?? '').trim(), name = (b['payee_name'] as String? ?? '').trim(), amt = b['amount_rupees'];
  if (name.length < 2 || name.length > 60) throw _Http(400, 'Enter the payee name (2 to 60 characters).');
  if (upi.isEmpty || !_upiRe.hasMatch(upi)) throw _Http(400, 'Enter a valid UPI ID, like name@bank.');
  if (amt is! int || amt < 1 || amt > 100000) throw _Http(400, 'Enter the amount in rupees (1 to 100000).');
  if ((await q('SELECT qr_key IS NOT NULL FROM payment_settings WHERE id=1')).first[0] != true) throw _Http(400, 'Upload the payment QR code first.');
  await q('UPDATE payment_settings SET upi_id=@upi, payee_name=@pn, amount_rupees=@amt, updated_at=now() WHERE id=1',
      {'upi': upi.isEmpty ? null : upi, 'pn': name.isEmpty ? null : name, 'amt': amt});
  await q("INSERT INTO audit_log(actor,action) VALUES(@u,'payment_settings_updated')", {'u': admin});
  log('info', 'payment_settings_updated', {'admin': admin});
  return _json({'message': 'Payment details saved.'});
}

Future<Response> adminDeletePaymentSettings(Request r) async {
  final admin = await _admin(r);
  final old = (await q('SELECT qr_key FROM payment_settings WHERE id=1')).first[0] as String?;
  await q('UPDATE payment_settings SET upi_id=NULL, payee_name=NULL, amount_rupees=NULL, qr_key=NULL, updated_at=now() WHERE id=1');
  if (old != null) { final f = File('${mediaDir.path}/$old'); if (f.existsSync()) f.deleteSync(); }
  await q("INSERT INTO audit_log(actor,action) VALUES(@u,'payment_settings_deleted')", {'u': admin});
  return _json({'message': 'Payment details deleted.'});
}

Future<Response> adminDeleteQr(Request r) async {
  final admin = await _admin(r);
  final old = (await q('SELECT qr_key FROM payment_settings WHERE id=1')).first[0] as String?;
  await q('UPDATE payment_settings SET qr_key=NULL, updated_at=now() WHERE id=1');
  if (old != null) { final f = File('${mediaDir.path}/$old'); if (f.existsSync()) f.deleteSync(); }
  await q("INSERT INTO audit_log(actor,action) VALUES(@u,'payment_qr_deleted')", {'u': admin});
  return _json({'message': 'QR code removed.'});
}

Future<Response> adminUploadQr(Request r) async {
  final admin = await _admin(r), key = await _saveImage(r);
  final old = await q('SELECT qr_key FROM payment_settings WHERE id=1');
  await q('UPDATE payment_settings SET qr_key=@k, updated_at=now() WHERE id=1', {'k': key});
  final oldKey = old.first[0] as String?;
  if (oldKey != null) { final f = File('${mediaDir.path}/$oldKey'); if (f.existsSync()) f.deleteSync(); }
  await q("INSERT INTO audit_log(actor,action) VALUES(@u,'payment_qr_updated')", {'u': admin});
  return _json({'message': 'QR code saved.'}, 201);
}

Future<Map<String, dynamic>> _rzpCreateOrder(int paise, String receipt, String uid) async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final req = await c.postUrl(Uri.parse('https://api.razorpay.com/v1/orders'));
    req.headers
      ..set('content-type', 'application/json')
      ..set('authorization', 'Basic ${base64Encode(utf8.encode('${env['RAZORPAY_KEY_ID']}:${env['RAZORPAY_KEY_SECRET']}'))}');
    req.add(utf8.encode(jsonEncode({'amount': paise, 'currency': 'INR', 'receipt': receipt, 'notes': {'user_id': uid}})));
    final res = await req.close().timeout(const Duration(seconds: 20));
    final body = await utf8.decoder.bind(res).join();
    if (res.statusCode != 200) {
      log('error', 'razorpay_order_failed', {'status': res.statusCode}); // never log keys or the response body
      throw _Http(502, 'Could not start the payment. Please try again.');
    }
    return jsonDecode(body) as Map<String, dynamic>;
  } on _Http {
    rethrow;
  } catch (e) {
    log('error', 'razorpay_unreachable', {'error': e.runtimeType.toString()});
    throw _Http(502, 'Could not reach the payment service. Please try again.');
  } finally {
    c.close();
  }
}

/// Constant-time HMAC-SHA256 check (hex), used for the checkout signature and the webhook.
bool _sigOk(String data, String sig, String key) {
  final mac = Hmac(sha256, utf8.encode(key)).convert(utf8.encode(data)).toString();
  if (mac.length != sig.length) return false;
  var d = 0;
  for (var i = 0; i < mac.length; i++) { d |= mac.codeUnitAt(i) ^ sig.codeUnitAt(i); }
  return d == 0;
}

Future<void> _markPaid(String orderId, String payId) async {
  final res = await q("UPDATE payments SET status='verified', verified_at=now(), rzp_payment_id=@p WHERE rzp_order_id=@o AND status='created' RETURNING user_id::text", {'p': payId, 'o': orderId});
  if (res.isNotEmpty) {
    await q("INSERT INTO notifications(user_id,kind) VALUES(@t,'payment_verified')", {'t': res.first[0]});
    log('info', 'razorpay_paid', {'user': res.first[0]});
  }
}

Future<Response> rzpOrder(Request r) async {
  final uid = _uid(r);
  if (!_rzpOn) throw _Http(503, 'Online payment is not set up yet. Please pay by UPI.');
  final rupees = (await q('SELECT amount_rupees FROM payment_settings WHERE id=1')).first[0] as int?;
  if (rupees == null) throw _Http(400, 'The payment amount has not been set by the admin yet.');
  final paise = rupees * 100, order = await _rzpCreateOrder(paise, 'nsm_${_rid()}', uid), orderId = order['id'] as String?;
  if (orderId == null) throw _Http(502, 'Could not start the payment. Please try again.');
  await q("INSERT INTO payments(user_id,method,amount_paise,rzp_order_id,status) VALUES(@u,'razorpay',@p,@o,'created')", {'u': uid, 'p': paise, 'o': orderId});
  return _json({'order_id': orderId, 'amount_paise': paise, 'currency': 'INR', 'key_id': env['RAZORPAY_KEY_ID']});
}

Future<Response> rzpVerify(Request r) async {
  final uid = _uid(r), b = await _body(r);
  if (!_rzpOn) throw _Http(503, 'Online payment is not set up yet.');
  final orderId = b['razorpay_order_id'] as String? ?? '', payId = b['razorpay_payment_id'] as String? ?? '', sig = (b['razorpay_signature'] as String? ?? '').toLowerCase();
  final res = await q('SELECT status FROM payments WHERE rzp_order_id=@o AND user_id=@u', {'o': orderId, 'u': uid});
  if (res.isEmpty) throw _Http(404, 'Payment not found.');
  if (res.first[0] == 'verified') return _json({'message': 'Payment verified. Thank you!'});
  if (!_sigOk('$orderId|$payId', sig, env['RAZORPAY_KEY_SECRET']!)) {
    log('warn', 'razorpay_bad_signature', {'user': uid});
    throw _Http(400, 'The payment could not be verified. If money was deducted, please contact support.');
  }
  await _markPaid(orderId, payId);
  return _json({'message': 'Payment successful. Thank you!'});
}

/// Razorpay calls this even if the member closes the app before verification. Set RAZORPAY_WEBHOOK_SECRET and add the URL in the Razorpay dashboard.
Future<Response> rzpWebhook(Request r) async {
  final key = env['RAZORPAY_WEBHOOK_SECRET'] ?? '', raw = await r.readAsString();
  if (key.isEmpty || !_sigOk(raw, r.headers['x-razorpay-signature'] ?? '', key)) throw _Http(400, 'Invalid signature.');
  final ev = jsonDecode(raw) as Map<String, dynamic>;
  final pay = ((ev['payload'] as Map?)?['payment'] as Map?)?['entity'] as Map?;
  if (pay != null && (ev['event'] == 'payment.captured' || ev['event'] == 'order.paid')) await _markPaid('${pay['order_id']}', '${pay['id']}');
  return _json({'ok': true});
}

// ---- Marriages: a member of an accepted interest reports it, an admin confirms it, and both profiles leave search
Future<Response> reportMarried(Request r, String id) async {
  final uid = _uid(r);
  final res = await q('''SELECT i.from_user::text, i.to_user::text, pf.name, pt.name FROM interests i
      LEFT JOIN profiles pf ON pf.user_id=i.from_user LEFT JOIN profiles pt ON pt.user_id=i.to_user
      WHERE i.id=@i AND i.status='accepted' AND (i.from_user=@u OR i.to_user=@u)''', {'i': id, 'u': uid});
  if (res.isEmpty) throw _Http(404, 'Accepted interest not found.');
  final x = res.first;
  try {
    await q('INSERT INTO marriages(interest_id,user_a,user_b,names,reported_by) VALUES(@i,@f,@t,@n,@u)', {'i': id, 'f': x[0], 't': x[1], 'n': '${x[2] ?? 'Member'} & ${x[3] ?? 'Member'}', 'u': uid});
  } on UniqueViolationException {
    throw _Http(409, 'This marriage has already been reported.');
  }
  log('info', 'marriage_reported', {'user': uid});
  return _json({'message': 'Congratulations! Our team will confirm it shortly.'}, 201);
}

Future<Response> adminMarriages(Request r) async {
  await _admin(r);
  final st = r.url.queryParameters['status'];
  final res = await q("SELECT id::text AS id, status, names, reported_at::text AS reported_at, decided_at::text AS decided_at FROM marriages WHERE (@s::text IS NULL OR status=@s) ORDER BY reported_at DESC LIMIT 100",
      {'s': (st == null || st == 'all') ? null : st});
  return _json({'items': res.map((x) => x.toColumnMap()).toList()});
}

Future<Response> adminDecideMarriage(Request r, String id) async {
  final admin = await _admin(r), ok = (await _body(r))['confirm'] == true;
  final res = await q("UPDATE marriages SET status=@s, decided_at=now(), decided_by=@u WHERE id=@i AND status='reported' RETURNING user_a::text, user_b::text",
      {'s': ok ? 'confirmed' : 'rejected', 'u': admin, 'i': id});
  if (res.isEmpty) throw _Http(404, 'Pending marriage report not found.');
  if (ok) {
    for (final who in [res.first[0], res.first[1]]) {
      if (who == null) continue;
      await q('UPDATE users SET matched_at=now() WHERE id=@t', {'t': who});
      await q("INSERT INTO notifications(user_id,kind) VALUES(@t,'marriage_confirmed')", {'t': who});
    }
  }
  await q("INSERT INTO audit_log(actor,action) VALUES(@u,@act)", {'u': admin, 'act': ok ? 'marriage_confirmed' : 'marriage_rejected'});
  return _json({'message': ok ? 'Marriage confirmed. Both profiles are removed from search.' : 'Report rejected.'});
}

// ---- Admin reports: weekly / monthly numbers and the monthly member list
String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<Response> adminInsights(Request r) async {
  await _admin(r);
  final qp = r.url.queryParameters, unit = qp['period'] == 'month' ? 'month' : 'week';
  final n = (int.tryParse(qp['count'] ?? '') ?? (unit == 'week' ? 8 : 12)).clamp(1, 24).toInt();
  final now = DateTime.now().toUtc(), today = DateTime.utc(now.year, now.month, now.day);
  final starts = <DateTime>[for (var i = n - 1; i >= 0; i--) unit == 'week' ? today.subtract(Duration(days: today.weekday - 1 + 7 * i)) : DateTime.utc(now.year, now.month - i, 1)];
  final from = _ymd(starts.first);
  String ts(String col) => "date_trunc('$unit', $col AT TIME ZONE 'UTC')::date::text";
  String dt(String col) => "date_trunc('$unit', $col::timestamp)::date::text";
  Future<Map<String, int>> m(String sql) async {
    final res = await q(sql, {'from': from});
    return {for (final x in res) x[0] as String: (x[1] as num).toInt()};
  }
  final regs = await m("SELECT ${ts('created_at')}, count(*) FROM users WHERE role='member' AND created_at >= @from::date GROUP BY 1");
  final views = await m("SELECT ${dt('day')}, count(*) FROM profile_views WHERE day >= @from::date GROUP BY 1");
  final viewers = await m("SELECT ${dt('day')}, count(DISTINCT viewer) FROM profile_views WHERE day >= @from::date GROUP BY 1");
  final sent = await m("SELECT ${ts('created_at')}, count(*) FROM interests WHERE created_at >= @from::date GROUP BY 1");
  final accepted = await m("SELECT ${ts('responded_at')}, count(*) FROM interests WHERE status='accepted' AND responded_at >= @from::date GROUP BY 1");
  final creq = await m("SELECT ${ts('created_at')}, count(*) FROM contact_requests WHERE created_at >= @from::date GROUP BY 1");
  final cacc = await m("SELECT ${ts('responded_at')}, count(*) FROM contact_requests WHERE status='accepted' AND responded_at >= @from::date GROUP BY 1");
  final marr = await m("SELECT ${ts('decided_at')}, count(*) FROM marriages WHERE status='confirmed' AND decided_at >= @from::date GROUP BY 1");
  final pays = await m("SELECT ${ts('verified_at')}, count(*) FROM payments WHERE status='verified' AND verified_at >= @from::date GROUP BY 1");
  final amounts = await m("SELECT ${ts('verified_at')}, coalesce(sum(amount_paise),0)/100 FROM payments WHERE status='verified' AND verified_at >= @from::date GROUP BY 1");
  final rows = [for (final s in starts) {
    'start': _ymd(s), 'registrations': regs[_ymd(s)] ?? 0, 'profile_views': views[_ymd(s)] ?? 0, 'viewers': viewers[_ymd(s)] ?? 0,
    'interests_sent': sent[_ymd(s)] ?? 0, 'interests_accepted': accepted[_ymd(s)] ?? 0, 'contact_requests': creq[_ymd(s)] ?? 0,
    'contacts_shared': cacc[_ymd(s)] ?? 0, 'marriages': marr[_ymd(s)] ?? 0, 'payments': pays[_ymd(s)] ?? 0, 'payment_amount': amounts[_ymd(s)] ?? 0,
  }];
  final st = await q("SELECT status, count(*) FROM users WHERE role='member' GROUP BY 1");
  final byStatus = {for (final x in st) x[0] as String: (x[1] as num).toInt()};
  final mar = (await q("SELECT count(*) FROM marriages WHERE status='confirmed'")).first[0] as num;
  final amt = (await q("SELECT coalesce(sum(amount_paise),0)/100 FROM payments WHERE status='verified'")).first[0] as num;
  return _json({'period': unit, 'rows': rows, 'totals': {'members': byStatus.values.fold<int>(0, (a, b) => a + b), 'approved': byStatus['approved'] ?? 0, 'pending': byStatus['pending'] ?? 0,
    'suspended': byStatus['suspended'] ?? 0, 'marriages': mar.toInt(), 'payment_amount': amt.toInt()}});
}

Future<Response> adminMemberReport(Request r) async {
  await _admin(r);
  final month = r.url.queryParameters['month'] ?? '';
  if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month)) throw _Http(400, 'Choose a month like 2026-11.');
  final res = await q('''SELECT u.email, u.status, u.created_at::date::text AS joined, p.name, p.age, p.gender, p.location, p.marital_status, p.education, p.occupation, p.phone,
      (SELECT count(*) FROM interests i WHERE i.from_user=u.id) AS interests_sent,
      (SELECT count(*) FROM interests i WHERE i.to_user=u.id) AS interests_received,
      (SELECT count(*) FROM interests i WHERE (i.from_user=u.id OR i.to_user=u.id) AND i.status='accepted') AS connections,
      (SELECT count(*) FROM profile_views v WHERE v.viewed=u.id) AS profile_views
    FROM users u LEFT JOIN profiles p ON p.user_id=u.id
    WHERE u.role='member' AND to_char(u.created_at AT TIME ZONE 'UTC','YYYY-MM')=@m ORDER BY u.created_at''', {'m': month});
  return _json({'month': month, 'items': res.map((x) => x.toColumnMap()).toList()});
}

// ---- Admin (role re-checked in the database on every call, every action audited)
Future<String> _admin(Request r) async {
  final uid = _uid(r);
  final res = await q('SELECT role,status FROM users WHERE id=@u', {'u': uid});
  if (res.isEmpty || res.first[0] != 'admin' || res.first[1] == 'suspended') throw _Http(403, 'Admin access only.');
  return uid;
}

/// The built-in 'setup' account can do exactly one thing: create the real admin. It is disabled right after.
Future<Response> createAdmin(Request r) async {
  final uid = _uid(r);
  final me = await q('SELECT role,status FROM users WHERE id=@u', {'u': uid});
  if (me.isEmpty || !['setup', 'admin'].contains(me.first[0]) || me.first[1] == 'suspended') throw _Http(403, 'Not allowed.');
  final b = await _body(r), email = (b['email'] as String? ?? '').trim().toLowerCase(), pw = b['password'] as String? ?? '';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) throw _Http(400, 'Enter a valid email address.');
  if (pw.length < 8) throw _Http(400, 'Password must be at least 8 characters.');
  final sec = _parseSecurity(b['security']);
  final newId = await _createUser(email, pw, sec, role: 'admin', status: 'approved');
  await q("INSERT INTO audit_log(actor,action,target) VALUES(@u,'admin_created',@t)", {'u': uid, 't': newId});
  final wasSetup = me.first[0] == 'setup';
  if (wasSetup) {
    await q("UPDATE users SET status='suspended' WHERE id=@u", {'u': uid});
    await q("INSERT INTO audit_log(actor,action,target) VALUES(@u,'setup_account_disabled',@u)", {'u': uid});
  }
  log('info', 'admin_created', {'by': uid, 'admin': newId, 'setup_disabled': wasSetup});
  return _json({'message': wasSetup ? 'Admin created. The setup account is now disabled. Sign in with the new admin.' : 'Admin created.'}, 201);
}

Future<Response> adminUsers(Request r) async {
  await _admin(r);
  final res = await q('''SELECT u.id::text AS id, u.email, u.status, p.name, p.age, p.gender, p.location, p.marital_status
    FROM users u LEFT JOIN profiles p ON p.user_id=u.id
    WHERE u.role='member' AND (@s::text IS NULL OR u.status=@s) ORDER BY u.created_at DESC LIMIT 100''', {'s': r.url.queryParameters['status']});
  return _json({'items': res.map((x) => x.toColumnMap()).toList()});
}

Future<Response> adminUserDetail(Request r, String id) async {
  await _admin(r);
  final u = await q("SELECT email,status,status_reason,created_at::text FROM users WHERE id=@i AND role='member'", {'i': id});
  if (u.isEmpty) throw _Http(404, 'Member not found.');
  final p = await q('SELECT row_to_json(p) FROM profiles p WHERE user_id=@i', {'i': id});
  final ph = await q('SELECT id::text AS id FROM photos WHERE user_id=@i ORDER BY created_at', {'i': id});
  return _json({'id': id, 'email': u.first[0], 'status': u.first[1], 'status_reason': u.first[2], 'joined': u.first[3],
    'profile': p.isEmpty ? null : p.first[0], 'photos': ph.map((x) => x.toColumnMap()).toList()});
}

Future<Response> adminSetStatus(Request r, String id) async {
  final admin = await _admin(r), b = await _body(r), s = b['status'], reason = ((b['reason'] as String?) ?? '').trim();
  if (!['approved', 'rejected', 'suspended', 'pending'].contains(s)) throw _Http(400, 'Invalid status.');
  if (s == 'suspended' && reason.length < 3) throw _Http(400, 'Please write a reason for the suspension. It is shown to the member.');
  if (reason.length > 300) throw _Http(400, 'The reason must be under 300 characters.');
  final res = await q("UPDATE users SET status=@s, status_reason=@why WHERE id=@i AND role='member' RETURNING id",
      {'s': s, 'why': (s == 'approved' || s == 'pending' || reason.isEmpty) ? null : reason, 'i': id});
  if (res.isEmpty) throw _Http(404, 'Member not found.');
  await q('INSERT INTO audit_log(actor,action,target) VALUES(@u,@act,@i)', {'u': admin, 'act': 'user_$s', 'i': id});
  await q('INSERT INTO notifications(user_id,kind) VALUES(@i,@k)', {'i': id, 'k': 'profile_$s'});
  log('info', 'admin_set_status', {'admin': admin, 'target': id, 'status': s});
  return _json({'message': 'Member marked $s.'});
}

Future<Response> adminPayments(Request r) async {
  await _admin(r);
  final st = r.url.queryParameters['status'];
  final res = await q('''SELECT pay.id::text AS id, pay.status, pay.method, pay.created_at::text AS created_at, pay.verified_at::text AS verified_at,
      u.email, p.name, (pay.amount_paise/100) AS amount_rupees, pay.txn_ref, pay.admin_note, a.email AS verified_by_email, (pay.screenshot_key IS NOT NULL) AS has_screenshot
    FROM payments pay JOIN users u ON u.id=pay.user_id LEFT JOIN profiles p ON p.user_id=pay.user_id LEFT JOIN users a ON a.id=pay.verified_by
    WHERE pay.status<>'created' AND (@s::text IS NULL OR pay.status=@s) ORDER BY pay.created_at DESC LIMIT 200''',
      {'s': (st == null || st == 'all') ? null : st});
  return _json({'items': res.map((x) => x.toColumnMap()).toList()});
}
Future<Response> adminScreenshot(Request r, String id) async {
  await _admin(r);
  final res = await q('SELECT screenshot_key FROM payments WHERE id=@i', {'i': id});
  if (res.isEmpty || res.first[0] == null) throw _Http(404, 'No screenshot for this payment.');
  return _file(res.first[0] as String);
}

Future<Response> adminVerify(Request r, String id) async {
  final admin = await _admin(r), b = await _body(r), ok = b['approve'] == true, note = _opt(b['note']), amt = b['amount_rupees'];
  if (amt != null && (amt is! int || amt < 1 || amt > 100000)) throw _Http(400, 'Amount must be between 1 and 100000 rupees.');
  final res = await q("UPDATE payments SET status=@s, verified_by=@a, verified_at=now(), admin_note=@note, amount_paise=COALESCE(@amt::int*100, amount_paise) WHERE id=@i AND status='pending' RETURNING user_id",
      {'s': ok ? 'verified' : 'rejected', 'a': admin, 'note': note, 'amt': amt, 'i': id});
  if (res.isEmpty) throw _Http(404, 'Pending payment not found.');
  await q('INSERT INTO notifications(user_id,kind,ref_id) VALUES(@t,@k,@i)', {'t': res.first[0], 'k': ok ? 'payment_verified' : 'payment_rejected', 'i': id});
  await q('INSERT INTO audit_log(actor,action,target) VALUES(@u,@act,@t)', {'u': admin, 'act': ok ? 'payment_verified' : 'payment_rejected', 't': res.first[0]});
  log('info', 'admin_payment', {'admin': admin, 'payment': id, 'verified': ok});
  return _json({'message': ok ? 'Payment verified.' : 'Payment rejected.'});
}

// ---- Chat: only between two members with an ACCEPTED interest. Message text is never logged.
Future<String> _chatPeer(String uid, String interestId) async {
  final res = await q("SELECT (CASE WHEN from_user=@u THEN to_user ELSE from_user END)::text FROM interests WHERE id=@i AND status='accepted' AND (from_user=@u OR to_user=@u)", {'u': uid, 'i': interestId});
  if (res.isEmpty) throw _Http(403, 'Chat opens after both members accept the interest.');
  final peer = res.first[0] as String;
  final bl = await q('SELECT 1 FROM blocks WHERE (blocker=@u AND blocked=@t) OR (blocker=@t AND blocked=@u)', {'u': uid, 't': peer});
  if (bl.isNotEmpty) throw _Http(403, 'Chat is not available with this member.');
  return peer;
}

Future<Response> getMessages(Request r, String id) async {
  final uid = _uid(r);
  await _chatPeer(uid, id);
  final after = int.tryParse(r.url.queryParameters['after'] ?? '') ?? 0;
  final res = await q('''SELECT * FROM (SELECT id, (sender=@u) AS mine, body, created_at::text AS created_at FROM messages
      WHERE interest_id=@i AND id>@after ORDER BY id DESC LIMIT 100) t ORDER BY id''', {'u': uid, 'i': id, 'after': after});
  return _json({'items': res.map((x) => x.toColumnMap()).toList()});
}

Future<Response> sendMessage(Request r, String id) async {
  final uid = _uid(r);
  await _requireApproved(uid);
  final peer = await _chatPeer(uid, id);
  final ps = await q('SELECT status FROM users WHERE id=@u', {'u': peer});
  if (ps.isEmpty || ps.first[0] != 'approved') throw _Http(403, 'This member is not available right now.');
  final text = ((await _body(r))['text'] as String? ?? '').trim();
  if (text.isEmpty || text.length > 1000) throw _Http(400, 'Message must be 1 to 1000 characters.');
  final recent = await q("SELECT count(*) FROM messages WHERE sender=@u AND created_at > now() - interval '1 minute'", {'u': uid});
  if ((recent.first[0] as int) >= 30) throw _Http(429, 'You are sending messages too fast. Please wait a moment.');
  await q('INSERT INTO messages(interest_id,sender,body) VALUES(@i,@u,@b)', {'i': id, 'u': uid, 'b': text});
  await q("INSERT INTO notifications(user_id,kind,ref_id) SELECT @t,'message_received',@i WHERE NOT EXISTS (SELECT 1 FROM notifications WHERE user_id=@t AND kind='message_received' AND ref_id=@i AND NOT read)", {'t': peer, 'i': id});
  log('info', 'message_sent', {'from': uid, 'interest': id});
  return _json({'message': 'Sent.'}, 201);
}

// ---- Account deletion (required by Play for apps with sign-up; also Phase 10 "member deletion request")
Future<Response> deleteAccount(Request r) async {
  final uid = _uid(r), b = await _body(r);
  final res = await q('SELECT password_hash FROM users WHERE id=@u', {'u': uid});
  if (res.isEmpty || !DBCrypt().checkpw(b['password'] as String? ?? '', res.first[0] as String)) throw _Http(403, 'Password is incorrect.');
  final keys = await q('SELECT storage_key FROM photos WHERE user_id=@u UNION ALL SELECT screenshot_key FROM payments WHERE user_id=@u', {'u': uid});
  await q('DELETE FROM users WHERE id=@u', {'u': uid});
  for (final k in keys) {
    final f = File('${mediaDir.path}/${k[0]}');
    if (f.existsSync()) f.deleteSync();
  }
  log('info', 'account_deleted', {'user': uid});
  return _json({'message': 'Your account and data were deleted.'});
}

// ---- Forgot / reset password (6-digit emailed code, stored hashed, 30 min, 5 attempts)
String _sha(String v) => sha256.convert(utf8.encode(v)).toString();

Future<void> _sendMail(String to, String subject, String body) async {
  final host = env['SMTP_HOST'];
  if (host == null || host.isEmpty) {
    if (env['APP_ENV'] == 'production') { log('error', 'smtp_not_configured'); } else { log('warn', 'dev_mail', {'to': to, 'subject': subject, 'body': body}); }
    return;
  }
  try {
    final port = int.tryParse(env['SMTP_PORT'] ?? '') ?? 587;
    final server = SmtpServer(host, port: port, username: env['SMTP_USER'], password: env['SMTP_PASS'], ssl: port == 465);
    await send(Message()..from = Address(env['SMTP_FROM'] ?? 'no-reply@localhost', 'Nari Shakthi Matrimony')..recipients.add(to)..subject = subject..text = body, server);
  } catch (e) {
    log('error', 'mail_failed', {'error': e.runtimeType.toString()}); // never log the body (it holds the code)
  }
}

/// Signed-in users (admins and members) change their password by giving the old one.
Future<Response> changePassword(Request r) async {
  final uid = _uid(r), b = await _body(r), oldPw = b['old_password'] as String? ?? '', newPw = b['new_password'] as String? ?? '';
  if (newPw.length < 8) throw _Http(400, 'The new password must be at least 8 characters.');
  if (newPw == oldPw) throw _Http(400, 'The new password must be different from the old one.');
  final res = await q('SELECT password_hash FROM users WHERE id=@u', {'u': uid});
  if (res.isEmpty || !DBCrypt().checkpw(oldPw, res.first[0] as String)) {
    log('warn', 'password_change_failed', {'user': uid});
    throw _Http(400, 'The old password is not correct.');
  }
  await q('UPDATE users SET password_hash=@h WHERE id=@u', {'h': DBCrypt().hashpw(newPw, DBCrypt().gensalt()), 'u': uid});
  await q("INSERT INTO audit_log(actor,action) VALUES(@u,'password_changed')", {'u': uid});
  log('info', 'password_changed', {'user': uid});
  return _json({'message': 'Your password has been changed.'});
}

Future<Response> forgot(Request r) async {
  final email = ((await _body(r))['email'] as String? ?? '').trim().toLowerCase();
  final res = await q('SELECT id::text FROM users WHERE email=@e', {'e': email});
  if (res.isNotEmpty) {
    final uid = res.first[0] as String, code = (100000 + _rnd.nextInt(900000)).toString();
    await q('UPDATE password_resets SET used=true WHERE user_id=@u AND NOT used', {'u': uid});
    await q("INSERT INTO password_resets(user_id,code_hash,expires_at) VALUES(@u,@h, now() + interval '30 minutes')", {'u': uid, 'h': _sha(code)});
    await _sendMail(email, 'Your Nari Shakthi Matrimony reset code', 'Your reset code is $code. It expires in 30 minutes. If you did not ask for it, ignore this email.');
    log('info', 'reset_requested', {'user': uid});
  }
  return _json({'message': 'If this email is registered, a reset code has been sent.'}); // same answer either way
}

Future<Response> resetPassword(Request r) async {
  final b = await _body(r);
  final email = (b['email'] as String? ?? '').trim().toLowerCase(), code = (b['code'] as String? ?? '').trim(), pw = b['password'] as String? ?? '';
  if (pw.length < 8) throw _Http(400, 'Password must be at least 8 characters.');
  const bad = 'Invalid or expired code.';
  final res = await q('''SELECT pr.id, pr.user_id::text, pr.code_hash, pr.attempts FROM password_resets pr JOIN users u ON u.id=pr.user_id
      WHERE u.email=@e AND NOT pr.used AND pr.expires_at>now() ORDER BY pr.id DESC LIMIT 1''', {'e': email});
  if (res.isEmpty || (res.first[3] as int) >= 5) throw _Http(400, bad);
  final row = res.first;
  if (row[2] != _sha(code)) {
    await q('UPDATE password_resets SET attempts=attempts+1 WHERE id=@rid', {'rid': row[0]});
    throw _Http(400, bad);
  }
  await q('UPDATE users SET password_hash=@h WHERE id=@u', {'h': DBCrypt().hashpw(pw, DBCrypt().gensalt()), 'u': row[1]});
  await q('UPDATE password_resets SET used=true WHERE user_id=@u', {'u': row[1]});
  log('info', 'password_reset_done', {'user': row[1]});
  return _json({'message': 'Password changed. Sign in with your new password.'});
}

// ---- Password recovery with the 3 security questions
Map<String, String> _q(String id) => {'id': id, 'text': _secQuestions[id]!};

Future<Response> recoverQuestions(Request r) async {
  final email = ((await _body(r))['email'] as String? ?? '').trim().toLowerCase();
  final res = await q('SELECT s.question_id FROM security_answers s JOIN users u ON u.id=s.user_id WHERE u.email=@e ORDER BY s.slot', {'e': email});
  List<String> ids;
  if (res.length == 3) {
    ids = res.map((x) => x[0] as String).toList();
  } else {
    // Unknown email: answer in the same shape (3 stable questions) so nobody can probe which emails are registered.
    final keys = _secQuestions.keys.toList(), h = sha256.convert(utf8.encode(email)).bytes;
    ids = [for (var i = 0; i < 3; i++) keys[(h[0] + i * 3) % keys.length]];
  }
  return _json({'questions': ids.map(_q).toList()});
}

Future<Response> recoverReset(Request r) async {
  final b = await _body(r), email = (b['email'] as String? ?? '').trim().toLowerCase(), pw = b['password'] as String? ?? '', ans = b['answers'];
  if (pw.length < 8) throw _Http(400, 'Password must be at least 8 characters.');
  if (ans is! List || ans.length != 3) throw _Http(400, 'Answer all 3 questions.');
  const bad = 'One or more answers are incorrect.';
  final u = await q('SELECT id::text FROM users WHERE email=@e', {'e': email});
  if (u.isEmpty) { DBCrypt().hashpw('x', DBCrypt().gensalt()); throw _Http(400, bad); }
  final uid = u.first[0] as String;
  final lock = await q('SELECT locked_until > now() FROM security_attempts WHERE user_id=@u', {'u': uid});
  if (lock.isNotEmpty && lock.first[0] == true) throw _Http(429, 'Too many wrong answers. Please try again in 30 minutes.');
  final rows = await q('SELECT answer_hash FROM security_answers WHERE user_id=@u ORDER BY slot', {'u': uid});
  var ok = rows.length == 3;
  if (ok) {
    for (var i = 0; i < 3; i++) {
      if (!DBCrypt().checkpw(_norm('${ans[i]}'), rows[i][0] as String)) ok = false; // checks all 3, never stops early
    }
  }
  if (!ok) {
    await q('''INSERT INTO security_attempts(user_id,failed) VALUES(@u,1) ON CONFLICT (user_id) DO UPDATE SET
      failed = CASE WHEN security_attempts.failed+1 >= 5 THEN 0 ELSE security_attempts.failed+1 END,
      locked_until = CASE WHEN security_attempts.failed+1 >= 5 THEN now() + interval '30 minutes' ELSE security_attempts.locked_until END''', {'u': uid});
    log('warn', 'recovery_failed', {'user': uid});
    throw _Http(400, bad);
  }
  await q('UPDATE users SET password_hash=@h WHERE id=@u', {'h': DBCrypt().hashpw(pw, DBCrypt().gensalt()), 'u': uid});
  await q('DELETE FROM security_attempts WHERE user_id=@u', {'u': uid});
  log('info', 'password_recovered', {'user': uid});
  return _json({'message': 'Password changed. Sign in with your new password.'});
}

// ---- Block and report
Future<Response> blockMember(Request r, String id) async {
  final uid = _uid(r);
  if (uid == id) throw _Http(400, 'You cannot block yourself.');
  try {
    await q('INSERT INTO blocks(blocker,blocked) VALUES(@u,@t) ON CONFLICT DO NOTHING', {'u': uid, 't': id});
  } on ServerException { throw _Http(404, 'Member not found.'); }
  await q("UPDATE interests SET status='rejected' WHERE status='sent' AND ((from_user=@u AND to_user=@t) OR (from_user=@t AND to_user=@u))", {'u': uid, 't': id});
  log('info', 'member_blocked', {'user': uid, 'target': id});
  return _json({'message': 'Member blocked. You will not see each other.'});
}

Future<Response> unblockMember(Request r, String id) async {
  await q('DELETE FROM blocks WHERE blocker=@u AND blocked=@t', {'u': _uid(r), 't': id});
  return _json({'message': 'Member unblocked.'});
}

Future<Response> listBlocks(Request r) async {
  final res = await q('SELECT p.user_id::text AS user_id, p.name FROM blocks b JOIN profiles p ON p.user_id=b.blocked WHERE b.blocker=@u', {'u': _uid(r)});
  return _json({'items': res.map((x) => x.toColumnMap()).toList()});
}

Future<Response> reportMember(Request r) async {
  final uid = _uid(r), b = await _body(r);
  final target = b['target'] as String? ?? '', reason = b['reason'] as String? ?? '', details = (b['details'] as String?)?.trim();
  if (!{'fake_profile', 'harassment', 'inappropriate_content', 'asking_for_money', 'other'}.contains(reason)) throw _Http(400, 'Choose a reason.');
  if (target == uid) throw _Http(400, 'You cannot report yourself.');
  if (details != null && details.length > 500) throw _Http(400, 'Details must be under 500 characters.');
  try {
    await q('INSERT INTO reports(reporter,target,reason,details) VALUES(@u,@t,@r,@d)', {'u': uid, 't': target, 'r': reason, 'd': (details == null || details.isEmpty) ? null : details});
  } on ServerException { throw _Http(404, 'Member not found.'); }
  log('info', 'member_reported', {'reporter': uid, 'target': target, 'reason': reason});
  return _json({'message': 'Thank you. Our team will review this report.'}, 201);
}

Future<Response> adminReports(Request r) async {
  await _admin(r);
  final res = await q('''SELECT r.id, r.reason, r.details, r.status, r.created_at::text AS created_at, r.target::text AS target_id,
      tp.name AS target_name, tu.email AS target_email, tu.status AS target_status,
      (SELECT count(*) FROM reports x WHERE x.target=r.target) AS report_count
    FROM reports r JOIN users tu ON tu.id=r.target LEFT JOIN profiles tp ON tp.user_id=r.target
    WHERE (@s::text IS NULL OR r.status=@s) ORDER BY r.id DESC LIMIT 100''', {'s': r.url.queryParameters['status']});
  return _json({'items': res.map((x) => x.toColumnMap()).toList()}); // reporter identity is deliberately not returned
}

Future<Response> adminResolveReport(Request r, String id) async {
  final admin = await _admin(r), act = (await _body(r))['action'], rid = int.tryParse(id);
  if (rid == null || !['dismiss', 'suspend'].contains(act)) throw _Http(400, 'Invalid request.');
  final res = await q("UPDATE reports SET status=@s, resolved_by=@a, resolved_at=now() WHERE id=@rid AND status='open' RETURNING target::text",
      {'s': act == 'suspend' ? 'actioned' : 'dismissed', 'a': admin, 'rid': rid});
  if (res.isEmpty) throw _Http(404, 'Open report not found.');
  final target = res.first[0] as String;
  if (act == 'suspend') {
    await q("UPDATE users SET status='suspended', status_reason='Reported for breaking our community rules.' WHERE id=@t AND role='member'", {'t': target});
    await q("INSERT INTO notifications(user_id,kind) VALUES(@t,'profile_suspended')", {'t': target});
  }
  await q('INSERT INTO audit_log(actor,action,target) VALUES(@u,@act,@t)', {'u': admin, 'act': 'report_$act', 't': target});
  log('info', 'admin_report', {'admin': admin, 'report': rid, 'action': act});
  return _json({'message': act == 'suspend' ? 'Member suspended.' : 'Report dismissed.'});
}

Future<void> main() async {
  final u = Uri.parse(env['DATABASE_URL'] ?? (throw 'DATABASE_URL missing'));
  final auth = u.userInfo.split(':');
  db = await Connection.open(Endpoint(host: u.host, port: u.hasPort ? u.port : 5432, database: u.path.substring(1),
      username: auth[0], password: auth.length > 1 ? Uri.decodeComponent(auth[1]) : null),
      settings: ConnectionSettings(sslMode: env['APP_ENV'] == 'production' ? SslMode.require : SslMode.disable));
  final router = Router()
    ..get('/health', (Request _) => _json({'status': 'ok'}))
    ..post('/auth/register', register)
    ..post('/auth/login', login)
    ..get('/auth/questions', (Request _) => _json({'questions': _secQuestions.keys.map(_q).toList()}))
    ..post('/auth/recover/questions', recoverQuestions)
    ..post('/auth/recover/reset', recoverReset)
    ..get('/members/<id>', memberProfile)
    ..post('/contact-requests/<id>', requestContact)
    ..get('/contact-requests', contactRequestsIncoming)
    ..post('/contact-requests/<id>/respond', respondContact)
    ..get('/public/search', publicSearch)
    ..get('/public/donate', publicDonate)
    ..get('/public/donate/qr', publicDonateQr)
    ..post('/admin/create-admin', createAdmin)
    ..post('/auth/change-password', changePassword)
    ..post('/auth/forgot', forgot)
    ..post('/auth/reset', resetPassword)
    ..get('/blocks', listBlocks)
    ..post('/blocks/<id>', blockMember)
    ..delete('/blocks/<id>', unblockMember)
    ..post('/reports', reportMember)
    ..get('/admin/reports', adminReports)
    ..post('/admin/reports/<id>/resolve', adminResolveReport)
    ..get('/profile', getProfile)
    ..put('/profile', putProfile)
    ..delete('/profile', deleteProfile)
    ..put('/photos/<id>', replacePhoto)
    ..get('/admin/users/<id>', adminUserDetail)
    ..delete('/admin/payment-settings', adminDeletePaymentSettings)
    ..delete('/admin/payment-settings/qr', adminDeleteQr)
    ..get('/search', search)
    ..post('/interests/<id>', sendInterest)
    ..post('/interests/<id>/respond', respond)
    ..put('/shortlist/<id>', (Request r, String id) => shortlist(r, id, true))
    ..delete('/shortlist/<id>', (Request r, String id) => shortlist(r, id, false))
    ..delete('/account', deleteAccount)
    ..get('/shortlist', myShortlist)
    ..get('/interests', inbox)
    ..get('/notifications', notifications)
    ..get('/photos', listPhotos)
    ..post('/photos', addPhoto)
    ..get('/photos/<id>', getPhoto)
    ..delete('/photos/<id>', deletePhoto)
    ..get('/payment-info', paymentInfo)
    ..get('/payment-info/qr', paymentQr)
    ..put('/admin/payment-settings', adminSavePaymentSettings)
    ..post('/admin/payment-settings/qr', adminUploadQr)
    ..post('/payments/razorpay/order', rzpOrder)
    ..post('/payments/razorpay/verify', rzpVerify)
    ..post('/webhooks/razorpay', rzpWebhook)
    ..post('/interests/<id>/married', reportMarried)
    ..get('/admin/marriages', adminMarriages)
    ..post('/admin/marriages/<id>/decide', adminDecideMarriage)
    ..get('/admin/insights', adminInsights)
    ..get('/admin/reports/members', adminMemberReport)
    ..post('/payments', addPayment)
    ..get('/payments/mine', myPayments)
    ..get('/admin/users', adminUsers)
    ..get('/chats/<id>/messages', getMessages)
    ..post('/chats/<id>/messages', sendMessage)
    ..post('/admin/users/<id>/status', adminSetStatus)
    ..get('/admin/payments', adminPayments)
    ..get('/admin/payments/<id>/screenshot', adminScreenshot)
    ..post('/admin/payments/<id>/verify', adminVerify);
  final handler = const Pipeline().addMiddleware(cors()).addMiddleware(logging()).addMiddleware(securityHeaders()).addMiddleware(rateLimit('auth/', 60, const Duration(minutes: 10))).addMiddleware(rateLimit('public/', 120, const Duration(minutes: 10))).addHandler(router.call);
  final port = int.parse(env['PORT'] ?? '8080');
  await io.serve(handler, InternetAddress.anyIPv4, port);
  log('info', 'server_started', {'port': port, 'env': env['APP_ENV']});
}
