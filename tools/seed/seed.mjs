import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import admin from 'firebase-admin';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '../..');

const isCheckMode = process.argv.includes('--check');
const seedTimestamp = () => admin.firestore.Timestamp.now();
const defaultTestUserPassword = 'SiteConnect@12345';

const collections = {
  roles: 'roles',
  systemSettings: 'system_settings',
  users: 'users',
  projects: 'projects',
  projectMembers: 'project_members',
};

const userRoles = [
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
];

const testUserProfiles = [
  ['administrator', 'SiteConnect Test Administrator', 'Kampala'],
  ['project_manager', 'SiteConnect Test Project Manager', 'Kampala'],
  ['site_engineer', 'SiteConnect Test Site Engineer', 'Kampala'],
  ['contractor', 'SiteConnect Test Contractor', 'Kampala'],
  ['consultant', 'SiteConnect Test Consultant', 'Kampala'],
  ['clerk_of_works', 'SiteConnect Test Clerk of Works', 'Kampala'],
  ['district_engineer', 'SiteConnect Test District Engineer', 'Kampala'],
  ['procurement_officer', 'SiteConnect Test Procurement Officer', 'Kampala'],
  [
    'community_representative',
    'SiteConnect Test Community Representative',
    'Kampala',
  ],
  ['environment_officer', 'SiteConnect Test Environment Officer', 'Kampala'],
  [
    'community_development_officer',
    'SiteConnect Test Community Development Officer',
    'Kampala',
  ],
];

async function main() {
  initializeFirebaseAdmin();

  const db = admin.firestore();
  const adminUser = await resolveSeedAdminUser();
  const now = seedTimestamp();

  console.log(
    `${isCheckMode ? 'Checking' : 'Seeding'} SiteConnect Uganda Firestore data`,
  );
  console.log(`Project: ${admin.app().options.projectId ?? 'default'}`);
  console.log(`Admin profile UID: ${adminUser.uid}`);

  await seedRoles(db, now);
  await seedSystemSettings(db, now);
  await seedFirstAdminProfile(db, adminUser, now);

  const sampleProjectId = 'sample-kampala-primary-school-renovation';
  await seedSampleProject(db, sampleProjectId, adminUser.uid, now);
  await seedSampleProjectMembers(db, sampleProjectId, adminUser, now);
  await seedTestUsers(db, sampleProjectId, adminUser.uid, now);

  console.log(isCheckMode ? 'Seed check completed.' : 'Seed completed.');
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

async function resolveSeedAdminUser() {
  const uid = process.env.SEED_ADMIN_UID?.trim();
  if (uid) {
    const userRecord = await admin.auth().getUser(uid);
    return {
      uid: userRecord.uid,
      email: userRecord.email || process.env.SEED_ADMIN_EMAIL || '',
      fullName: userRecord.displayName || process.env.SEED_ADMIN_NAME || '',
      phoneNumber: userRecord.phoneNumber || process.env.SEED_ADMIN_PHONE || '',
    };
  }

  const email = process.env.SEED_ADMIN_EMAIL?.trim();
  if (email) {
    const userRecord = await admin.auth().getUserByEmail(email);
    return {
      uid: userRecord.uid,
      email: userRecord.email || email,
      fullName: userRecord.displayName || process.env.SEED_ADMIN_NAME || '',
      phoneNumber: userRecord.phoneNumber || process.env.SEED_ADMIN_PHONE || '',
    };
  }

  throw new Error(
    'Set SEED_ADMIN_UID or SEED_ADMIN_EMAIL for an existing Firebase Auth user. ' +
      'The seed script creates only the Firestore profile, not the Auth account.',
  );
}

async function seedRoles(db, now) {
  for (const finalRole of userRoles) {
    const [value, label] = finalRole;
    await setIfMissing(db.collection(collections.roles).doc(value), {
      id: value,
      value,
      label,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      createdBy: 'seed',
    });
  }
}

async function seedSystemSettings(db, now) {
  await setIfMissing(db.collection(collections.systemSettings).doc('app_config'), {
    id: 'app_config',
    appName: 'SiteConnect Uganda',
    country: 'Uganda',
    defaultCurrency: 'UGX',
    mvpMode: true,
    createdAt: now,
    updatedAt: now,
    createdBy: 'seed',
  });

  await setIfMissing(
    db.collection(collections.systemSettings).doc('offline_policy'),
    {
      id: 'offline_policy',
      enableFirestorePersistence: true,
      syncStrategy: 'updated_at_incremental',
      maxCachedProjectDays: 90,
      createdAt: now,
      updatedAt: now,
      createdBy: 'seed',
    },
  );
}

async function seedFirstAdminProfile(db, adminUser, now) {
  const fullName =
    process.env.SEED_ADMIN_NAME?.trim() ||
    adminUser.fullName ||
    'SiteConnect Administrator';

  await setIfMissing(db.collection(collections.users).doc(adminUser.uid), {
    uid: adminUser.uid,
    fullName,
    email: adminUser.email,
    role: 'administrator',
    phoneNumber: process.env.SEED_ADMIN_PHONE?.trim() || adminUser.phoneNumber,
    district: process.env.SEED_ADMIN_DISTRICT?.trim() || 'Kampala',
    profileImage: null,
    isActive: true,
    createdAt: now,
    updatedAt: now,
    createdBy: adminUser.uid,
  });
}

async function seedSampleProject(db, projectId, createdBy, now) {
  await setIfMissing(db.collection(collections.projects).doc(projectId), {
    id: projectId,
    projectCode: 'SC-UG-MVP-001',
    name: 'Kampala Primary School Renovation',
    description:
      'Sample public construction project for validating SiteConnect Uganda workflows.',
    district: process.env.SEED_SAMPLE_PROJECT_DISTRICT?.trim() || 'Kampala',
    status: 'active',
    contractorName: 'Sample Contractor Ltd',
    projectManagerId: createdBy,
    startDate: now,
    expectedEndDate: admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 120 * 24 * 60 * 60 * 1000),
    ),
    budgetAmount: 150000000,
    latitude: 0.3476,
    longitude: 32.5825,
    createdAt: now,
    updatedAt: now,
    createdBy,
  });
}

