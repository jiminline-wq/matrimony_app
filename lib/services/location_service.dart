import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'dart:async';

// ============================================================
// LOCATION SERVICE
// User এর GPS location save + distance calculate
// ============================================================

class LocationService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ============================================================
  // CHECK PERMISSION
  // ============================================================
  static Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // ============================================================
  // REQUEST PERMISSION
  // ============================================================
  static Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('❌ Location service off');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      debugPrint('❌ Permission denied');
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('❌ Permission denied forever');
      return false;
    }

    return true;
  }

  // ============================================================
  // GET CURRENT POSITION (with fallback)
  // ============================================================
  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPerm = await hasPermission();
      if (!hasPerm) {
        final granted = await requestPermission();
        if (!granted) return null;
      }

      // ১. Try last known position (fastest)
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          final age = DateTime.now().difference(lastKnown.timestamp).inMinutes;
          if (age < 10) {
            debugPrint('✅ Using last known position (age: ${age}m)');
            return lastKnown;
          }
        }
      } catch (_) {}

      // ২. Try current position with timeout
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 20),
        );
        debugPrint('✅ Got fresh GPS position');
        return position;
      } on TimeoutException {
        debugPrint('⚠️ GPS timeout, trying last known...');
      }

      // ৩. Fallback: last known (any age)
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          debugPrint('✅ Fallback to last known position');
          return lastKnown;
        }
      } catch (_) {}

      // ৪. Final fallback: getCurrentPosition without timeLimit
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
        );
        debugPrint('✅ Got low accuracy position');
        return position;
      } catch (e) {
        debugPrint('❌ All position attempts failed: $e');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Get position failed: $e');
      return null;
    }
  }

  // ============================================================
  // SAVE LOCATION TO FIRESTORE
  // ============================================================
  static Future<bool> saveLocationToFirestore() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      final position = await getCurrentPosition();
      if (position == null) return false;

      // Approximate location for privacy (round to 3 decimals ~ 100m accuracy)
      final lat = double.parse(position.latitude.toStringAsFixed(3));
      final lng = double.parse(position.longitude.toStringAsFixed(3));

      await _firestore.collection('users').doc(uid).set({
        'location': {'lat': lat, 'lng': lng},
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Location saved: $lat, $lng');
      return true;
    } catch (e) {
      debugPrint('❌ Save location failed: $e');
      return false;
    }
  }

  // ============================================================
  // CALCULATE DISTANCE (in km)
  // ============================================================
  static double? calculateDistance(
    double? myLat,
    double? myLng,
    double? theirLat,
    double? theirLng,
  ) {
    if (myLat == null || myLng == null) return null;
    if (theirLat == null || theirLng == null) return null;

    final meters = Geolocator.distanceBetween(myLat, myLng, theirLat, theirLng);

    return meters / 1000; // convert to km
  }

  // ============================================================
  // FORMAT DISTANCE FOR DISPLAY
  // ============================================================
  static String formatDistance(double? km, bool isBangla) {
    if (km == null) return '';

    if (km < 1) {
      final meters = (km * 1000).round();
      return isBangla ? '$meters মিটার দূরে' : '$meters m away';
    }

    if (km < 10) {
      return isBangla
          ? '${km.toStringAsFixed(1)} কিমি দূরে'
          : '${km.toStringAsFixed(1)} km away';
    }

    return isBangla
        ? '${km.toStringAsFixed(0)} কিমি দূরে'
        : '${km.toStringAsFixed(0)} km away';
  }
}
