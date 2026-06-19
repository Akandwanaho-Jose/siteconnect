import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import admin from 'firebase-admin';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '../..');

const roles = new Map([
  ['administrator', 'Administrator'],
  ['project_manager', 'Project Manager'],
  ['site_engineer', 'Site Engineer'],
  ['contractor', 'Contractor'],
  ['consultant', 'Consultant'],
  ['clerk_of_works', 'Clerk of Works'],
  ['district_engineer', 'District Engineer'],
  ['procurement_officer', 'Procurement Officer'],
  ['community_representative', 'Community Representative'],
  ['environment_officer', 'Environment Officer'],
  ['community_development_officer', 'Community Development Officer (CDO)'],
]);

const command = process.argv[2] || 'help';
const args = parseArgs(process.argv.slice(3));

async function main() {
  if (command === 'help' || args.help) {
    printHelp();
    return;
  }

  initializeFirebaseAdmin();

  switch (command) {
    case 'list':
      await listUsers();
      break;
    case 'create':
      await createUser();
      break;
    case 'update-email':
      await updateEmailCommand();
      break;
    case 'update-role':
      await updateRoleCommand();
      break;
    case 'apply-email-map':
      await applyEmailMap();
      break;
    default:
      throw new Error(`Unknown command: ${command}. Run npm run users:help.`);
  }
}

function initializeFirebaseAdmin() {
  if (admin.apps.length > 0) {
    return;
  }

  const explicitJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  const explicitFile =
    process.env.FIREBASE_SERVICE_ACCOUNT_FILE ||
    process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const projectId =
    process.env.FIREBASE_PROJECT_ID || readProjectIdFromFirebaseJson();

  if (explicitJson) {
    const serviceAccount = JSON.parse(explicitJson);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: projectId || serviceAccount.project_id,
    });
    return;
  }

  if (explicitFile) {
    const serviceAccountPath = path.resolve(rootDir, explicitFile);
    if (!existsSync(serviceAccountPath)) {
      throw new Error(
        `Service account file not found: ${serviceAccountPath}. ` +
          'Set FIREBASE_SERVICE_ACCOUNT_FILE to an existing ignored JSON file.',
      );
    }

    const serviceAccount = JSON.parse(
      readFileSync(serviceAccountPath, 'utf8'),
    );
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: projectId || serviceAccount.project_id,
    });
    return;
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId,
  });
}

function readProjectIdFromFirebaseJson() {
  const firebaseJsonPath = path.join(rootDir, 'firebase.json');
  if (!existsSync(firebaseJsonPath)) {
    return undefined;
  }

  const firebaseJson = JSON.parse(readFileSync(firebaseJsonPath, 'utf8'));
  return firebaseJson?.flutter?.platforms?.android?.default?.projectId;
}

async function listUsers() {
  const db = admin.firestore();
  const authUsers = await listAllAuthUsers();

  const rows = [];
  for (const user of authUsers) {
    const profileSnapshot = await db.collection('users').doc(user.uid).get();
    const profile = profileSnapshot.data() || {};

    rows.push({
      email: user.email || '',
      uid: user.uid,
      name: profile.fullName || user.displayName || '',
      role: profile.role || '(missing profile)',
      district: profile.district || '',
    });
  }

  rows.sort((left, right) => left.email.localeCompare(right.email));
  console.table(rows);
}

async function createUser() {
  const email = normalizeEmail(requiredArg('email'));
  const password = requiredArg('password');
  const fullName = requiredArg('name');
  const role = normalizeRole(requiredArg('role'));
  const district = requiredArg('district');
  const phoneNumber = args.phone || '';
  const createdBy = await resolveCreatedBy();

  if (password.length < 6) {
    throw new Error('Password must be at least 6 characters.');
  }

  let authUser;
  try {
    authUser = await admin.auth().createUser({
      email,
      password,
      displayName: fullName,
      emailVerified: false,
      disabled: false,
    });
  } catch (error) {
    throw mapAuthError(error);
  }

  try {
    const now = admin.firestore.Timestamp.now();
    await admin.firestore().collection('users').doc(authUser.uid).set({
      uid: authUser.uid,
      fullName,
      email,
      role,
      phoneNumber,
      district,
      profileImage: null,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      createdBy,
    });

    console.log(`Created ${email} as ${roleLabel(role)}.`);
    console.log(`UID: ${authUser.uid}`);
  } catch (error) {
    await admin.auth().deleteUser(authUser.uid).catch(() => {});
    throw error;
  }
}

async function updateEmailCommand() {
  const user = await resolveAuthUser();
  const toEmail = normalizeEmail(requiredArg('to'));

  await updateUserEmail({ uid: user.uid, fromEmail: user.email, toEmail });
}

async function applyEmailMap() {
  const file = requiredArg('file');
  const filePath = path.resolve(rootDir, file);
  if (!existsSync(filePath)) {
    throw new Error(`Email map file not found: ${filePath}`);
  }

  const mappings = JSON.parse(readFileSync(filePath, 'utf8'));
  if (!Array.isArray(mappings)) {
    throw new Error('Email map must be a JSON array.');
  }

  for (const mapping of mappings) {
    const user = await resolveAuthUser({
      uid: mapping.uid,
      email: mapping.from || mapping.fromEmail || mapping.email,
    });
    const toEmail = normalizeEmail(mapping.to || mapping.toEmail);
    await updateUserEmail({
      uid: user.uid,
      fromEmail: user.email,
      toEmail,
    });
  }
}

