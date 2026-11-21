module dssg.md;

import std;

extern (C) char* cmark_markdown_to_html(const char* text, size_t len, int options);

string processMarkdown(string content) {
  import core.stdc.stdlib;
  auto ptr = cmark_markdown_to_html(content.ptr, content.length, 0 /* CMARK_OPT_DEFAULT */);
  scope (exit) free(ptr);
  return ptr.fromStringz.dup;
}
