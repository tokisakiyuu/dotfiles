#!/usr/bin/env node

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Youdao Translator
// @raycast.mode fullOutput

// Optional parameters:
// @raycast.icon https://ydlunacommon-cdn.nosdn.127.net/31cf4b56e6c0b3af668aa079de1a898c.png
// @raycast.argument1 { "type": "text", "placeholder": "Content" }
// @raycast.packageName Youdao Translator

// Documentation:
// @raycast.author tokisakiyuu
// @raycast.authorURL tokisakiyuu.com

// https://fanyi.youdao.com/openapi/
// https://ai.youdao.com/console/#/app-overview

import { createHash, randomUUID } from "crypto";

const text = process.argv.slice(2)[0];

const input =
  text.length > 20 ? text.slice(0, 10) + text.length + text.slice(-10) : text;
const appId = "5d52d44efbb544ad";
const appSecret = "IDZns6eW5wT5x5TqsQ9nws3Gyxx9JlvH";
const salt = randomUUID();
const curtime = Math.trunc(Date.now() / 1000);

const res = await fetch("https://openapi.youdao.com/api", {
  method: "POST",
  headers: {
    "Content-Type": "application/x-www-form-urlencoded",
  },
  body: new URLSearchParams({
    q: text,
    from: "auto",
    to: "auto",
    appKey: appId,
    salt,
    sign: createHash("sha256")
      .update(`${appId}${input}${salt}${curtime}${appSecret}`)
      .digest("hex"),
    signType: "v3",
    curtime,
  }),
});

const data = await res.json();

if (data.errorCode === "0") {
  console.log(data.translation.at(0));
} else {
  console.error(`API Request Error: [ErrorCode:${data.errorCode}]`);
}
