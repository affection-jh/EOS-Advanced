import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
// ignore: library_prefixes
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as Kakao;
import 'package:provider/provider.dart';
import 'package:week02/service/user_service.dart';

class AuthService {
  Future<User?> signInWithKakao(BuildContext context) async {
    late Kakao.OAuthToken token;
    try {
      token = await (await Kakao.isKakaoTalkInstalled()
          ? Kakao.UserApi.instance.loginWithKakaoTalk()
          : Kakao.UserApi.instance.loginWithKakaoAccount());

      // Firebase
      Kakao.User kakaoUser = await Kakao.UserApi.instance.me();
      var provider = OAuthProvider("oidc.kakao");
      var credential = provider.credential(
        idToken: token.idToken,
        accessToken: token.accessToken,
      );
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      //사용자 이름 설정
      await userCredential.user?.updateProfile(
          displayName: kakaoUser.kakaoAccount?.profile?.nickname ?? "user");

      await userCredential.user?.reload();
      User? user = FirebaseAuth.instance.currentUser;
      context.read<UserService>().user = user;
      print("user : ${context.read<UserService>().user?.displayName}");

      /*
      //Firestore 등록
      final userService = context.read<UserService>();

      //기존 사용자정보에 없으면 등록
      print("!!!!!!!!!!!!!!!!!!!!${userCredential.user!.uid}");
      if (!await userService.checkUserExists(userCredential.user!.uid)) {
        userService.loginWith = 'KaKao';
        userService.userName = userCredential.user?.displayName;
        if (!await userService.enrollUserToServer()) {
          return null;
        }
      }
*/

      print('카카오 로그인 성공');
      return user;
    } on Kakao.KakaoAuthException catch (e) {
      print('카카오 인증 실패: ${e.message}');
    } on FirebaseAuthException catch (e) {
      print('파이어베이스 인증 실패: ${e.message}');
    } catch (e) {
      print('알 수 없는 오류: $e');
    }
    return null;
  }

//구글로그인
  Future<User?> signInWithGoogle(BuildContext context) async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    try {
      // Google 로그인 시도
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        print('Google 로그인 취소됨');
        return null;
      }
      // Google 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      // Firebase
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
/*
      //Firestore 등록
      final userService = context.read<UserService>();

      //기존 사용자정보에 없으면 등록//////////->shared preference변경

      if (!await userService.checkUserExists(userCredential.user!.uid)) {
        userService.loginWith = 'Google';
        userService.userName = userCredential.user?.displayName;
        if (!await userService.enrollUserToServer()) {
          return null;
        }
      }
  */

      print('Google 로그인 성공: ${userCredential.user?.email}');
      return userCredential.user;
    } catch (error) {
      print('Google 로그인 실패: $error');
      return null;
    }
  }

  Future<void> logout() async {
    final GoogleSignIn _googleSignIn = GoogleSignIn();

    var currentUser = FirebaseAuth.instance.currentUser;
    var providers =
        currentUser?.providerData.map((info) => info.providerId).toList() ?? [];
    //카카오 로그아웃
    if (providers.contains("oidc.kakao")) {
      try {
        await Kakao.UserApi.instance.logout();
        print('카카오 로그아웃 성공');
      } catch (e) {
        print('카카오 로그아웃 실패: $e');
      }
    }
    // Google 로그아웃
    else if (providers.contains('google.com')) {
      try {
        await _googleSignIn.signOut();
        print('Google 로그아웃 성공');
      } catch (e) {
        print('Google 로그아웃 실패$e');
      }
    }

    // Firebase 로그아웃
    try {
      await FirebaseAuth.instance.signOut();
      print('Firebase 로그아웃 성공');
    } catch (e) {
      print('Firebase 로그아웃 실패: $e');
    }
  }
}
