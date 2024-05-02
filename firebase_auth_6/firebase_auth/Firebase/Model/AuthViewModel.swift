//  AuthViewModel.swift
//  firebase_auth
//  Created by Rupaj Sen on 24/04/24.

import Foundation
import Firebase
import FirebaseFirestore

enum UserType: String, Codable {
    case patient = "Patient"
    case doctor = "Doctor"
    case admin = "Admin"
}

enum Gender: String, Codable {
    case male
    case female
}

struct User: Identifiable, Codable {
    var id: String
    var fullname: String
    var email: String
    var userType: UserType
    var dob: Date?
    var gender: Gender? // Add the gender property
}

protocol AuthenticationFormProtocol {
    var formIsValid: Bool { get }
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    
    init() {
        self.userSession = Auth.auth().currentUser
        
        Task {
            await fetchUser()
        }
    }
    
    /*
     func signIn(withEmail email: String, password: String, userType: UserType) async throws {
     do {
     let result = try await Auth.auth().signIn(withEmail: email, password: password)
     self.userSession = result.user
     await fetchUser()
     
     // Check if the fetched user's userType matches the desired userType
     if let currentUser = self.currentUser, currentUser.userType == userType {
     // If both email, password, and userType match, login is successful
     print("Login successful")
     } else {
     // If userType doesn't match, sign out the user and throw an error
     try await Auth.auth().signOut()
     self.userSession = nil
     throw NSError(domain: "AuthViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "User is not of the desired type."])
     }
     } catch {
     print("Failed to log in with error \(error.localizedDescription)")
     throw error
     }
     }*/
    
    func signIn(withEmail email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = result.user
            await fetchUser()
        } catch {
            print("Failed to log in with error \(error.localizedDescription)")
            throw error
        }
    }
    
    
        func createUser(withEmail email: String, password: String, fullname: String, userType: UserType) async throws -> User {
            do {
                let result = try await Auth.auth().createUser(withEmail: email, password: password)
                self.userSession = result.user
                let user = User(id: result.user.uid, fullname: fullname, email: email, userType: userType)
                let encodedUser = try Firestore.Encoder().encode(user)
                try await Firestore.firestore().collection("users").document(user.id).setData(encodedUser)
                await fetchUser()
                return user
            } catch {
                print("Failed to create user with error \(error.localizedDescription)")
                throw error
            }
        }
    
    func fetchUserSynchronously() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }
            if let userData = try? snapshot?.data(as: User.self) {
                self.currentUser = userData
            } else {
                print("User data not available")
            }
        }
    }

    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            self.currentUser = nil
        } catch {
            print("Failed to sign out error : \(error.localizedDescription)")
        }
    }
    
    func deleteAccount() {}
    
    func fetchUser() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let snapshot = try? await Firestore.firestore().collection("users").document(uid).getDocument() else { return }
        self.currentUser = try? snapshot.data(as: User.self)
    }
}

