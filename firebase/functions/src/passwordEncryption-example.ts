import SHA3 from "sha3";

export function encryptPassword(oldPassword: string): string {
  const s265 = new SHA3(256);
  const s512 = new SHA3(512);

  s512.update(oldPassword + "o$!hP64J^7c");
  s265.update(
    s512.digest("base64") + "fKLpdlk1px5ZwvF^YuIb9252C08@aQ4qDRZz5h2"
  );

  return s265.digest("base64");
}
