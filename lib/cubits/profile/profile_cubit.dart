import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';
import 'package:spot/models/profile.dart';
import 'package:spot/repositories/repository.dart';

part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required Repository repository,
  })   : _repository = repository,
        super(ProfileLoading());

  final Repository _repository;
  Profile? _profile;

  StreamSubscription<Map<String, Profile>>? _subscription;

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  Future<void> loadProfile(String uid) async {
    try {
      await _repository.getProfile(uid);
      _subscription = _repository.profileStream.listen((profiles) {
        _profile = profiles[uid];
        if (_profile == null) {
          emit(ProfileNotFound());
        } else {
          emit(ProfileLoaded(_profile!));
        }
      });
    } catch (err) {
      emit(ProfileError());
    }
  }

  Future<void> saveProfile({
    required String name,
    required String description,
    required File? imageFile,
  }) async {
    try {
      final userId = _repository.userId;
      if (userId == null) {
        throw PlatformException(
          code: 'Auth_Error',
          message: 'Session has expired',
        );
      }
      emit(ProfileLoading());
      String? imageUrl;
      if (imageFile != null) {
        final imagePath =
            '$userId/profile${DateTime.now().millisecondsSinceEpoch}.${imageFile.path.split('.').last}';
        imageUrl = await _repository.uploadFile(
          bucket: 'profiles',
          file: imageFile,
          path: imagePath,
        );
      }

      return _repository.saveProfile(
        map: Profile.toMap(
          id: userId,
          name: name,
          description: description,
          imageUrl: imageUrl,
        ),
        userId: userId,
      );
    } catch (err) {
      emit(ProfileError());
      rethrow;
    }
  }
}
