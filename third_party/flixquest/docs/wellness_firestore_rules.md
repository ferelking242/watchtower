# Viewing Insights Firestore rules

FlixQuest stores registered-user Viewing Insights sync data under
`wellness-v1/{firebaseUid}/sessions` and `wellness-v1/{firebaseUid}/daily`.
Merge the following match block into the deployed Firestore rules. The project
does not keep its environment-level Firebase configuration in this repository,
so this snippet is intentionally not an independently deployable ruleset.

```text
match /wellness-v1/{userId} {
  allow read, write: if request.auth != null
    && request.auth.uid == userId
    && request.auth.token.firebase.sign_in_provider != 'anonymous';

  match /{document=**} {
    allow read, write: if request.auth != null
      && request.auth.uid == userId
      && request.auth.token.firebase.sign_in_provider != 'anonymous';
  }
}
```

The client uses document IDs for session upserts and performs no compound
Firestore queries, so no additional Firestore index is required.
