//
//  AuthViewModel.swift
//  BPA-MobileApps
//
//  Created by Krish Bothra on 12/30/23.
//

import Foundation
import Firebase
import FirebaseFirestoreSwift

protocol AuthenticationFormProtocol {
    var formIsValid: Bool { get }
}



@MainActor
class AuthViewModel: ObservableObject{
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    @Published var events: [Event] = []

    
    init() {
        self.userSession = Auth.auth().currentUser
        
        Task {
            await fetchUser()
        }
        
    }
    
    func signIn(withEmail email: String , password: String) async throws {
        do{
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = result.user
            await fetchUser()
        } catch {
            print("DEBUG: failed to login with error \(error.localizedDescription)")
        }
    }
    
    func createUser(withEmail email: String , password: String, fullname: String) async throws {
        do{
            let result =  try await Auth.auth().createUser(withEmail: email, password: password)
            self.userSession = result.user
            let user = User(id: result.user.uid, fullname: fullname, email: email)
            let encodedUser = try Firestore.Encoder().encode(user)
            try await Firestore.firestore().collection("users").document(user.id).setData(encodedUser)
            await fetchUser()
        } catch{
            print("DEBUG: Failed to create user with error \(error.localizedDescription)")
        }
    }
    func signOut(){
        do{
            try Auth.auth().signOut()
            self.userSession = nil
            self.currentUser = nil
        } catch {
            print("DEBUG: Failed to sign out with error \(error.localizedDescription)")
        }
    }
    
    func saveEvent(event: Event){
        guard let userId = currentUser?.id else { return }
        let db = Firestore.firestore()
        do {
            let eventData = try Firestore.Encoder().encode(event)
            // Add a new document to the "events" collection
            try db.collection("events").addDocument(data: eventData)
        } catch {
            print("Error saving event: \(error.localizedDescription)")
        }
    }
    
    func fetchUser() async{
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let snapshot = try? await Firestore.firestore().collection("users").document(uid).getDocument() else { return }
        self.currentUser = try? snapshot.data(as: User.self)
    }
    
    
    func fetchData() {
            let db = Firestore.firestore()
            db.collection("events").getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting documents: \(error)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("No documents")
                    return
                }

                self.events = documents.compactMap { document in
                    do {
                        let event = try Firestore.Decoder().decode(Event.self, from: document.data())
                        return event
                    } catch {
                        print("Error decoding document: \(error)")
                        return nil
                    }
                }
            }
        }

}
