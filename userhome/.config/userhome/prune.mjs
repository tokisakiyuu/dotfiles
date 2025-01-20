#!/usr/bin/env -S node

import whitelist from "./dotfile-whitelist.json" with { type: "json" };
import { homedir } from "node:os";
import { readdir, unlink } from "node:fs/promises";

const whitelistFiles = whitelist.map(({ name }) => name);

const home = homedir();
const filenames = await readdir(home);
const dotfiles = filenames.filter((name) => name.startsWith("."));
const diffs = dotfiles.filter((name) => !whitelistFiles.includes(name));

console.log("Targets:\n\n" + diffs.join("\n\n"));

await Promise.all(diffs.map((name) => unlink(home + "/" + name)));
