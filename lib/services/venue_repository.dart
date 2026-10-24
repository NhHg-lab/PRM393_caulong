import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../config/app_config.dart';
import '../models/venue_model.dart';

abstract class VenueRepository {
  Future<List<VenueModel>> getVenues();
  Future<VenueModel?> getVenue(String id);
  Future<List<CourtModel>> getCourts(String venueId);
  Future<bool> isFavorite(String userId, String venueId);
  Future<void> toggleFavorite(String userId, String venueId, bool isFavorite);
  Stream<Set<String>> watchFavorites(String userId);

  factory VenueRepository.instance({FirebaseFirestore? firestore}) {
    if (AppConfig.authMode == AuthMode.firebase && (firestore != null || Firebase.apps.isNotEmpty)) {
      return FirestoreVenueRepository(firestore: firestore);
    }
    return DemoVenueRepository();
  }
}

class DemoVenueRepository implements VenueRepository {
  DemoVenueRepository() {
    _initSeed();
  }

  final List<VenueModel> _venues = [];
  final Map<String, Set<String>> _userFavorites = {};
  final _favoritesStreamController = StreamController<Set<String>>.broadcast();

  void _initSeed() {
    _venues.addAll(const [
      VenueModel(
        id: '0',
        name: 'SkyBadminton Club',
        address: '152 Nguyễn Thị Thập, P. Bình Thuận, Quận 7',
        district: 'Quận 7',
        price: 90000,
        rating: 4.9,
        tags: ['Máy lạnh', 'Thảm BWF', 'Bãi đỗ ô tô'],
        courtCount: 6,
      ),
      VenueModel(
        id: '1',
        name: 'Victory Arena',
        address: '340 Hoàng Văn Thụ, Tân Bình',
        district: 'Tân Bình',
        price: 100000,
        rating: 4.8,
        tags: ['Thảm BWF', 'Bãi đỗ ô tô', 'Mở 24/7'],
        courtCount: 8,
      ),
      VenueModel(
        id: '2',
        name: 'CLB Cầu Lông Victor Pro',
        address: 'Đường số 7, Tân Phong, Quận 7',
        district: 'Quận 7',
        price: 80000,
        rating: 4.7,
        tags: ['Máy lạnh', 'Thảm BWF'],
        courtCount: 4,
      ),
    ]);
  }

  @override
  Future<List<VenueModel>> getVenues() async {
    return List.unmodifiable(_venues);
  }

  @override
  Future<VenueModel?> getVenue(String id) async {
    try {
      return _venues.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<CourtModel>> getCourts(String venueId) async {
    final venue = await getVenue(venueId);
    final count = venue?.courtCount ?? 4;
    return List.generate(
      count,
      (i) => CourtModel(
        id: '${venueId}_${i + 1}',
        venueId: venueId,
        courtNumber: i + 1,
        name: 'Sân ${i + 1}',
        basePrice: venue?.price ?? 90000,
        peakPrice: (venue?.price ?? 90000) + 30000,
      ),
    );
  }

  @override
  Future<bool> isFavorite(String userId, String venueId) async {
    return _userFavorites[userId]?.contains(venueId) ?? false;
  }

  @override
  Future<void> toggleFavorite(String userId, String venueId, bool isFavorite) async {
    final set = _userFavorites.putIfAbsent(userId, () => <String>{});
    if (isFavorite) {
      set.add(venueId);
    } else {
      set.remove(venueId);
    }
    _favoritesStreamController.add(Set.unmodifiable(set));
  }

  @override
  Stream<Set<String>> watchFavorites(String userId) {
    return _favoritesStreamController.stream;
  }
}

class FirestoreVenueRepository implements VenueRepository {
  FirestoreVenueRepository({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  static const venuesCollection = 'venues';
  static const courtsCollection = 'courts';
  static const usersCollection = 'users';
  static const favoritesSubcollection = 'favorites';

  final DemoVenueRepository _fallback = DemoVenueRepository();

  @override
  Future<List<VenueModel>> getVenues() async {
    try {
      final snapshot = await _db.collection(venuesCollection).where('active', isEqualTo: true).get();
      if (snapshot.docs.isEmpty) {
        return await _fallback.getVenues();
      }
      return snapshot.docs.map((doc) => VenueModel.fromJson(doc.data(), id: doc.id)).toList();
    } catch (_) {
      return _fallback.getVenues();
    }
  }

  @override
  Future<VenueModel?> getVenue(String id) async {
    try {
      final doc = await _db.collection(venuesCollection).doc(id).get();
      if (!doc.exists) {
        return await _fallback.getVenue(id);
      }
      return VenueModel.fromJson(doc.data()!, id: doc.id);
    } catch (_) {
      return _fallback.getVenue(id);
    }
  }

  @override
  Future<List<CourtModel>> getCourts(String venueId) async {
    try {
      final snapshot = await _db
          .collection(courtsCollection)
          .where('venueId', isEqualTo: venueId)
          .where('active', isEqualTo: true)
          .get();
      if (snapshot.docs.isEmpty) {
        return await _fallback.getCourts(venueId);
      }
      return snapshot.docs.map((doc) => CourtModel.fromJson(doc.data(), id: doc.id)).toList();
    } catch (_) {
      return _fallback.getCourts(venueId);
    }
  }

  @override
  Future<bool> isFavorite(String userId, String venueId) async {
    try {
      final doc = await _db
          .collection(usersCollection)
          .doc(userId)
          .collection(favoritesSubcollection)
          .doc(venueId)
          .get();
      return doc.exists;
    } catch (_) {
      return _fallback.isFavorite(userId, venueId);
    }
  }

  @override
  Future<void> toggleFavorite(String userId, String venueId, bool isFavorite) async {
    try {
      final ref = _db
          .collection(usersCollection)
          .doc(userId)
          .collection(favoritesSubcollection)
          .doc(venueId);
      if (isFavorite) {
        await ref.set({'createdAt': FieldValue.serverTimestamp()});
      } else {
        await ref.delete();
      }
    } catch (_) {
      await _fallback.toggleFavorite(userId, venueId, isFavorite);
    }
  }

  @override
  Stream<Set<String>> watchFavorites(String userId) {
    try {
      return _db
          .collection(usersCollection)
          .doc(userId)
          .collection(favoritesSubcollection)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((d) => d.id).toSet());
    } catch (_) {
      return _fallback.watchFavorites(userId);
    }
  }
}
