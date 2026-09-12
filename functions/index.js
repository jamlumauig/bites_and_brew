/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

initializeApp();

const adminEmails = new Set(["heyjamdev@gmail.com"]);

function requireAdmin(request) {
  if (!request.auth || request.auth.token.role !== "admin") {
    throw new HttpsError("permission-denied", "Administrator access is required.");
  }
}

exports.bootstrapRole = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }

  const auth = getAuth();
  const user = await auth.getUser(request.auth.uid);
  const role = adminEmails.has((user.email || "").toLowerCase())
    ? "admin"
    : user.customClaims?.role === "admin"
      ? "admin"
      : "user";

  if (user.customClaims?.role !== role) {
    await auth.setCustomUserClaims(user.uid, {...user.customClaims, role});
  }
  return {role};
});

exports.listUsers = onCall(async (request) => {
  requireAdmin(request);
  const result = await getAuth().listUsers(1000);
  return {
    users: result.users.map((user) => ({
      uid: user.uid,
      email: user.email || "",
      role: user.customClaims?.role === "admin" ? "admin" : "user",
    })),
  };
});

exports.setUserRole = onCall(async (request) => {
  requireAdmin(request);
  const uid = request.data?.uid;
  const role = request.data?.role;
  if (typeof uid !== "string" || !["admin", "user"].includes(role)) {
    throw new HttpsError("invalid-argument", "A user ID and valid role are required.");
  }

  const auth = getAuth();
  const target = await auth.getUser(uid);
  const targetEmail = (target.email || "").toLowerCase();
  if (adminEmails.has(targetEmail) && role !== "admin") {
    throw new HttpsError("failed-precondition", "The bootstrap admin cannot be demoted.");
  }
  await auth.setCustomUserClaims(uid, {...target.customClaims, role});
  return {uid, role};
});

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