async function seedSampleProjectMembers(db, projectId, adminUser, now) {
  const adminMemberId = `${projectId}_${adminUser.uid}_administrator`;

  await setIfMissing(db.collection(collections.projectMembers).doc(adminMemberId), {
    id: adminMemberId,
    projectId,
    userId: adminUser.uid,
    role: 'administrator',
    status: 'active',
    assignedAt: now,
    createdAt: now,
    updatedAt: now,
    createdBy: adminUser.uid,
  });

  const optionalProjectManagerUid = process.env.SEED_SAMPLE_PROJECT_MANAGER_UID;
  if (!optionalProjectManagerUid) {
    console.log(
      'Skipping optional project manager member. Set SEED_SAMPLE_PROJECT_MANAGER_UID to add one.',
    );
    return;
  }

  await admin.auth().getUser(optionalProjectManagerUid);

  const projectManagerId = `${projectId}_${optionalProjectManagerUid}_project_manager`;
  await setIfMissing(db.collection(collections.projectMembers).doc(projectManagerId), {
    id: projectManagerId,
    projectId,
    userId: optionalProjectManagerUid,
    role: 'project_manager',
    status: 'active',
    assignedAt: now,
    createdAt: now,
    updatedAt: now,
    createdBy: adminUser.uid,
  });
}

