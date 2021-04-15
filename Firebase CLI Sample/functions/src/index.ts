import * as admin from "firebase-admin";
import { doBackupFirestoreData } from "./doBackupFirestoreData";
import { dumpImages } from "./dumpImages";
import { exportToExcel, importFromExcel } from "./excelOperations";
import {
  onClassUpdated,
  onPersonUpdated,
  onHistoryDayDeleted,
  onHistoryRecordWrite,
  onServantsHistoryRecordWrite,
  onInvitationCreated,
  onUserUpdated,
} from "./firestore-triggers";
import { onUserSignUp, onUserDeleted } from "./auth-triggers";

import {
  getUsers,
  approveUser,
  unApproveUser,
  deleteUser,
  resetPassword,
  updatePermissions,
  migrateHistory,
  tempUpdateUserData,
} from "./adminEndpoints";
import {
  registerWithLink,
  registerAccount,
  registerFCMToken,
  updateUserSpiritData,
  sendMessageToUsers,
  changeUserName,
  changePassword,
  deleteImage,
  recoverDoc,
} from "./usersEndpoints";

admin.initializeApp();

exports.doBackupFirestoreData = doBackupFirestoreData;
exports.dumpImages = dumpImages;

exports.importFromExcel = importFromExcel;
exports.exportToExcel = exportToExcel;

exports.onClassUpdated = onClassUpdated;
exports.onPersonUpdated = onPersonUpdated;
exports.onUserUpdated = onUserUpdated;
exports.onHistoryDayDeleted = onHistoryDayDeleted;
exports.onHistoryRecordWrite = onHistoryRecordWrite;
exports.onServantsHistoryRecordWrite = onServantsHistoryRecordWrite;
exports.onInvitationCreated = onInvitationCreated;

exports.onUserSignUp = onUserSignUp;
exports.onUserDeleted = onUserDeleted;

exports.getUsers = getUsers;
exports.approveUser = approveUser;
exports.unApproveUser = unApproveUser;
exports.deleteUser = deleteUser;
exports.resetPassword = resetPassword;
exports.updatePermissions = updatePermissions;

exports.registerWithLink = registerWithLink;
exports.registerAccount = registerAccount;
exports.registerFCMToken = registerFCMToken;
exports.updateUserSpiritData = updateUserSpiritData;
exports.sendMessageToUsers = sendMessageToUsers;
exports.changeUserName = changeUserName;
exports.changePassword = changePassword;
exports.deleteImage = deleteImage;
exports.recoverDoc = recoverDoc;
exports.migrateHistory = migrateHistory;
exports.tempUpdateUserData = tempUpdateUserData;
