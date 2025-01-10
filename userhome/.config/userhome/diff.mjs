#!/usr/bin/env -S node

import whitelist from "./dotfile-whitelist.json" with { type: "json" };
import { homedir } from "node:os";
import { readdir, stat } from "node:fs/promises";

const home = homedir();
const filenames = await readdir(home);
const dotfiles = filenames.filter((name) => name.startsWith("."));
const diffs = dotfiles.filter((name) => !whitelist.includes(name));

const infomations = await Promise.all(
  diffs.map(async (name) => ({
    name,
    stat: await stat(home + "/" + name),
  })),
);

console.log(
  "Diffs:\n\n" +
    infomations
      .map(
        ({ name, stat }) =>
          `${name}\nBirthTime: ${stat.birthtime.toLocaleString()}\nModifyTime: ${stat.mtime.toLocaleString()}`,
      )
      .join("\n\n"),
);
