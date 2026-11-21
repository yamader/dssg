module dssg.tmpl;

import std;
import dyaml;
import dssg.main: Context;

class Directive {
  enum Type {
    Comment,
    Embed, // obj, args, layout
    End,
    For, // obj, args[0], slot
    Slot,
    Wrap, // obj, args, slot, layout
  }
  Type type;
  string obj;
  string[] args;
  Template slot;
  Template layout;
}

class Template {
  string[string] meta;
  string[] fragments;
  Directive[] directives;

  string eval(string[string] args = new string[string]) {
    auto res = appender!string;
    foreach (frag, dir; fragments.zip(directives)) {
      res ~= frag;
      with (dir.type) final switch (dir.type) {
        case Comment:
          break;
        case Embed:
          res ~= dir.layout.eval(/*dir.args*/);
          break;
        case End:
          assert(0);
        case For:
          // for
          res ~= dir.slot.eval(/*dir.obj, env*/);
          break;
        case Slot:
          // embed from args
          break;
        case Wrap:
          res ~= dir.layout.eval(/*dir.args, slot*/);
          break;
      }
    }
    res ~= fragments[$-1];
    return res[];
  }
}

auto pop(T: SList!U, U)(T s) {
  auto x = s.front;
  s.removeFront;
  return x;
}

auto evalExpr() {
  //
}

auto parseFrontmatter(string content) {
  try {
    if (auto leading = content.matchFirst(ctRegex!`---\r?\n`))
      if (auto fm = leading.post.matchFirst(ctRegex!`\n---\r?\n`))
        return tuple(Loader.fromString(fm.pre).load, fm.post);
  } catch (LoaderException) {}
  return tuple(Node(), content);
}

auto taketok(string s) {
  s = s.stripLeft;
  auto tail = s.find!(std.ascii.isWhite);
  return tuple(s[0..$-tail.length], tail);
}

auto taketok(T: Tuple!U, U...)(T t) {
  auto (head, tail) = t[$-1].taketok;
  t[$-1] = head;
  return t ~ tail;
}

auto takestr(string s) {
  s = s.stripLeft;
  if (!s.startsWith('"')) return s.taketok;

  auto tail = s.drop(1);
  while (true) {
    auto quo = tail.matchFirst(ctRegex!`\\*"`);
    if (!quo) assert(0);

    tail = quo.post;
    if (quo.hit.length%2) break;
    if (tail.empty) assert(0);
  }
  auto escaped = s[1..$-tail.length-1];
  return tuple(escaped, tail);
}

Directive parseDirective(string s) {
  auto dir = new Directive;
  auto (head, body) = s.stripRight.taketok;
  with (dir.type) switch (head) {
    case "--":
      dir.type = Comment;
      break;
    case "embed":
      dir.type = Embed;
      dir.obj = body.takestr[0];
      break;
    case "end":
      dir.type = End;
      break;
    case "for":
      dir.type = For;
      auto (var, _, arr) = body.taketok.taketok;
      dir.obj = var;
      dir.args = [arr];
      break;
    case "slot":
      dir.type = Slot;
      break;
    case "wrap":
      dir.type = Wrap;
      dir.obj = body.takestr[0];
      break;
    default:
      assert(0);
  }
  return dir;
}

Template loadTemplate(string path) {
  auto canon = path.buildNormalizedPath;

  static Template[string] cache;
  if (canon in cache) return cache[canon];

  auto tmpl = new Template;
  cache[canon] = tmpl;

  auto (meta, content) = canon.readText.parseFrontmatter;
  if (meta.isValid) foreach (pair; meta.mapping)
    tmpl.meta[pair.key.as!string] = pair.value.as!string;

  auto fragsStack = appender!(string[]).SList!(Appender!(string[]));
  auto dirsStack = appender!(Directive[]).SList!(Appender!(Directive[]));
  while (content.matchFirst(ctRegex!`\{\{.+\}\}`)) {
    auto (head, _, post) = content.findSplit("{{").asTuple;
    auto (body, __, tail) = post.findSplit("}}").asTuple;

    fragsStack.front ~= head;
    auto dir = body.parseDirective;
    dirsStack.front ~= dir;
    content = tail;

    with (dir.type) {
      // load dir.layout
      if (dir.type == Embed || dir.type == Wrap) {
        dir.layout = canon.dirName.buildPath(dir.obj).loadTemplate;
      }
      // begin dir.slot
      if (dir.type == For || dir.type == Wrap) {
        fragsStack.insertFront(appender!(string[]));
        dirsStack.insertFront(appender!(Directive[]));
      }
      // end dir.slot
      if (dir.type == End) {
        auto slot = new Template;
        slot.fragments = fragsStack.pop[];
        slot.directives = dirsStack.pop[];
        dirsStack.front.data[$-1].slot = slot;
      }
    }
  }
  auto frags = fragsStack.pop;
  auto dirs = dirsStack.pop;
  assert(fragsStack.empty && dirsStack.empty); // missing end
  frags ~= content;
  tmpl.fragments = frags[];
  tmpl.directives = dirs[];

  return tmpl;
}

string processTemplate(string path) {
  return path.loadTemplate.eval;
}
