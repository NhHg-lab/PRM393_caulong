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

test('payments and matches collections closed even to a client with an admin claim', async () => {
  const db = env.authenticatedContext('admin', {role:'ADMIN'}).firestore();
  for (const collection of ['payments','matches']) {
    await assertFails(setDoc(doc(db, collection, 'one'), {value:1}));
    await assertFails(getDoc(doc(db, collection, 'one')));
  }
});

test('Sprint 2: user can read/write own favorites; other users cannot', async () => {
  const playerDb = env.authenticatedContext('player').firestore();
  const otherDb = env.authenticatedContext('other').firestore();
  const favRef = doc(playerDb, 'users/player/favorites/venue_1');
  
  await assertSucceeds(setDoc(favRef, {createdAt: serverTimestamp()}));
  await assertSucceeds(getDoc(favRef));
  await assertFails(getDoc(doc(otherDb, 'users/player/favorites/venue_1')));
  await assertFails(setDoc(doc(otherDb, 'users/player/favorites/venue_1'), {createdAt: serverTimestamp()}));
  await assertSucceeds(deleteDoc(favRef));
});

test('Sprint 2: authenticated user can read venues and courts; cannot write', async () => {
  const playerDb = env.authenticatedContext('player').firestore();
  await assertSucceeds(getDoc(doc(playerDb, 'venues/venue_1')));
  await assertFails(setDoc(doc(playerDb, 'venues/venue_1'), {name: 'New Venue'}));
  await assertSucceeds(getDoc(doc(playerDb, 'courts/court_1')));
  await assertFails(setDoc(doc(playerDb, 'courts/court_1'), {name: 'New Court'}));
});

test('Sprint 2: bookings lifecycle - create HOLD, view own, cancel; cannot forge confirmed or view others', async () => {
  const playerDb = env.authenticatedContext('player').firestore();
  const otherDb = env.authenticatedContext('other').firestore();
  const bookingRef = doc(playerDb, 'bookings/booking_1');

  // Valid HOLD booking creation
  const holdData = {
    userId: 'player',
    venueId: 'venue_1',
    status: 'HOLD',
    createdAt: serverTimestamp(),
  };
  await assertSucceeds(setDoc(bookingRef, holdData));

  // Cannot create with CONFIRMED directly
  await assertFails(setDoc(doc(playerDb, 'bookings/booking_fake'), {
    ...holdData,
    status: 'CONFIRMED',
  }));

  // Cannot create for someone else
  await assertFails(setDoc(doc(playerDb, 'bookings/booking_imposter'), {
    ...holdData,
    userId: 'other',
  }));

  // Player can read own booking; other cannot
  await assertSucceeds(getDoc(bookingRef));
  await assertFails(getDoc(doc(otherDb, 'bookings/booking_1')));

  // Owner can cancel own booking
  await assertSucceeds(updateDoc(bookingRef, {status: 'CANCELLED'}));

  // Cannot modify other fields or delete
  await assertFails(updateDoc(bookingRef, {venueId: 'venue_hack'}));
  await assertFails(deleteDoc(bookingRef));
});
