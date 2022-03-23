import { config } from "dotenv";
import * as admin from "firebase-admin";

admin.initializeApp();
config();

export * from "./adminEndpoints";
export * from "./auth-triggers";
export * from "./doBackupFirestoreData";
export * from "./dumpImages";
export * from "./excelOperations";
export * from "./firestore-triggers";
export * from "./scheduledMessages";
export * from "./temp-migrations";
export * from "./usersEndpoints";