async function updateRoleCommand() {
  const user = await resolveAuthUser();
  const role = normalizeRole(requiredArg('role'));
  const userRef = admin.firestore().collection('users').doc(user.uid);
  const snapshot = await userRef.get();

  if (!snapshot.exists) {
    throw new Error(
      `Firestore profile missing for ${user.email}. Create the profile first.`,
    );
  }

  await userRef.set(
    {
      role,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  console.log(`Updated ${user.email} role to ${roleLabel(role)}.`);
}

async function updateUserEmail({ uid, fromEmail, toEmail }) {
  const existingTargetUser = await findAuthUserByEmail(toEmail);
  if (existingTargetUser && existingTargetUser.uid !== uid) {
    throw new Error(`${toEmail} is already used by another Firebase Auth user.`);
  }

  const profileRef = admin.firestore().collection('users').doc(uid);
  const profileSnapshot = await profileRef.get();
  if (!profileSnapshot.exists) {
    throw new Error(
      `Firestore profile missing for ${fromEmail || uid}. ` +
        'Create the profile before changing email.',
    );
  }

  await admin.auth().updateUser(uid, {
    email: toEmail,
    emailVerified: false,
  });

  await profileRef.set(
    {
      email: toEmail,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  console.log(`${fromEmail || uid} -> ${toEmail}`);
}

async function resolveCreatedBy() {
  const explicitUid = args['created-by'] || process.env.SEED_ADMIN_UID;
  if (explicitUid) {
    return explicitUid.trim();
  }

  const explicitEmail =
    args['created-by-email'] || process.env.SEED_ADMIN_EMAIL;
  if (explicitEmail) {
    const adminUser = await admin.auth().getUserByEmail(
      normalizeEmail(explicitEmail),
    );
    return adminUser.uid;
  }

  return 'local-admin-script';
}

async function resolveAuthUser(overrides = {}) {
  const uid = overrides.uid || args.uid;
  if (uid) {
    return admin.auth().getUser(uid.trim());
  }

  const email =
    overrides.email ||
    args.email ||
    args.from ||
    args['from-email'] ||
    args.current ||
    args['current-email'];

  if (!email) {
    throw new Error('Set --uid, --email, or --from for the target user.');
  }

  return admin.auth().getUserByEmail(normalizeEmail(email));
}

async function findAuthUserByEmail(email) {
  try {
    return await admin.auth().getUserByEmail(email);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      return null;
    }

    throw error;
  }
}

async function listAllAuthUsers() {
  const users = [];
  let pageToken;

  do {
    const result = await admin.auth().listUsers(1000, pageToken);
    users.push(...result.users);
    pageToken = result.pageToken;
  } while (pageToken);

  return users;
}

function parseArgs(values) {
  const parsed = {};

  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];
    if (!value.startsWith('--')) {
      continue;
    }

    const rawKey = value.slice(2);
    const equalsIndex = rawKey.indexOf('=');

    if (equalsIndex >= 0) {
      parsed[rawKey.slice(0, equalsIndex)] = rawKey.slice(equalsIndex + 1);
      continue;
    }

    const nextValue = values[index + 1];
    if (nextValue && !nextValue.startsWith('--')) {
      parsed[rawKey] = nextValue;
      index += 1;
      continue;
    }

    parsed[rawKey] = true;
  }

  return parsed;
}

function requiredArg(name) {
  const value = args[name];
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new Error(`Missing required --${name}.`);
  }

  return value.trim();
}

function normalizeEmail(email) {
  if (typeof email !== 'string') {
    throw new Error('Email is required.');
  }

  const normalized = email.trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized)) {
    throw new Error(`Invalid email address: ${email}`);
  }

  return normalized;
}

function normalizeRole(role) {
  const normalized = role
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '');

  if (!roles.has(normalized)) {
    throw new Error(
      `Invalid role: ${role}. Valid roles: ${[...roles.keys()].join(', ')}`,
    );
  }

  return normalized;
}

function roleLabel(role) {
  return roles.get(role) || role;
}

function mapAuthError(error) {
  switch (error.code) {
    case 'auth/email-already-exists':
      return new Error('An account already exists for this email address.');
    case 'auth/invalid-email':
      return new Error('Enter a valid email address.');
    case 'auth/invalid-password':
      return new Error('Use a stronger password.');
    default:
      return error;
  }
}

function printHelp() {
  console.log(`
SiteConnect local user admin tool

Required env:
  FIREBASE_SERVICE_ACCOUNT_FILE=tools/seed/credentials/service-account.json

Commands:
  npm run users:list

  npm run users:create -- \\
    --email jane@example.com \\
    --password TempPass123 \\
    --name "Jane Nalwoga" \\
    --role site_engineer \\
    --district Kampala

  npm run users:update-email -- \\
    --from siteconnect.site-engineer@siteconnect.test \\
    --to jane@example.com

  npm run users:update-role -- \\
    --email jane@example.com \\
    --role project_manager

  npm run users:apply-email-map -- \\
    --file tools/admin/email-map.example.json
`);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
