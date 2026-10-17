import std;
import dyaml;

extern (C) char* cmark_markdown_to_html(const char* text, size_t len, int options);

struct Context {
  string src, dest, work;
}

string processMarkdown(string content) {
  import core.stdc.stdlib;
  auto ptr = cmark_markdown_to_html(content.ptr, content.length, 0 /* CMARK_OPT_DEFAULT */);
  scope (exit) free(ptr);
  return ptr.fromStringz.dup;
}

auto parseFrontmatter(ref Context ctx, string content) {
  try {
    if (auto leading = content.matchFirst(ctRegex!"---\r?\n"))
      if (auto fm = leading.post.matchFirst(ctRegex!"\n---\r?\n"))
        return tuple(Loader.fromString(fm.pre).load, fm.post);
  } catch (LoaderException) {}
  return tuple(Node(), content);
}

string processTemplate(ref Context ctx, string path) {
  auto (fm, content) = ctx.parseFrontmatter(path.readText);
  ("title" in fm).writeln;
  return content;
}

void processFile(ref Context ctx, string path) {
  static bool[string] store;

  if (path in store)
    return;

  auto dest = ctx.destPath(path);
  switch (path.extension) {
    case ".md":
      std.file.write(dest.withExtension(".html"), ctx.processTemplate(path).processMarkdown());
      break;
    case ".html":
      std.file.write(dest, ctx.processTemplate(path));
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
  scope (exit) work.exists && work.rmdirRecurse;

  Context ctx = {
    src: src,
    dest: dest,
    work: work,
  };

  ctx.processCtx;

  return 0;
}