async function seedTestUsers(db, sampleProjectId, createdBy, now) {
  if (!envFlag('SEED_TEST_USERS')) {
    console.log('Skipping role test users. Set SEED_TEST_USERS=true to add them.');
    return;
  }

  const password =
    process.env.SEED_TEST_USERS_PASSWORD?.trim() || defaultTestUserPassword;
  if (password.length < 6) {
    throw new Error('SEED_TEST_USERS_PASSWORD must be at least 6 characters.');
  }

  const emailDomain =
    process.env.SEED_TEST_USER_EMAIL_DOMAIN?.trim() || 'siteconnect.test';
  const emailPrefix =
    process.env.SEED_TEST_USER_EMAIL_PREFIX?.trim() || 'siteconnect';
  const defaultDistrict =
    process.env.SEED_TEST_USER_DISTRICT?.trim() || 'Kampala';

  console.log(
    `${isCheckMode ? 'Checking' : 'Seeding'} role test users for ${emailDomain}`,
  );

  const seededUsers = [];

  for (const profile of testUserProfiles) {
    const [role, fullName, district] = profile;
    const slug = role.replaceAll('_', '-');
    const email = `${emailPrefix}.${slug}@${emailDomain}`.toLowerCase();
    const uid = `${emailPrefix}-test-${slug}`.replaceAll('.', '-');

    const authUser = await ensureTestAuthUser({
      uid,
      email,
      password,
      displayName: fullName,
    });

    const userData = {
      uid: authUser.uid,
      fullName,
      email,
      role,
      phoneNumber: '',
      district: district || defaultDistrict,
      profileImage: null,
      isActive: true,
      isSeedTestUser: true,
      createdAt: now,
      updatedAt: now,
      createdBy,
    };

    await upsertSeededDocument(
      db.collection(collections.users).doc(authUser.uid),
      userData,
    );

    await seedTestProjectMember({
      db,
      sampleProjectId,
      userId: authUser.uid,
      role,
      createdBy,
      now,
    });

    seededUsers.push({ email, password, role, uid: authUser.uid });
  }

  console.log('Role test login credentials:');
  for (const user of seededUsers) {
    console.log(`${user.role}: ${user.email} / ${user.password}`);
  }
}

async function ensureTestAuthUser({ uid, email, password, displayName }) {
  const existingUser = await findAuthUser(uid, email);

  if (existingUser) {
    if (isCheckMode) {
      console.log(`WOULD UPDATE auth user ${email}`);
      return existingUser;
    }

    const updatedUser = await admin.auth().updateUser(existingUser.uid, {
      email,
      password,
      displayName,
      emailVerified: true,
      disabled: false,
    });
    console.log(`UPDATED auth user ${email}`);
    return updatedUser;
  }

  if (isCheckMode) {
    console.log(`WOULD CREATE auth user ${email}`);
    return { uid, email, displayName };
  }

  const createdUser = await admin.auth().createUser({
    uid,
    email,
    password,
    displayName,
    emailVerified: true,
    disabled: false,
  });
  console.log(`CREATED auth user ${email}`);
  return createdUser;
}

async function findAuthUser(uid, email) {
  try {
    return await admin.auth().getUser(uid);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  try {
    return await admin.auth().getUserByEmail(email);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  return null;
}

async function seedTestProjectMember({
  db,
  sampleProjectId,
  userId,
  role,
  createdBy,
  now,
}) {
  const memberId = `${sampleProjectId}_${userId}_${role}`;

  await setIfMissing(db.collection(collections.projectMembers).doc(memberId), {
    id: memberId,
    projectId: sampleProjectId,
    userId,
    role,
    status: 'active',
    assignedAt: now,
    createdAt: now,
    updatedAt: now,
    createdBy,
    isSeedTestUser: true,
  });
}

async function upsertSeededDocument(documentRef, data) {
  const snapshot = await documentRef.get();
  const pathLabel = documentRef.path;

  if (isCheckMode) {
    console.log(`${snapshot.exists ? 'WOULD UPDATE' : 'WOULD CREATE'} ${pathLabel}`);
    return;
  }

  if (!snapshot.exists) {
    await documentRef.set(data);
    console.log(`CREATED ${pathLabel}`);
    return;
  }

  await documentRef.set(
    {
      ...data,
      createdAt: snapshot.data().createdAt || data.createdAt,
    },
    { merge: true },
  );
  console.log(`UPDATED ${pathLabel}`);
}

function envFlag(name) {
  const value = process.env[name]?.trim().toLowerCase();
  return value === '1' || value === 'true' || value === 'yes';
}

async function setIfMissing(documentRef, data) {
  const snapshot = await documentRef.get();
  const pathLabel = documentRef.path;

  if (snapshot.exists) {
    console.log(`SKIP existing ${pathLabel}`);
    return;
  }

  if (isCheckMode) {
    console.log(`WOULD CREATE ${pathLabel}`);
    return;
  }

  await documentRef.set(data);
  console.log(`CREATED ${pathLabel}`);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
