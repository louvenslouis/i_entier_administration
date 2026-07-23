import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/provider_application.dart';

abstract class AdminRepository {
  Stream<bool> watchAccess(String uid);

  Stream<List<ProviderApplication>> watchApplications();

  Future<void> reviewApplication({
    required ProviderApplication application,
    required String adminUid,
    required ApplicationStatus status,
    String reason = '',
  });
}

class FirestoreAdminRepository implements AdminRepository {
  final FirebaseFirestore firestore;

  FirestoreAdminRepository({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<bool> watchAccess(String uid) => firestore
      .collection('administrators')
      .doc(uid)
      .snapshots()
      .map((document) => document.exists && document.data()?['active'] == true);

  @override
  Stream<List<ProviderApplication>> watchApplications() => firestore
      .collection('providerProfiles')
      .orderBy('updatedAt', descending: true)
      .limit(250)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(ProviderApplication.fromFirestore)
            .toList(growable: false),
      );

  @override
  Future<void> reviewApplication({
    required ProviderApplication application,
    required String adminUid,
    required ApplicationStatus status,
    String reason = '',
  }) async {
    if (status == ApplicationStatus.pending) {
      throw ArgumentError('Une décision finale est requise.');
    }
    final normalizedReason = status == ApplicationStatus.rejected
        ? reason.trim()
        : '';
    if (status == ApplicationStatus.rejected && normalizedReason.isEmpty) {
      throw ArgumentError('Un motif de refus est requis.');
    }

    final profile = firestore
        .collection('providerProfiles')
        .doc(application.id);
    final directory = firestore
        .collection(
          application.type == ApplicationType.professional
              ? 'personnelMedical'
              : 'institution',
        )
        .doc(application.id);
    final review = firestore.collection('providerReviews').doc();
    await firestore.runTransaction((transaction) async {
      final profileSnapshot = await transaction.get(profile);
      if (!profileSnapshot.exists) {
        throw StateError('Le dossier professionnel n’existe plus.');
      }
      final directorySnapshot = await transaction.get(directory);
      final previousStatus = ApplicationStatusText.fromStorage(
        profileSnapshot.data()?['verificationStatus']?.toString(),
      );
      if (previousStatus == status) {
        throw StateError('Cette décision est déjà appliquée.');
      }

      transaction.update(profile, {
        'verificationStatus': status.storageValue,
        'rejectionReason': normalizedReason,
        'isVisible': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(review, {
        'profileId': application.id,
        'adminUid': adminUid,
        'previousStatus': previousStatus.storageValue,
        'newStatus': status.storageValue,
        'reason': normalizedReason,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (directorySnapshot.exists) transaction.delete(directory);
    });
  }
}
