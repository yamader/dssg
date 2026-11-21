module dssg.main;

import std;
import dssg.md;
import dssg.tmpl;

struct Context {
  string src, dest, work;
}

void processFile(ref Context ctx, string path) {
  static bool[string] store;

  if (path in store)
    return;

  auto dest = ctx.destPath(path);
  switch (path.extension) {
    case ".md":
      std.file.write(dest.withExtension(".html"), path.processTemplate.processMarkdown);
      break;
    case ".html":
      std.file.write(dest, path.processTemplate);
      break;
    default:
      std.file.copy(path, dest);
  }
}

void processCtx(ref Context ctx) {
  foreach (dirEntry; ctx.src.dirEntries(SpanMode.breadth)) {
    if (dirEntry.isDir) {
      auto dest = ctx.destPath(dirEntry.name);
      if (!dest.exists) dest.mkdir;
    } else if (dirEntry.isFile) {
      ctx.processFile(dirEntry.name);
    }
  }
}

string destPath(ref Context ctx, string srcPath) {
  return ctx.dest.buildPath(srcPath[ctx.src.length+1..$]);
}

int main(string[] args) {
  // GetoptResult getoptRes;
  // try {
  //   getoptRes = getopt(
  //     args,
  //   );
  //   if (getoptRes.helpWanted) {
  //     defaultGetoptPrinter("usage: dssg [opts] <src> <dest>\nopts:", getoptRes.options);
  //     return 0;
  //   }
  //   if (args.length != 3) throw GetOptException;
  // } catch (GetOptException) {
  //   defaultGetoptPrinter("usage: dssg [opts] <src> <dest>\nopts:", getoptRes.options);
  //   return 1;
  // }

  auto src = args[1];

  auto dest = args[2];
  if (!dest.exists) dest.mkdir;

  auto work = tempDir.buildPath("dssg_" ~ thisProcessID.to!string);
  work.mkdir;
  scope (exit) if (work.exists) work.rmdirRecurse;

  Context ctx = {
    src: src,
    dest: dest,
    work: work,
  };

  ctx.processCtx;

  return 0;
}
