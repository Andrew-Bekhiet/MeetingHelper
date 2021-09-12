import { initializeApp } from "firebase-admin";
import { config } from "dotenv";

initializeApp();
config();

export * from "./doBackupFirestoreData";
export * from "./dumpImages";
export * from "./excelOperations";
export * from "./firestore-triggers";
export * from "./auth-triggers";

export * from "./adminEndpoints";
export * from "./usersEndpoints";
export * from "./temp-migrations";
