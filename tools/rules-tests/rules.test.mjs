import { before, after, beforeEach, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, deleteDoc, serverTimestamp, Timestamp } from 'firebase/firestore';

let env;
const profile = () => ({
  fullName: 'Test Player', email: 'player@example.com', role: 'CUSTOMER',
  authProvider: 'LOCAL', createdAt: serverTimestamp(),
});
const own = () => doc(env.authenticatedContext('player', {email: 'player@example.com'}).firestore(), 'users/player');
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-courtly-sprint1',
    firestore: {host: '127.0.0.1', port: 8085, rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8')},
  });
});
beforeEach(async () => { await env.clearFirestore(); });
after(async () => { await env?.cleanup(); });
test('owner can create, read and edit allowed fields', async () => {
  await assertSucceeds(setDoc(own(), profile()));
  await assertSucceeds(getDoc(own()));
  await assertSucceeds(updateDoc(own(), {fullName: 'Updated Player', phone: '0901234567', avatarUrl: null}));
});
test('anonymous and other users cannot read or write profile', async () => {
  await setDoc(own(), profile());
  for (const db of [env.unauthenticatedContext().firestore(), env.authenticatedContext('other').firestore()]) {
    await assertFails(getDoc(doc(db, 'users/player')));
    await assertFails(setDoc(doc(db, 'users/player'), profile()));
  }
});
test('cannot create admin, extra fields, wrong email or forged time', async () => {
  for (const override of [{role:'ADMIN'}, {enabled:true}, {email:'other@example.com'}, {createdAt:Timestamp.fromMillis(0)}, {phone:123}]) {
    await assertFails(setDoc(own(), {...profile(), ...override}));
  }
});
test('cannot change protected fields, delete or add unknown fields', async () => {
  await setDoc(own(), profile());
  for (const change of [{role:'ADMIN'}, {email:'other@example.com'}, {authProvider:'GOOGLE'}, {createdAt:Timestamp.fromMillis(0)}, {enabled:true}, {fullName:42}]) {
    await assertFails(updateDoc(own(), change));
  }
  await assertFails(deleteDoc(own()));
});
test('business collections closed even to a client with an admin claim', async () => {
  const db = env.authenticatedContext('admin', {role:'ADMIN'}).firestore();
  for (const collection of ['venues','courts','bookings','payments','matches']) {
    await assertFails(setDoc(doc(db, collection, 'one'), {value:1}));
    await assertFails(getDoc(doc(db, collection, 'one')));
  }
});
