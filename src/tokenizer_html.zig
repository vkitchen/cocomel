// TOKENIZER_HTML.ZIG
// ------------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Indexer = @import("indexer.zig").Indexer;

const Pair = struct {
    key: []const u8,
    value: []const u8,
};

const escapes = [_]Pair{
    .{ .key = "&Tab;", .value = "" },
    .{ .key = "&NewLine", .value = "" },
    .{ .key = "&nbsp;", .value = "" },
    .{ .key = "&quot;", .value = "“" },
    .{ .key = "&amp;", .value = "&" },
    .{ .key = "&lt;", .value = "<" },
    .{ .key = "&gt;", .value = ">" },
    .{ .key = "&nbsp;", .value = "" },
    .{ .key = "&iexcl;", .value = "¡" },
    .{ .key = "&cent;", .value = "¢" },
    .{ .key = "&pound;", .value = "£" },
    .{ .key = "&curren;", .value = "¤" },
    .{ .key = "&yen;", .value = "¥" },
    .{ .key = "&brvbar;", .value = "¦" },
    .{ .key = "&sect;", .value = "§" },
    .{ .key = "&uml;", .value = "¨" },
    .{ .key = "&copy;", .value = "©" },
    .{ .key = "&ordf;", .value = "ª" },
    .{ .key = "&laquo;", .value = "«" },
    .{ .key = "&not;", .value = "¬" },
    .{ .key = "&shy;", .value = "" },
    .{ .key = "&reg;", .value = "®" },
    .{ .key = "&macr;", .value = "¯" },
    .{ .key = "&deg;", .value = "°" },
    .{ .key = "&plusmn;", .value = "±" },
    .{ .key = "&sup2;", .value = "²" },
    .{ .key = "&sup3;", .value = "³" },
    .{ .key = "&acute;", .value = "´" },
    .{ .key = "&micro;", .value = "µ" },
    .{ .key = "&para;", .value = "¶" },
    .{ .key = "&dot;", .value = "·" },
    .{ .key = "&cedil;", .value = "¸" },
    .{ .key = "&sup1;", .value = "¹" },
    .{ .key = "&ordm;", .value = "º" },
    .{ .key = "&raquo;", .value = "»" },
    .{ .key = "&frac14;", .value = "¼" },
    .{ .key = "&frac12;", .value = "½" },
    .{ .key = "&frac34;", .value = "¾" },
    .{ .key = "&iquest;", .value = "¿" },
    .{ .key = "&Agrave;", .value = "À" },
    .{ .key = "&Aacute;", .value = "Á" },
    .{ .key = "&Acirc;", .value = "Â" },
    .{ .key = "&Atilde;", .value = "Ã" },
    .{ .key = "&Auml;", .value = "Ä" },
    .{ .key = "&Aring;", .value = "Å" },
    .{ .key = "&AElig;", .value = "Æ" },
    .{ .key = "&Ccedil;", .value = "Ç" },
    .{ .key = "&Egrave;", .value = "È" },
    .{ .key = "&Eacute;", .value = "É" },
    .{ .key = "&Ecirc;", .value = "Ê" },
    .{ .key = "&Euml;", .value = "Ë" },
    .{ .key = "&Igrave;", .value = "Ì" },
    .{ .key = "&Iacute;", .value = "Í" },
    .{ .key = "&Icirc;", .value = "Î" },
    .{ .key = "&Iuml;", .value = "Ï" },
    .{ .key = "&ETH;", .value = "Ð" },
    .{ .key = "&Ntilde;", .value = "Ñ" },
    .{ .key = "&Ograve;", .value = "Ò" },
    .{ .key = "&Oacute;", .value = "Ó" },
    .{ .key = "&Ocirc;", .value = "Ô" },
    .{ .key = "&Otilde;", .value = "Õ" },
    .{ .key = "&Ouml;", .value = "Ö" },
    .{ .key = "&times;", .value = "×" },
    .{ .key = "&Oslash;", .value = "Ø" },
    .{ .key = "&Ugrave;", .value = "Ù" },
    .{ .key = "&Uacute;", .value = "Ú" },
    .{ .key = "&Ucirc;", .value = "Û" },
    .{ .key = "&Uuml;", .value = "Ü" },
    .{ .key = "&Yacute;", .value = "Ý" },
    .{ .key = "&THORN;", .value = "Þ" },
    .{ .key = "&szlig;", .value = "ß" },
    .{ .key = "&agrave;", .value = "à" },
    .{ .key = "&aacute;", .value = "á" },
    .{ .key = "&acirc;", .value = "â" },
    .{ .key = "&atilde;", .value = "ã" },
    .{ .key = "&auml;", .value = "ä" },
    .{ .key = "&aring;", .value = "å" },
    .{ .key = "&aelig;", .value = "æ" },
    .{ .key = "&ccedil;", .value = "ç" },
    .{ .key = "&egrave;", .value = "è" },
    .{ .key = "&eacute;", .value = "é" },
    .{ .key = "&ecirc;", .value = "ê" },
    .{ .key = "&euml;", .value = "ë" },
    .{ .key = "&igrave;", .value = "ì" },
    .{ .key = "&iacute;", .value = "í" },
    .{ .key = "&icirc;", .value = "î" },
    .{ .key = "&iuml;", .value = "ï" },
    .{ .key = "&eth;", .value = "ð" },
    .{ .key = "&ntilde;", .value = "ñ" },
    .{ .key = "&ograve;", .value = "ò" },
    .{ .key = "&oacute;", .value = "ó" },
    .{ .key = "&ocirc;", .value = "ô" },
    .{ .key = "&otilde;", .value = "õ" },
    .{ .key = "&ouml;", .value = "ö" },
    .{ .key = "&divide;", .value = "÷" },
    .{ .key = "&oslash;", .value = "ø" },
    .{ .key = "&ugrave;", .value = "ù" },
    .{ .key = "&uacute;", .value = "ú" },
    .{ .key = "&ucirc;", .value = "û" },
    .{ .key = "&uuml;", .value = "ü" },
    .{ .key = "&yacute;", .value = "ý" },
    .{ .key = "&thorn;", .value = "þ" },
    .{ .key = "&yuml;", .value = "ÿ" },
    .{ .key = "&Amacr;", .value = "Ā" },
    .{ .key = "&amacr;", .value = "ā" },
    .{ .key = "&Abreve;", .value = "Ă" },
    .{ .key = "&abreve;", .value = "ă" },
    .{ .key = "&Aogon;", .value = "Ą" },
    .{ .key = "&aogon;", .value = "ą" },
    .{ .key = "&Cacute;", .value = "Ć" },
    .{ .key = "&cacute;", .value = "ć" },
    .{ .key = "&Ccirc;", .value = "Ĉ" },
    .{ .key = "&ccirc;", .value = "ĉ" },
    .{ .key = "&Cdot;", .value = "Ċ" },
    .{ .key = "&cdot;", .value = "ċ" },
    .{ .key = "&Ccaron;", .value = "Č" },
    .{ .key = "&ccaron;", .value = "č" },
    .{ .key = "&Dcaron;", .value = "Ď" },
    .{ .key = "&dcaron;", .value = "ď" },
    .{ .key = "&Dstrok;", .value = "Đ" },
    .{ .key = "&dstrok;", .value = "đ" },
    .{ .key = "&Emacr;", .value = "Ē" },
    .{ .key = "&emacr;", .value = "ē" },
    .{ .key = "&Ebreve;", .value = "Ĕ" },
    .{ .key = "&ebreve;", .value = "ĕ" },
    .{ .key = "&Edot;", .value = "Ė" },
    .{ .key = "&edot;", .value = "ė" },
    .{ .key = "&Eogon;", .value = "Ę" },
    .{ .key = "&eogon;", .value = "ę" },
    .{ .key = "&Ecaron;", .value = "Ě" },
    .{ .key = "&ecaron;", .value = "ě" },
    .{ .key = "&Gcirc;", .value = "Ĝ" },
    .{ .key = "&gcirc;", .value = "ĝ" },
    .{ .key = "&Gbreve;", .value = "Ğ" },
    .{ .key = "&gbreve;", .value = "ğ" },
    .{ .key = "&Gdot;", .value = "Ġ" },
    .{ .key = "&gdot;", .value = "ġ" },
    .{ .key = "&Gcedil;", .value = "Ģ" },
    .{ .key = "&gcedil;", .value = "ģ" },
    .{ .key = "&Hcirc;", .value = "Ĥ" },
    .{ .key = "&hcirc;", .value = "ĥ" },
    .{ .key = "&Hstrok;", .value = "Ħ" },
    .{ .key = "&hstrok;", .value = "ħ" },
    .{ .key = "&Itilde;", .value = "Ĩ" },
    .{ .key = "&itilde;", .value = "ĩ" },
    .{ .key = "&Imacr;", .value = "Ī" },
    .{ .key = "&imacr;", .value = "ī" },
    .{ .key = "&Ibreve;", .value = "Ĭ" },
    .{ .key = "&ibreve;", .value = "ĭ" },
    .{ .key = "&Iogon;", .value = "Į" },
    .{ .key = "&iogon;", .value = "į" },
    .{ .key = "&Idot;", .value = "İ" },
    .{ .key = "&imath;", .value = "ı" },
    .{ .key = "&IJlig;", .value = "Ĳ" },
    .{ .key = "&ijlig;", .value = "ĳ" },
    .{ .key = "&Jcirc;", .value = "Ĵ" },
    .{ .key = "&jcirc;", .value = "ĵ" },
    .{ .key = "&Kcedil;", .value = "Ķ" },
    .{ .key = "&kcedil;", .value = "ķ" },
    .{ .key = "&kgreen;", .value = "ĸ" },
    .{ .key = "&Lacute;", .value = "Ĺ" },
    .{ .key = "&lacute;", .value = "ĺ" },
    .{ .key = "&Lcedil;", .value = "Ļ" },
    .{ .key = "&lcedil;", .value = "ļ" },
    .{ .key = "&Lcaron;", .value = "Ľ" },
    .{ .key = "&lcaron;", .value = "ľ" },
    .{ .key = "&Lmidot;", .value = "Ŀ" },
    .{ .key = "&lmidot;", .value = "ŀ" },
    .{ .key = "&Lstrok;", .value = "Ł" },
    .{ .key = "&lstrok;", .value = "ł" },
    .{ .key = "&Nacute;", .value = "Ń" },
    .{ .key = "&nacute;", .value = "ń" },
    .{ .key = "&Ncedil;", .value = "Ņ" },
    .{ .key = "&ncedil;", .value = "ņ" },
    .{ .key = "&Ncaron;", .value = "Ň" },
    .{ .key = "&ncaron;", .value = "ň" },
    .{ .key = "&napos;", .value = "ŉ" },
    .{ .key = "&ENG;", .value = "Ŋ" },
    .{ .key = "&eng;", .value = "ŋ" },
    .{ .key = "&Omacr;", .value = "Ō" },
    .{ .key = "&omacr;", .value = "ō" },
    .{ .key = "&Obreve;", .value = "Ŏ" },
    .{ .key = "&obreve;", .value = "ŏ" },
    .{ .key = "&Odblac;", .value = "Ő" },
    .{ .key = "&odblac;", .value = "ő" },
    .{ .key = "&OElig;", .value = "Œ" },
    .{ .key = "&oelig;", .value = "œ" },
    .{ .key = "&Racute;", .value = "Ŕ" },
    .{ .key = "&racute;", .value = "ŕ" },
    .{ .key = "&Rcedil;", .value = "Ŗ" },
    .{ .key = "&rcedil;", .value = "ŗ" },
    .{ .key = "&Rcaron;", .value = "Ř" },
    .{ .key = "&rcaron;", .value = "ř" },
    .{ .key = "&Sacute;", .value = "Ś" },
    .{ .key = "&sacute;", .value = "ś" },
    .{ .key = "&Scirc;", .value = "Ŝ" },
    .{ .key = "&scirc;", .value = "ŝ" },
    .{ .key = "&Scedil;", .value = "Ş" },
    .{ .key = "&scedil;", .value = "ş" },
    .{ .key = "&Scaron;", .value = "Š" },
    .{ .key = "&scaron;", .value = "š" },
    .{ .key = "&Tcedil;", .value = "Ţ" },
    .{ .key = "&tcedil;", .value = "ţ" },
    .{ .key = "&Tcaron;", .value = "Ť" },
    .{ .key = "&tcaron;", .value = "ť" },
    .{ .key = "&Tstrok;", .value = "Ŧ" },
    .{ .key = "&tstrok;", .value = "ŧ" },
    .{ .key = "&Utilde;", .value = "Ũ" },
    .{ .key = "&utilde;", .value = "ũ" },
    .{ .key = "&Umacr;", .value = "Ū" },
    .{ .key = "&umacr;", .value = "ū" },
    .{ .key = "&Ubreve;", .value = "Ŭ" },
    .{ .key = "&ubreve;", .value = "ŭ" },
    .{ .key = "&Uring;", .value = "Ů" },
    .{ .key = "&uring;", .value = "ů" },
    .{ .key = "&Udblac;", .value = "Ű" },
    .{ .key = "&udblac;", .value = "ű" },
    .{ .key = "&Uogon;", .value = "Ų" },
    .{ .key = "&uogon;", .value = "ų" },
    .{ .key = "&Wcirc;", .value = "Ŵ" },
    .{ .key = "&wcirc;", .value = "ŵ" },
    .{ .key = "&Ycirc;", .value = "Ŷ" },
    .{ .key = "&ycirc;", .value = "ŷ" },
    .{ .key = "&Yuml;", .value = "Ÿ" },
    .{ .key = "&fnof;", .value = "ƒ" },
    .{ .key = "&circ;", .value = "ˆ" },
    .{ .key = "&tilde;", .value = "˜" },
    .{ .key = "&Alpha;", .value = "Α" },
    .{ .key = "&Beta;", .value = "Β" },
    .{ .key = "&Gamma;", .value = "Γ" },
    .{ .key = "&Delta;", .value = "Δ" },
    .{ .key = "&Epsilon;", .value = "Ε" },
    .{ .key = "&Zeta;", .value = "Ζ" },
    .{ .key = "&Eta;", .value = "Η" },
    .{ .key = "&Theta;", .value = "Θ" },
    .{ .key = "&Iota;", .value = "Ι" },
    .{ .key = "&Kappa;", .value = "Κ" },
    .{ .key = "&Lambda;", .value = "Λ" },
    .{ .key = "&Mu;", .value = "Μ" },
    .{ .key = "&Nu;", .value = "Ν" },
    .{ .key = "&Xi;", .value = "Ξ" },
    .{ .key = "&Omicron;", .value = "Ο" },
    .{ .key = "&Pi;", .value = "Π" },
    .{ .key = "&Rho;", .value = "Ρ" },
    .{ .key = "&Sigma;", .value = "Σ" },
    .{ .key = "&Tau;", .value = "Τ" },
    .{ .key = "&Upsilon;", .value = "Υ" },
    .{ .key = "&Phi;", .value = "Φ" },
    .{ .key = "&Chi;", .value = "Χ" },
    .{ .key = "&Psi;", .value = "Ψ" },
    .{ .key = "&Omega;", .value = "Ω" },
    .{ .key = "&alpha;", .value = "α" },
    .{ .key = "&beta;", .value = "β" },
    .{ .key = "&gamma;", .value = "γ" },
    .{ .key = "&delta;", .value = "δ" },
    .{ .key = "&epsilon;", .value = "ε" },
    .{ .key = "&zeta;", .value = "ζ" },
    .{ .key = "&eta;", .value = "η" },
    .{ .key = "&theta;", .value = "θ" },
    .{ .key = "&iota;", .value = "ι" },
    .{ .key = "&kappa;", .value = "κ" },
    .{ .key = "&lambda;", .value = "λ" },
    .{ .key = "&mu;", .value = "μ" },
    .{ .key = "&nu;", .value = "ν" },
    .{ .key = "&xi;", .value = "ξ" },
    .{ .key = "&omicron;", .value = "ο" },
    .{ .key = "&pi;", .value = "π" },
    .{ .key = "&rho;", .value = "ρ" },
    .{ .key = "&sigmaf;", .value = "ς" },
    .{ .key = "&sigma;", .value = "σ" },
    .{ .key = "&tau;", .value = "τ" },
    .{ .key = "&upsilon;", .value = "υ" },
    .{ .key = "&phi;", .value = "φ" },
    .{ .key = "&chi;", .value = "χ" },
    .{ .key = "&psi;", .value = "ψ" },
    .{ .key = "&omega;", .value = "ω" },
    .{ .key = "&thetasym;", .value = "ϑ" },
    .{ .key = "&upsih;", .value = "ϒ" },
    .{ .key = "&piv;", .value = "ϖ" },
    .{ .key = "&ensp;", .value = "" },
    .{ .key = "&emsp;", .value = "" },
    .{ .key = "&thinsp;", .value = "" },
    .{ .key = "&zwnj;", .value = "" },
    .{ .key = "&zwj;", .value = "" },
    .{ .key = "&lrm;", .value = "" },
    .{ .key = "&rlm;", .value = "" },
    .{ .key = "&ndash;", .value = "–" },
    .{ .key = "&mdash;", .value = "—" },
    .{ .key = "&lsquo;", .value = "‘" },
    .{ .key = "&rsquo;", .value = "’" },
    .{ .key = "&sbquo;", .value = "‚" },
    .{ .key = "&ldquo;", .value = "“" },
    .{ .key = "&rdquo;", .value = "”" },
    .{ .key = "&bdquo;", .value = "„" },
    .{ .key = "&dagger;", .value = "†" },
    .{ .key = "&Dagger;", .value = "‡" },
    .{ .key = "&bull;", .value = "•" },
    .{ .key = "&hellip;", .value = "…" },
    .{ .key = "&permil;", .value = "‰" },
    .{ .key = "&prime;", .value = "′" },
    .{ .key = "&Prime;", .value = "″" },
    .{ .key = "&lsaquo;", .value = "‹" },
    .{ .key = "&rsaquo;", .value = "›" },
    .{ .key = "&oline;", .value = "‾" },
    .{ .key = "&euro;", .value = "€" },
    .{ .key = "&trade;", .value = "™" },
    .{ .key = "&larr;", .value = "←" },
    .{ .key = "&uarr;", .value = "↑" },
    .{ .key = "&rarr;", .value = "→" },
    .{ .key = "&darr;", .value = "↓" },
    .{ .key = "&harr;", .value = "↔" },
    .{ .key = "&crarr;", .value = "↵" },
    .{ .key = "&forall;", .value = "∀" },
    .{ .key = "&part;", .value = "∂" },
    .{ .key = "&exist;", .value = "∃" },
    .{ .key = "&empty;", .value = "∅" },
    .{ .key = "&nabla;", .value = "∇" },
    .{ .key = "&isin;", .value = "∈" },
    .{ .key = "&notin;", .value = "∉" },
    .{ .key = "&ni;", .value = "∋" },
    .{ .key = "&prod;", .value = "∏" },
    .{ .key = "&sum;", .value = "∑" },
    .{ .key = "&minus;", .value = "−" },
    .{ .key = "&lowast;", .value = "∗" },
    .{ .key = "&radic;", .value = "√" },
    .{ .key = "&prop;", .value = "∝" },
    .{ .key = "&infin;", .value = "∞" },
    .{ .key = "&ang;", .value = "∠" },
    .{ .key = "&and;", .value = "∧" },
    .{ .key = "&or;", .value = "∨" },
    .{ .key = "&cap;", .value = "∩" },
    .{ .key = "&cup;", .value = "∪" },
    .{ .key = "&int;", .value = "∫" },
    .{ .key = "&there4;", .value = "∴" },
    .{ .key = "&sim;", .value = "∼" },
    .{ .key = "&cong;", .value = "≅" },
    .{ .key = "&asymp;", .value = "≈" },
    .{ .key = "&ne;", .value = "≠" },
    .{ .key = "&equiv;", .value = "≡" },
    .{ .key = "&le;", .value = "≤" },
    .{ .key = "&ge;", .value = "≥" },
    .{ .key = "&sub;", .value = "⊂" },
    .{ .key = "&sup;", .value = "⊃" },
    .{ .key = "&nsub;", .value = "⊄" },
    .{ .key = "&sube;", .value = "⊆" },
    .{ .key = "&supe;", .value = "⊇" },
    .{ .key = "&oplus;", .value = "⊕" },
    .{ .key = "&otimes;", .value = "⊗" },
    .{ .key = "&perp;", .value = "⊥" },
    .{ .key = "&sdot;", .value = "⋅" },
    .{ .key = "&lceil;", .value = "⌈" },
    .{ .key = "&rceil;", .value = "⌉" },
    .{ .key = "&lfloor;", .value = "⌊" },
    .{ .key = "&rfloor;", .value = "⌋" },
    .{ .key = "&loz;", .value = "◊" },
    .{ .key = "&spades;", .value = "♠" },
    .{ .key = "&clubs;", .value = "♣" },
    .{ .key = "&hearts;", .value = "♥" },
    .{ .key = "&diams;", .value = "♦" },
};

fn isPunct(c: u8) bool {
    return c == '!' or c == '"' or c == '\'' or c == '(' or c == ')' or c == ',' or c == '-' or c == '.' or c == ';' or c == '?';
}

fn isWordChar(c: u8) bool {
    return std.ascii.isAlphabetic(c) or isPunct(c) or c == 0xE2;
}

pub const HtmlTokenizer = struct {
    const Self = @This();

    indexer: *Indexer,
    doc: *std.Io.Reader = undefined,
    buf: [512]u8 = undefined, // Tar block size
    index: usize = 0,
    len: usize = 0,
    file_size: usize = 0,

    pub fn init(indexer: *Indexer) Self {
        return .{ .indexer = indexer };
    }

    fn read(self: *Self) !void {
        self.len = try self.doc.readSliceShort(&self.buf);
        self.index = 0;
    }

    fn eof(self: *Self) !bool {
        if (self.file_size == 0)
            return true;
        if (self.index >= self.len)
            try self.read();
        return self.len == 0;
    }

    fn peek(self: *Self) !u8 {
        if (try self.eof())
            return 0;
        return self.buf[self.index];
    }

    fn consume(self: *Self) void {
        self.index += 1;
        self.file_size -|= 1;
    }

    fn consumeWhitespace(self: *Self) !void {
        while (std.ascii.isWhitespace(try self.peek()))
            self.consume();
    }

    fn consumeStr(self: *Self, str: []const u8) !bool {
        for (str) |c| {
            if (try self.peek() == c) {
                self.consume();
            } else {
                return false;
            }
        }
        return true;
    }

    pub fn tokenize(self: *Self, doc: *std.Io.Reader, file_size: u64) !void {
        self.doc = doc;
        self.file_size = file_size;
        try self.read();

        while (true) {
            const char = try self.peek();
            // EOF
            if (char == 0) {
                return;
            }
            // Tag
            else if (char == '<') {
                self.consume();
                if (try self.peek() == 's') {
                    self.consume();
                    if (try self.consumeStr("cript")) {
                        while (true) {
                            while (try self.peek() != '<')
                                self.consume();
                            if (try self.consumeStr("</script>")) {
                                break;
                            }
                        }
                        continue;
                    }
                    if (try self.consumeStr("tyle")) {
                        while (true) {
                            while (try self.peek() != '<')
                                self.consume();
                            if (try self.consumeStr("</style>")) {
                                break;
                            }
                        }
                        continue;
                    }
                }
                if (try self.consumeStr("title>")) {
                    var i: usize = 0;
                    while (i < self.indexer.buffer.len and try self.peek() != '<') : (i += 1) {
                        // HTML escape
                        if (try self.peek() == '&') {
                            var i_: usize = 0;
                            var buf: [10]u8 = undefined;
                            while (i_ < buf.len and try self.peek() != ';') : (i_ += 1) {
                                buf[i_] = try self.peek();
                                self.consume();
                            }
                            // grab the ;
                            if (i_ < buf.len and try self.peek() == ';') {
                                buf[i_] = try self.peek();
                                self.consume();
                                i_ += 1;
                            }

                            if (buf[1] == '#') {
                                const code_point = try if (buf[2] == 'x') std.fmt.parseInt(u21, buf[3 .. i_ - 1], 16) else std.fmt.parseInt(u21, buf[2 .. i_ - 1], 10);
                                i_ = try std.unicode.utf8Encode(code_point, self.indexer.buffer[i..]);
                            } else {
                                for (escapes) |pair| {
                                    if (std.mem.eql(u8, pair.key, buf[0..i_])) {
                                        i_ = pair.value.len;
                                        @memcpy(self.indexer.buffer[i .. i + i_], pair.value);
                                        break;
                                    }
                                }
                            }
                            i += i_ - 1;
                            continue;
                        }

                        self.indexer.buffer[i] = try self.peek();
                        self.consume();
                    }

                    try self.indexer.addTitle(self.indexer.buffer[0..i]);

                    while (try self.peek() != '>')
                        self.consume();
                    continue;
                }
                while (try self.peek() != '>')
                    self.consume();
                continue;
            }
            // HTML escape
            else if (char == '&') {
                var i: usize = 0;
                while (i < self.indexer.buffer.len and try self.peek() != ';') : (i += 1) {
                    self.indexer.buffer[i] = try self.peek();
                    self.consume();
                }
                // grab the ;
                if (i < self.indexer.buffer.len and try self.peek() == ';') {
                    self.indexer.buffer[i] = try self.peek();
                    self.consume();
                    i += 1;
                }

                if (self.indexer.buffer[1] == '#') {
                    const code_point = try if (self.indexer.buffer[2] == 'x') std.fmt.parseInt(u21, self.indexer.buffer[3 .. i - 1], 16) else std.fmt.parseInt(u21, self.indexer.buffer[2 .. i - 1], 10);
                    i = try std.unicode.utf8Encode(code_point, &self.indexer.buffer);
                    try self.indexer.addTerm(self.indexer.buffer[0..i]);
                    continue;
                }

                for (escapes) |pair| {
                    if (std.mem.eql(u8, pair.key, self.indexer.buffer[0..i])) {
                        @memcpy(self.indexer.buffer[0..pair.value.len], pair.value);
                        try self.indexer.addTerm(self.indexer.buffer[0..pair.value.len]);
                        break;
                    }
                }

                continue;
            }
            // Number
            else if (std.ascii.isDigit(char)) {
                var i: usize = 0;
                while (i < self.indexer.buffer.len and std.ascii.isDigit(try self.peek())) : (i += 1) {
                    self.indexer.buffer[i] = try self.peek();
                    self.consume();
                }

                try self.indexer.addTerm(self.indexer.buffer[0..i]);
                continue;
            }
            // Word
            else if (std.ascii.isAlphabetic(char)) {
                var i: usize = 0;
                while (i < self.indexer.buffer.len and isWordChar(try self.peek())) : (i += 1) {
                    if (try self.peek() == 0xE2) {
                        self.consume();
                        if (try self.peek() != 0x80)
                            continue;
                        self.consume();
                        if (try self.peek() != 0x99)
                            continue;
                        self.consume();

                        self.indexer.buffer[i] = '\'';
                        continue;
                    }
                    self.indexer.buffer[i] = try self.peek();
                    self.consume();
                }

                try self.indexer.addTerm(self.indexer.buffer[0..i]);
                continue;
            }
            self.consume();
        }
    }
};
